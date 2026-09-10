// ATA Tracking — pull latest graded quiz results from Teachable and write them
// into Supabase. Uses Node https (same as ata-sheet) so esbuild/Netlify does
// not depend on global fetch.
//
// Admin button: POST /.netlify/functions/ata-teachable-sync  {secret}
// Daily cron:   ata-teachable-cron.js (needs ATA_WEBHOOK_SECRET + TEACHABLE_API_KEY)

const https = require('https');
const QUIZZES = require('./ata-teachable-quizzes.json');

// Teachable sometimes numbers finals as TAB-I-100 / TAB-A-200; the tracker curriculum uses I-109 / A-207 etc.
const LESSON_CODE_REMAP = {
  'TAB-I-100': 'TAB-I-109',
  'TAB-I-400': 'TAB-I-406',
  'TAB-A-200': 'TAB-A-207',
  'TAB-A-300': 'TAB-A-306',
  'TAB-B-400': 'TAB-B-401',
};
function remapLessonCode(code, lectureName) {
  const raw = String(code || '').toUpperCase();
  if (/TAB-Intermediate-300\s+Final/i.test(lectureName || '')) return 'TAB-I-307';
  return LESSON_CODE_REMAP[raw] || raw;
}

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY ||
  'sb_publishable_hh7_CD_TuH0X3YugPn_Z6w_VWSAAvlb';

function env(name) {
  // Read at runtime so esbuild does not inline an empty build-time value.
  return (process.env && process.env[name]) || '';
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
    body: JSON.stringify(body),
  };
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

function requestJson(method, urlStr, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const payload = body == null ? null : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
    const req = https.request({
      protocol: u.protocol,
      hostname: u.hostname,
      port: u.port || 443,
      path: u.pathname + u.search,
      method,
      headers: Object.assign({
        Accept: 'application/json',
        'User-Agent': 'TABSkillsTracker/1.0',
      }, headers || {}, payload ? { 'Content-Length': String(payload.length) } : {}),
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (c) => { data += c; });
      res.on('end', () => {
        let parsed = null;
        if (data) {
          try { parsed = JSON.parse(data); } catch (_) { parsed = null; }
        }
        resolve({ status: res.statusCode || 0, text: data, json: parsed });
      });
    });
    req.on('error', reject);
    req.setTimeout(25000, () => { req.destroy(new Error('timeout ' + urlStr)); });
    if (payload) req.write(payload);
    req.end();
  });
}

async function teachableGet(apiKey, path, attempt) {
  const res = await requestJson('GET', 'https://developers.teachable.com/v1' + path, { apiKey });
  if (res.status === 429 && (attempt || 0) < 5) {
    await sleep(500 * Math.pow(2, attempt || 0));
    return teachableGet(apiKey, path, (attempt || 0) + 1);
  }
  if (res.status < 200 || res.status >= 300) {
    throw new Error('Teachable HTTP ' + res.status + ' ' + path + (res.text ? ': ' + String(res.text).slice(0, 180) : ''));
  }
  return res.json;
}

