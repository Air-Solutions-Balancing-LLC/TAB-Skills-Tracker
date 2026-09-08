// ATA Tracking — pull latest graded quiz results from Teachable and write them
// into Supabase (scores + one attempt per distinct Teachable submission).
//
// Triggered by:
//   * Admin button "Sync from Teachable" (POST with {secret} from the webhook RPC)
//   * Daily Netlify schedule (needs ATA_WEBHOOK_SECRET + TEACHABLE_API_KEY env vars)
//
// Env:
//   TEACHABLE_API_KEY   — required (Netlify → Site settings → Environment variables)
//   ATA_WEBHOOK_SECRET  — required for the scheduled run; the button can pass it
//   SUPABASE_URL        — optional override (defaults to the production project)
//   SUPABASE_ANON_KEY   — optional override (defaults to the publishable key)

const QUIZZES = require('./ata-teachable-quizzes.json');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY ||
  'sb_publishable_hh7_CD_TuH0X3YugPn_Z6w_VWSAAvlb';
const TEACHABLE_BASE = 'https://developers.teachable.com/v1';

function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
    body: JSON.stringify(body),
  };
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function teachableGet(apiKey, path, attempt) {
  const r = await fetch(TEACHABLE_BASE + path, {
    headers: { apiKey, Accept: 'application/json' },
  });
  if (r.status === 429 && (attempt || 0) < 4) {
    await sleep(400 * Math.pow(2, attempt || 0));
    return teachableGet(apiKey, path, (attempt || 0) + 1);
  }
  if (!r.ok) {
    const t = await r.text().catch(() => '');
    throw new Error('Teachable HTTP ' + r.status + ' ' + path + (t ? ': ' + t.slice(0, 180) : ''));
  }
  return r.json();
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
  const n = Math.min(limit, items.length);
  await Promise.all(Array.from({ length: n }, worker));
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
      external_id: 'teachable:' + quiz.quiz_id + ':' + (r.student_id || r.student_email || r.student_name) + ':' + submitted,
    });
  }
  return rows;
}

async function ingest(secret, rows) {
  const url = SUPABASE_URL.replace(/\/$/, '') + '/rest/v1/rpc/app_ata_import_attempts';
  let applied = 0, matched = 0, unmatched = 0;
  const chunk = 250;
  for (let i = 0; i < rows.length; i += chunk) {
    const slice = rows.slice(i, i + chunk);
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: 'Bearer ' + SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ p_secret: secret, p_rows: slice }),
    });
    const data = await res.json().catch(() => null);
    if (!res.ok || !data || data.ok === false) {
      throw new Error((data && (data.error || data.message)) || ('Ingest HTTP ' + res.status));
    }
    applied += data.applied || 0;
    matched += data.matched || 0;
    unmatched += data.unmatched || 0;
  }
  return { applied, matched, unmatched };
}

async function runSync(apiKey, secret) {
  const all = [];
  let quizErrors = 0;
  await mapPool(QUIZZES, 8, async (quiz) => {
    try {
      const path = '/courses/' + quiz.course_id + '/lectures/' + quiz.lecture_id + '/quizzes/' + quiz.quiz_id + '/responses';
      const payload = await teachableGet(apiKey, path);
      const rows = collectRows(quiz, payload);
      all.push.apply(all, rows);
    } catch (e) {
      quizErrors += 1;
      console.error('quiz failed', quiz.lesson_code, e.message);
    }
  });
  const result = await ingest(secret, all);
  return {
    ok: true,
    quizzes: QUIZZES.length,
    rowCount: all.length,
    quizErrors,
    applied: result.applied,
    matched: result.matched,
    unmatched: result.unmatched,
  };
}

exports.handler = async function (event) {
  const apiKey = process.env.TEACHABLE_API_KEY;
  if (!apiKey) {
    return json(500, { ok: false, error: 'TEACHABLE_API_KEY is not set on Netlify. Add it under Site settings → Environment variables.' });
  }
  let secret = process.env.ATA_WEBHOOK_SECRET || '';
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
