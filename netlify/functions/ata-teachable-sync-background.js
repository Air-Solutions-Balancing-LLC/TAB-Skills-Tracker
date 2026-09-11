// Background Teachable sync (up to 15 minutes). The admin button POSTs here
// so Netlify does not 504 the short HTTP function. Daily cron only triggers this.
const { handler } = require('./ata-teachable-sync');
exports.handler = handler;