async function mapPool(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  async function worker() {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}

function scorePercent(raw) {
  if (raw == null || raw === '') return null;
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  return n <= 1 ? Math.round(n * 1000) / 10 : Math.round(n * 10) / 10;
}

function collectRows(quiz, payload) {
  const inner = (payload && payload.quiz_responses) || payload || {};
  const responses = inner.responses || [];
  const rows = [];
  for (const r of responses) {
    const score = scorePercent(r.percent_correct);
    if (score == null && !r.submitted_at) continue;
    const submitted = r.submitted_at || '';
    rows.push({
      email: r.student_email || '',
      name: r.student_name || '',
      lesson_code: quiz.lesson_code,
      score,
      attempted_at: submitted || null,
      course_id: quiz.course_id,
      student_id: r.student_id || null,
      external_id: 'teachable:' + quiz.quiz_id + ':' + (r.student_id || r.student_email || r.student_name) + ':' + submitted,
    });
  }
  return rows;
}

async function ingest(secret, rows) {
  if (!rows.length) return { applied: 0, matched: 0, unmatched: 0 };
  const url = SUPABASE_URL.replace(/\/$/, '') + '/rest/v1/rpc/app_ata_import_attempts';
  let applied = 0, matched = 0, unmatched = 0;
  const chunk = 250;
  for (let i = 0; i < rows.length; i += chunk) {
    const slice = rows.slice(i, i + chunk);
    const res = await requestJson('POST', url, {
      apikey: SUPABASE_ANON_KEY,
      Authorization: 'Bearer ' + SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    }, { p_secret: secret, p_rows: slice });
    const data = res.json;
    if (res.status < 200 || res.status >= 300 || !data || data.ok === false) {
      throw new Error((data && (data.error || data.message || data.hint)) || ('Ingest HTTP ' + res.status + ' ' + String(res.text || '').slice(0, 180)));
    }
    applied += data.applied || 0;
    matched += data.matched || 0;
    unmatched += data.unmatched || 0;
  }
  return { applied, matched, unmatched };
}

async function runSync(apiKey, secret) {
  const probe = await teachableGet(apiKey, '/courses?per=1');
  if (!probe || !probe.courses) throw new Error('Teachable login failed — check TEACHABLE_API_KEY on Netlify.');

  const all = [];
  let quizErrors = 0;
  let firstError = '';
  await mapPool(QUIZZES, 4, async (quiz) => {
    try {
      const path = '/courses/' + quiz.course_id + '/lectures/' + quiz.lecture_id + '/quizzes/' + quiz.quiz_id + '/responses';
      const payload = await teachableGet(apiKey, path);
      all.push.apply(all, collectRows(quiz, payload));
    } catch (e) {
      quizErrors += 1;
      if (!firstError) firstError = (e && e.message) || String(e);
      console.error('quiz failed', quiz.lesson_code, e && e.message);
    }
  });
  const extras = await fillCompleteNoScore(apiKey, all);
  const result = await ingest(secret, all.concat(extras.rows));
  return {
    ok: true,
    quizzes: QUIZZES.length,
    rowCount: all.length,
    completeNoScore: extras.rows.length,
    progressJobs: extras.jobs,
    quizErrors,
    firstError: firstError || null,
    applied: result.applied,
    matched: result.matched,
    unmatched: result.unmatched,
  };
}

function flattenProgress(payload) {
  const sections = (payload && payload.course_progress && payload.course_progress.lecture_sections) || [];
  const lectures = [];
  for (const s of sections) {
    for (const l of s.lectures || []) lectures.push(l);
  }
  return lectures;
}

// Lectures marked Complete in Teachable with no graded quiz response (dashes
// instead of a percent). Pull those from course progress so they count as done.
async function fillCompleteNoScore(apiKey, scoredRows) {
  const scoredCount = {};
  const studentsByCourse = {};
  const scored = new Set();
  for (const row of scoredRows) {
    scoredCount[row.lesson_code] = (scoredCount[row.lesson_code] || 0) + 1;
    scored.add(String(row.email || row.name).toLowerCase() + '|' + row.lesson_code);
    if (!row.course_id || !row.student_id) continue;
    const cid = String(row.course_id);
    if (!studentsByCourse[cid]) studentsByCourse[cid] = {};
    studentsByCourse[cid][String(row.student_id)] = { email: row.email || '', name: row.name || '' };
  }
  const catalogByCourse = {};
  QUIZZES.forEach((q) => {
    const cid = String(q.course_id);
    if (!catalogByCourse[cid]) catalogByCourse[cid] = [];
    catalogByCourse[cid].push(q);
  });
  // Only fetch progress in courses that have at least one ATA quiz with no graded responses
  // (e.g. TAB-A-102: Complete in Teachable, dashes instead of a percent).
  const gapCourses = new Set();
  QUIZZES.forEach((q) => {
    if (!scoredCount[q.lesson_code]) gapCourses.add(String(q.course_id));
  });
  const jobs = [];
  gapCourses.forEach((courseId) => {
    const students = studentsByCourse[courseId] || {};
    Object.keys(students).forEach((uid) => {
      jobs.push({ courseId, uid, ident: students[uid] });
    });
  });
  const extra = [];
  await mapPool(jobs, 6, async (job) => {
    try {
      const payload = await teachableGet(apiKey, '/courses/' + job.courseId + '/progress?user_id=' + job.uid + '&per=100');
      const lectures = flattenProgress(payload);
      const byLec = {};
      (catalogByCourse[job.courseId] || []).forEach((q) => { byLec[String(q.lecture_id)] = q; });
      for (const lec of lectures) {
        if (!lec.is_completed) continue;
        let quiz = byLec[String(lec.id)];
        if (!quiz) {
          const m = /TAB-[BIA]-\d+/i.exec(lec.name || '');
          const code = remapLessonCode(m && m[0], lec.name);
          if (code) quiz = QUIZZES.find((q) => q.lesson_code === code);
        }
        if (!quiz) continue;
        const key = String(job.ident.email || job.ident.name).toLowerCase() + '|' + quiz.lesson_code;
        if (scored.has(key)) continue;
        scored.add(key);
        extra.push({
          email: job.ident.email,
          name: job.ident.name,
          lesson_code: quiz.lesson_code,
          score: null,
          attempted_at: lec.completed_at || null,
          complete_no_score: true,
          external_id: 'teachable-complete:' + quiz.lecture_id + ':' + job.uid,
        });
      }
    } catch (e) {
      console.error('progress failed', job.courseId, job.uid, e && e.message);
    }
  });
  return { rows: extra, jobs: jobs.length };
}

exports.handler = async function (event) {
  const apiKey = String(env('TEACHABLE_API_KEY') || '').trim();
  if (!apiKey) {
    return json(500, { ok: false, error: 'TEACHABLE_API_KEY is not set on Netlify. Add it under Project configuration → Environment variables, then Redeploy.' });
  }
  let secret = env('ATA_WEBHOOK_SECRET');
  if (event && event.body) {
    try {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      if (body && body.secret) secret = body.secret;
    } catch (_) { /* ignore */ }
  }
  if (!secret) {
    return json(500, { ok: false, error: 'Missing ATA webhook secret. Open Zapier setup once, or set ATA_WEBHOOK_SECRET on Netlify for the daily job.' });
  }
  try {
    const result = await runSync(apiKey, secret);
    return json(200, result);
  } catch (e) {
    return json(502, { ok: false, error: (e && e.message) || 'Teachable sync failed.' });
  }
};
