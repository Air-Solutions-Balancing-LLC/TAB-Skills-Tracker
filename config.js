// ============================================
// SUPABASE
// SUPABASE_KEY is the publishable / anon key (safe in the browser; protected by RLS).
// If sign-in fails to start, grab the "anon public" key from
// Supabase → Settings → API and paste it here.
// ============================================

const SUPABASE_URL = 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_KEY = 'sb_publishable_hh7_CD_TuH0X3YugPn_Z6w_VWSAAvlb';

const REGION_LABELS = {
  IM: 'Intermountain',
  KES: 'KES',
  MA: 'Mid-Atlantic',
  MW: 'Midwest',
  National: 'National',
  NE: 'New England',
  PC: 'Pacific Coast',
  RM: 'Rocky Mountain',
  SE: 'Southeast',
  SW: 'Southwest'
};

// ============================================
// AZURE AD (Microsoft Entra ID)
// Microsoft sign-in now runs through Supabase Auth (Authentication → Providers →
// Azure), NOT in the browser. These values are kept here only for reference —
// paste them into the Supabase Azure provider settings along with a client secret.
// The browser no longer reads them.
// ============================================

const AZURE_CLIENT_ID = '61c54fd8-5b63-4807-8514-dc1dc2e9c4bf';
const AZURE_TENANT_ID = '6d015a36-0af2-451c-8f51-03feaae541d6';

// ============================================
// ATA TRACKING — Google Sheet quiz feed
// The "Update from Sheet" button calls the Netlify function
// /.netlify/functions/ata-sheet, which reads the sheet server-side (Google does
// not send CORS headers, and the quiz data is split across one tab per technician
// named "Quiz History - <Name>"). ATA_SHEET_URL is only used for the "Open Sheet"
// link. The sheet must be shared so "Anyone with the link can view". To point at
// a different sheet, set the ATA_SHEET_ID environment variable in Netlify and
// update ATA_SHEET_URL below.
// ============================================

const ATA_SHEET_URL = 'https://docs.google.com/spreadsheets/d/1gsDfKRFfEmLi87UT7UaahWQW_zJ5AcjV0LPD1I18F00/edit?gid=0#gid=0';
