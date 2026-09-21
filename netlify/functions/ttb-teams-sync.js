// TTB — pull Teams attendance for the recurring Training Touch Base via Microsoft Graph.
// Admin button: POST /.netlify/functions/ttb-teams-sync  {secret}
// Friday cron:  ttb-teams-cron.js POSTs here after the Thursday meeting.
//
// Netlify env (application permissions + admin consent + application access policy
// granted to the meeting organizer):
//   AZURE_TENANT_ID
//   AZURE_TTB_CLIENT_ID      (or AZURE_CLIENT_ID)
//   AZURE_TTB_CLIENT_SECRET
//   ATA_WEBHOOK_SECRET
// Optional overrides:
//   TTB_ORGANIZER_EMAIL
//   TTB_MEETING_JOIN_URL
//   TTB_MEETING_CODE         (default 2844141263142)

const https = require('https');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY ||
  'sb_publishable_hh7_CD_TuH0X3YugPn_Z6w_VWSAAvlb';
const DEFAULT_JOIN = 'https://teams.microsoft.com/meet/2844141263142?p=jHgN3ZFQy0PnVLd4KW';
const DEFAULT_CODE = '2844141263142';
const DEFAULT_ORGANIZER = 'brenda.zwickau@airadigmsolutions.com';
const DEFAULT_TENANT = '6d015a36-0af2-451c-8f51-03feaae541d6';

function env(name) {
  return (process.env && process.env[name]) || '';
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
    body: JSON.stringify(body),
  };
}

function request(method, urlStr, headers, body, contentType) {
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
      }, headers || {}, payload ? {
        'Content-Type': contentType || 'application/json',
        'Content-Length': String(payload.length),
      } : {}),
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

async function graphToken(tenant, clientId, clientSecret) {
  const res = await request(
    'POST',
    'https://login.microsoftonline.com/' + encodeURIComponent(tenant) + '/oauth2/v2.0/token',
    {},
    'client_id=' + encodeURIComponent(clientId)
      + '&client_secret=' + encodeURIComponent(clientSecret)
      + '&scope=' + encodeURIComponent('https://graph.microsoft.com/.default')
      + '&grant_type=client_credentials',
    'application/x-www-form-urlencoded'
  );
  if (res.status < 200 || res.status >= 300 || !res.json || !res.json.access_token) {
    const err = (res.json && (res.json.error_description || res.json.error)) || ('token HTTP ' + res.status);
    throw new Error('Azure login failed — ' + err);
  }
  return res.json.access_token;
}

async function graphGet(token, path) {
  const res = await request('GET', 'https://graph.microsoft.com/v1.0' + path, {
    Authorization: 'Bearer ' + token,
  });
  if (res.status < 200 || res.status >= 300) {
    const err = (res.json && (res.json.error && res.json.error.message)) || ('Graph HTTP ' + res.status);
    const e = new Error(err + ' ' + path);
    e.status = res.status;
    e.body = res.json;
    throw e;
  }
  return res.json;
}

function meetingCode(joinUrl) {
  const fromEnv = String(env('TTB_MEETING_CODE') || '').trim();
  if (fromEnv) return fromEnv;
  const m = String(joinUrl || '').match(/\/meet\/(\d+)/);
  return (m && m[1]) || DEFAULT_CODE;
}

function nyDate(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
}

function earliest(intervals, key) {
  let best = null;
  for (const it of intervals || []) {
    const v = it && it[key];
    if (!v) continue;
    if (!best || v < best) best = v;
  }
  return best;
}

function latest(intervals, key) {
  let best = null;
  for (const it of intervals || []) {
    const v = it && it[key];
    if (!v) continue;
    if (!best || v > best) best = v;
  }
  return best;
}

function recordRows(records) {
  return (records || []).map((r) => {
    const intervals = r.attendanceIntervals || [];
    return {
      email: r.emailAddress || (r.identity && r.identity.userPrincipalName) || '',
      name: (r.identity && r.identity.displayName) || r.emailAddress || '',
      first_join: earliest(intervals, 'joinDateTime') || r.joinDateTime || null,
      last_leave: latest(intervals, 'leaveDateTime') || r.leaveDateTime || null,
      duration_seconds: r.totalAttendanceInSeconds != null ? Number(r.totalAttendanceInSeconds) : null,
    };
  }).filter((r) => r.email || r.name);
}

async function resolveOrganizer(token, email) {
  const clean = String(email || '').trim();
  if (!clean) throw new Error('Organizer email is empty. Save it in Admin → TTB settings.');
  const user = await graphGet(token, '/users/' + encodeURIComponent(clean) + '?$select=id,displayName,mail,userPrincipalName');
  if (!user || !user.id) throw new Error('Graph could not find organizer ' + clean);
  return user;
}

