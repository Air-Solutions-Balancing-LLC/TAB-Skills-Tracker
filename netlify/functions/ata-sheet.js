// ATA Tracking — Google Sheet importer (server-side).
//
// Why this runs on the server: the published Google Sheet is exported as CSV via
// the gviz endpoint, which does NOT return an Access-Control-Allow-Origin header,
// so a browser fetch is blocked by CORS. The quiz data also lives on one tab per
// technician ("Quiz History - <Name>"), so we discover the tabs from the sheet's
// htmlview, fetch each tab's CSV, and return a flat list of completions.
//
// Response: { ok, tabCount, rowCount, names, rows: [{ name, lesson_code, score, status }] }
//   * name        — technician name (tab title minus the "Quiz History - " prefix)
//   * lesson_code — e.g. "TAB-B-101"
//   * score       — percent (number) when the cell is "n/m", else null
//   * status      — the raw Score/Status cell text (for reference)
//
// The sheet id can be overridden with the ATA_SHEET_ID environment variable.

const https = require('https');

const DEFAULT_SHEET_ID = '1gsDfKRFfEmLi87UT7UaahWQW_zJ5AcjV0LPD1I18F00';

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { 'User-Agent': 'Mozilla/5.0 (compatible; TABSkillsTracker/1.0)' } }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          resolve(fetchText(res.headers.location));
          return;
        }
        if (res.statusCode !== 200) {
          reject(new Error('HTTP ' + res.statusCode + ' for ' + url));
          res.resume();
          return;
        }
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve(data));
      })
      .on('error', reject);
  });
}

function parseCsv(text) {
  const rows = [];
  let row = [], cur = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; }
      else cur += ch;
    } else {
      if (ch === '"') q = true;
      else if (ch === ',') { row.push(cur); cur = ''; }
      else if (ch === '\n') { row.push(cur); rows.push(row); row = []; cur = ''; }
      else if (ch === '\r') { /* skip */ }
      else cur += ch;
    }
  }
  if (cur !== '' || row.length) { row.push(cur); rows.push(row); }
  return rows;
}

// "12/15" -> 80 ; "5/5" -> 100 ; "Complete (no score shown)" -> null (still complete)
// Returns { completed: boolean, score: number|null }.
function interpretScore(cell) {
  const s = String(cell || '').trim();
  if (!s) return { completed: false, score: null };
  if (/not\s*taken|not\s*started|no\s*attempt|incomplete|in\s*progress/i.test(s)) {
    return { completed: false, score: null };
  }
  const frac = /^(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$/.exec(s);
  if (frac) {
    const den = parseFloat(frac[2]);
    const num = parseFloat(frac[1]);
    return { completed: true, score: den > 0 ? Math.round((num / den) * 1000) / 10 : null };
  }
  const pct = /^(\d+(?:\.\d+)?)\s*%$/.exec(s);
  if (pct) return { completed: true, score: parseFloat(pct[1]) };
  // "Complete (no score shown)", "No score recorded", "Passed", etc. → completed, no number.
  return { completed: true, score: null };
}

function extractTabs(htmlviewHtml) {
  const tabs = [];
  const re = /name: "((?:[^"\\]|\\.)*)", pageUrl: "[^"]*gid=(\d+)"/g;
  let m;
  while ((m = re.exec(htmlviewHtml)) !== null) {
    const name = m[1].replace(/\\(.)/g, '$1');
    tabs.push({ name, gid: m[2] });
  }
  return tabs;
}

exports.handler = async function () {
  const sheetId = process.env.ATA_SHEET_ID || DEFAULT_SHEET_ID;
  const base = 'https://docs.google.com/spreadsheets/d/' + sheetId;
  try {
    const html = await fetchText(base + '/htmlview');
    const tabs = extractTabs(html).filter((t) => /^Quiz History\s*-\s*/i.test(t.name));
    if (!tabs.length) {
      return json(502, { ok: false, error: 'No "Quiz History" tabs found. Make sure the sheet is shared so anyone with the link can view.' });
    }

    const rows = [];
    const names = [];
    // Fetch tabs with limited concurrency to be polite.
    const concurrency = 5;
    for (let i = 0; i < tabs.length; i += concurrency) {
      const batch = tabs.slice(i, i + concurrency);
      const results = await Promise.all(
        batch.map(async (tab) => {
          const csv = await fetchText(base + '/gviz/tq?tqx=out:csv&gid=' + tab.gid);
          return { tab, grid: parseCsv(csv) };
        })
      );
      results.forEach(({ tab, grid }) => {
        const techName = tab.name.replace(/^Quiz History\s*-\s*/i, '').trim();
        names.push(techName);
        grid.forEach((r) => {
          if (!r || r.length < 3) return;
          const quiz = String(r[1] || '');
          const codeMatch = /TAB-[BIA]-\d+/i.exec(quiz);
          if (!codeMatch) return;
          const info = interpretScore(r[2]);
          if (!info.completed) return;
          rows.push({
            name: techName,
            lesson_code: codeMatch[0].toUpperCase(),
            score: info.score,
            status: String(r[2] || '').trim(),
          });
        });
      });
    }

    return json(200, { ok: true, tabCount: tabs.length, rowCount: rows.length, names, rows });
  } catch (e) {
    return json(502, { ok: false, error: (e && e.message) || 'Failed to read the sheet.' });
  }
};

function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
    body: JSON.stringify(body),
  };
}
