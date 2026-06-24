# TAB Skills Tracker — Airadigm

## Setup Instructions

### 1. Configure Supabase credentials
Open `config.js` and replace the values:
```js
const SUPABASE_URL = 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_KEY = 'YOUR_PUBLISHABLE_KEY_HERE';
```

### 2. Configure Azure AD sign-in
In `config.js`, set your Microsoft Entra ID app registration values:
```js
const AZURE_CLIENT_ID = 'your-app-client-id';
const AZURE_TENANT_ID = 'your-tenant-id';
```

In [Azure Portal](https://portal.azure.com) → App registrations → your app → Authentication:
- Add a **Single-page application** redirect URI for each environment (e.g. `http://localhost:3000`, your Netlify URL)
- Enable **ID tokens** under Implicit grant (if shown)

Run `supabase/azure-login.sql` in the Supabase SQL Editor, then add each user's **Microsoft work email** to the `users.email` column.

### 3. Add users to Supabase
In Supabase Table Editor → `users` table, insert rows for each PM and technician.

**Project Manager example:**
| role | region | email                  | password    | tech_id |
|------|--------|------------------------|-------------|---------|
| pm   | RM     | pm@airadigm.com        | (legacy)    | (empty) |

**Technician example:**
| role       | region | email                  | password       | tech_id |
|------------|--------|------------------------|----------------|---------|
| technician | RM     | tech@airadigm.com      | (legacy)       | 1       |

### 4. Add technicians to Supabase
In `technicians` table, insert one row per technician.

### 5. Local development
```bash
npm install
npm run dev
```
Open `http://localhost:3000`

### 6. Deploy to Netlify
- Connect this GitHub repo to Netlify
- No build command needed
- Publish directory: `/` (root)

### 7. Connect Power Automate
Point your Power Automate flow to POST to:
`https://your-project.supabase.co/rest/v1/assessments`

## Files
- `index.html` — the full app
- `config.js` — Supabase and Azure credentials (keep private)
- `azure-sign-in.png` — Microsoft sign-in button
- `supabase/azure-login.sql` — Supabase migration for Azure login
- `README.md` — this file