async function findOnlineMeeting(token, organizerId, joinUrl) {
  const code = meetingCode(joinUrl);
  const tries = [
    '/users/' + organizerId + '/onlineMeetings?$filter=' + encodeURIComponent("VideoTeleconferenceId eq '" + code + "'"),
  ];
  const urls = [joinUrl, DEFAULT_JOIN].filter(Boolean);
  urls.forEach((u) => {
    tries.push('/users/' + organizerId + '/onlineMeetings?$filter=' + encodeURIComponent("JoinWebUrl eq '" + u + "'"));
  });
  for (const path of tries) {
    try {
      const payload = await graphGet(token, path);
      const row = (payload && payload.value && payload.value[0]) || null;
      if (row && row.id) return row;
    } catch (e) {
      if (e && e.status === 403) throw e;
    }
  }
  return null;
}

async function calendarOccurrences(token, organizerId, joinUrl, sinceIso) {
  const start = sinceIso || new Date(Date.now() - 21 * 86400000).toISOString();
  const end = new Date(Date.now() + 2 * 86400000).toISOString();
  const path = '/users/' + organizerId
    + '/calendar/calendarView?startDateTime=' + encodeURIComponent(start)
    + '&endDateTime=' + encodeURIComponent(end)
    + '&$select=id,subject,start,end,isCancelled,onlineMeeting'
    + '&$top=80';
  try {
    const payload = await graphGet(token, path);
    const code = meetingCode(joinUrl);
    return (payload.value || []).filter((ev) => {
      const url = ev.onlineMeeting && ev.onlineMeeting.joinUrl;
      if (url && String(url).indexOf(code) !== -1) return true;
      const sub = String(ev.subject || '');
      return /TTB|Training Touch Base/i.test(sub);
    });
  } catch (e) {
    if (e && e.status === 403) return { forbidden: true, error: e.message };
    return { error: (e && e.message) || String(e) };
  }
}

async function attendanceForMeeting(token, organizerId, meetingId) {
  const reports = await graphGet(
    token,
    '/users/' + organizerId + '/onlineMeetings/' + encodeURIComponent(meetingId) + '/attendanceReports'
  );
  const list = (reports && reports.value) || [];
  if (!list.length) return null;
  list.sort((a, b) => String(b.meetingEndDateTime || '').localeCompare(String(a.meetingEndDateTime || '')));
  const report = list[0];
  const recs = await graphGet(
    token,
    '/users/' + organizerId + '/onlineMeetings/' + encodeURIComponent(meetingId)
      + '/attendanceReports/' + encodeURIComponent(report.id) + '/attendanceRecords'
  );
  return {
    report,
    rows: recordRows(recs && recs.value),
  };
}

async function ingest(secret, session, rows) {
  const url = SUPABASE_URL.replace(/\/$/, '') + '/rest/v1/rpc/app_ttb_import_attendance';
  const res = await request('POST', url, {
    apikey: SUPABASE_ANON_KEY,
    Authorization: 'Bearer ' + SUPABASE_ANON_KEY,
  }, { p_secret: secret, p_session: session, p_rows: rows });
  const data = res.json;
  if (res.status < 200 || res.status >= 300 || !data || data.ok === false) {
    throw new Error((data && (data.error || data.message || data.hint)) || ('TTB ingest HTTP ' + res.status));
  }
  return data;
}

async function loadSettings(secret) {
  const url = SUPABASE_URL.replace(/\/$/, '') + '/rest/v1/rpc/app_ttb_settings';
  let fromDb = {};
  try {
    const res = await request('POST', url, {
      apikey: SUPABASE_ANON_KEY,
      Authorization: 'Bearer ' + SUPABASE_ANON_KEY,
    }, { p_secret: secret });
    if (res.json && res.json.ok) fromDb = res.json;
  } catch (_) { /* env fallback */ }
  return {
    organizer_email: String(env('TTB_ORGANIZER_EMAIL') || fromDb.organizer_email || DEFAULT_ORGANIZER).trim(),
    meeting_join_url: String(env('TTB_MEETING_JOIN_URL') || fromDb.meeting_join_url || DEFAULT_JOIN).trim(),
    secret,
  };
}

