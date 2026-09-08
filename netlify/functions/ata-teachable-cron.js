// Daily wrapper. Netlify will not let a scheduled function also serve the
// admin Sync button (HTTP 403). This file only runs on the cron.
const { handler } = require('./ata-teachable-sync');
exports.handler = handler;
