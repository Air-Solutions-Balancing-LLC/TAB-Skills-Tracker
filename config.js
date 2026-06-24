// ============================================
// SUPABASE
// SUPABASE_KEY is the publishable / anon key (safe in the browser; protected by RLS).
// If sign-in fails to start, grab the "anon public" key from
// Supabase → Settings → API and paste it here.
// ============================================

const SUPABASE_URL = 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_KEY = 'sb_publishable_hh7_CD_TuH0X3YugPn_Z6w_VWSAAvlb';

const REGION_LABELS = {
  RM: 'Rocky Mountain',
  SW: 'Southwest',
  SE: 'Southeast',
  NE: 'New England',
  National: 'National',
  Survey: 'Survey'
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