async function runSync(secret, body) {
  const tenant = String(env('AZURE_TENANT_ID') || DEFAULT_TENANT).trim();
  const clientId = String(env('AZURE_TTB_CLIENT_ID') || env('AZURE_CLIENT_ID') || '').trim();
  const clientSecret = String(env('AZURE_TTB_CLIENT_SECRET') || '').trim();
  if (!clientId || !clientSecret) {
    throw new Error('AZURE_TTB_CLIENT_ID and AZURE_TTB_CLIENT_SECRET are not set on Netlify. Add them (application permissions OnlineMeetings.Read.All + OnlineMeetingArtifact.Read.All), grant admin consent, then grant an application access policy to the meeting organizer.');
  }

  const settings = await loadSettings(secret);
  const organizerEmail = String((body && body.organizer_email) || settings.organizer_email || '').trim();
  const joinUrl = String((body && body.meeting_join_url) || settings.meeting_join_url || DEFAULT_JOIN).trim();
  if (!organizerEmail) {
    throw new Error('Save the organizer email in Admin → TTB, or set TTB_ORGANIZER_EMAIL on Netlify.');
  }

  const token = await graphToken(tenant, clientId, clientSecret);
  const organizer = await resolveOrganizer(token, organizerEmail);

  const wantedDate = body && body.meeting_date;
  const imported = [];
  let hint = '';

  const cal = await calendarOccurrences(token, organizer.id, joinUrl);
  const events = Array.isArray(cal) ? cal : [];
  if (cal && cal.forbidden) {
    hint = 'Calendar read was denied. Add Calendars.Read (application) or we will try the series meeting id only.';
  }

  const targets = [];
  for (const ev of events) {
    if (ev.isCancelled) continue;
    const start = ev.start && (ev.start.dateTime || ev.start);
    const date = nyDate(start && (String(start).endsWith('Z') || String(start).includes('+') ? start : String(start) + 'Z'));
    // calendarView dateTime is typically UTC without Z when timezone is specified — use the timezone field.
    const evDate = ev.start && ev.start.timeZone
      ? nyDate(ev.start.dateTime + (ev.start.timeZone === 'UTC' ? 'Z' : ''))
      : date;
    const meetingDate = evDate || date;
    if (wantedDate && meetingDate !== wantedDate) continue;
    if (meetingDate && meetingDate > nyDate(new Date().toISOString())) continue;
    const join = ev.onlineMeeting && ev.onlineMeeting.joinUrl;
    let meeting = null;
    if (join) {
      try {
        const found = await graphGet(
          token,
          '/users/' + organizer.id + '/onlineMeetings?$filter=' + encodeURIComponent("JoinWebUrl eq '" + join + "'")
        );
        meeting = found && found.value && found.value[0];
      } catch (_) { /* try series id below */ }
    }
    if (!meeting) meeting = await findOnlineMeeting(token, organizer.id, join || joinUrl);
    if (meeting && meeting.id) targets.push({ meetingDate, meetingId: meeting.id, subject: ev.subject || '' });
  }

  if (!targets.length) {
    const series = await findOnlineMeeting(token, organizer.id, joinUrl);
    if (series && series.id) {
      targets.push({
        meetingDate: wantedDate || nyDate(series.endDateTime || series.startDateTime || new Date().toISOString()),
        meetingId: series.id,
        subject: series.subject || 'TTB',
      });
    }
  }

  if (!targets.length) {
    throw new Error('Could not find the TTB online meeting. Check the organizer email, application access policy, and that attendance reports are enabled. ' + hint);
  }

  const seen = new Set();
  for (const t of targets) {
    const key = t.meetingId + '|' + t.meetingDate;
    if (seen.has(key)) continue;
    seen.add(key);
    try {
      const att = await attendanceForMeeting(token, organizer.id, t.meetingId);
      if (!att || !att.rows.length) {
        imported.push({ meeting_date: t.meetingDate, skipped: true, reason: 'no_report_yet' });
        continue;
      }
      const meetingDate = t.meetingDate || nyDate(att.report.meetingStartDateTime);
      const result = await ingest(secret, {
        meeting_date: meetingDate,
        topic: t.subject || null,
        teams_meeting_id: t.meetingId,
        teams_report_id: att.report.id,
      }, att.rows);
      imported.push(result);
    } catch (e) {
      imported.push({ meeting_date: t.meetingDate, ok: false, error: (e && e.message) || String(e) });
    }
  }

  return {
    ok: true,
    organizer: organizer.userPrincipalName || organizerEmail,
    imported,
    calendarHint: hint || null,
  };
}

exports.handler = async function (event) {
  let secret = env('ATA_WEBHOOK_SECRET');
  let body = {};
  if (event && event.body) {
    try {
      body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      if (body && body.secret) secret = body.secret;
    } catch (_) { /* ignore */ }
  }
  if (!secret) {
    return json(500, { ok: false, error: 'Missing ATA webhook secret. Set ATA_WEBHOOK_SECRET on Netlify, or open ATA Zapier setup once.' });
  }
  try {
    return json(200, await runSync(secret, body));
  } catch (e) {
    return json(502, { ok: false, error: (e && e.message) || 'Teams attendance sync failed.' });
  }
};
