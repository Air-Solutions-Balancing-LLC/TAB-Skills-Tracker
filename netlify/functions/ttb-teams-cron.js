// Friday trigger — TTB meeting is Thursday 2pm ET; Paula runs the report Friday.
const https = require('https');

function postJson(urlStr, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const payload = Buffer.from(JSON.stringify(body));
    const req = https.request({
      protocol: u.protocol,
      hostname: u.hostname,
      port: u.port || 443,
      path: u.pathname + u.search,
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'Content-Length': String(payload.length),
        'User-Agent': 'TABSkillsTracker/1.0',
      },
    }, (res) => {
      res.resume();
      res.on('end', () => resolve(res.statusCode || 0));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout invoking TTB sync')));
    req.write(payload);
    req.end();
  });
}

exports.handler = async function () {
  const secret = String((process.env && process.env.ATA_WEBHOOK_SECRET) || '').trim();
  if (!secret) {
    return { statusCode: 500, body: 'ATA_WEBHOOK_SECRET is not set on Netlify.' };
  }
  const base = String(process.env.URL || process.env.DEPLOY_PRIME_URL || 'https://tabskillstracking.netlify.app').replace(/\/$/, '');
  const status = await postJson(base + '/.netlify/functions/ttb-teams-sync', { secret });
  if (status < 200 || status >= 300) {
    return { statusCode: 502, body: 'TTB sync HTTP ' + status };
  }
  return { statusCode: 200, body: 'started' };
};
