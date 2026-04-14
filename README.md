# TAB Skills Tracker — Airadigm

## Setup Instructions

### 1. Configure Supabase credentials
Open `config.js` and replace the values:
```js
const SUPABASE_URL = 'https://vwjizsgmfjwgnaojgkmt.supabase.co';
const SUPABASE_KEY = 'YOUR_PUBLISHABLE_KEY_HERE';
```

### 2. Add users to Supabase
In Supabase Table Editor → `users` table, insert rows for each PM and technician.

**Project Manager example:**
| role | region | password    | tech_id |
|------|--------|-------------|---------|
| pm   | RM     | Denver#483  | (empty) |

**Technician example:**
| role       | region | password       | tech_id |
|------------|--------|----------------|---------|
| technician | RM     | Richard#son47  | 1       |

### 3. Add technicians to Supabase
In `technicians` table, insert one row per technician.

### 4. Deploy to Netlify
- Connect this GitHub repo to Netlify
- No build command needed
- Publish directory: `/` (root)

### 5. Connect Power Automate
Point your Power Automate flow to POST to:
`https://your-project.supabase.co/rest/v1/assessments`

## Files
- `index.html` — the full app
- `config.js` — Supabase credentials (keep private)
- `README.md` — this file
