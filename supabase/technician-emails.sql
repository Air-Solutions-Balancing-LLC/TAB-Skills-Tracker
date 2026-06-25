-- Populate technicians.email from the Airadigm employee directory.
-- Run in Supabase -> SQL Editor.
--
-- Matching is by NAME (case-insensitive, trimmed). This only updates technicians
-- that already exist; directory names with no matching technician are ignored.
-- Safe to run more than once (idempotent).
--
-- After sign-in, app_tech_azure_login() matches the verified Microsoft email to
-- technicians.email, so each technician lands on their own page automatically.

-- ── 1. Set emails, matched by name ───────────────────────────────────────────
UPDATE technicians t
SET email = v.email
FROM (VALUES
  ('Anatoliy Ilyuk',        'anatoliy.ilyuk@airadigmsolutions.com'),
  ('Andrew Parziale',       'andrew.parziale@airadigmsolutions.com'),
  ('Corey Crockett',        'corey.crockett@airadigmsolutions.com'),
  ('Dom Jean-Louis',        'dom.jean-louis@airadigmsolutions.com'),
  ('Don Beauchesne',        'don.beauchesne@airadigmsolutions.com'),
  ('Dylan Conner',          'dylan.conner@airadigmsolutions.com'),
  ('Eric Olson',            'eric.olson@airadigmsolutions.com'),
  ('Gary St. Clair',        'gary.stclair@airadigmsolutions.com'),
  ('Jimmy Anderson',        'jimmy.anderson@airadigmsolutions.com'),
  ('James Dupass',          'james.dupass@airadigmsolutions.com'),
  ('Jeremy Wickson',        'jeremy.wickson@airadigmsolutions.com'),
  ('Jonny Cascarano',       'jonny.cascarano@airadigmsolutions.com'),
  ('Kody Collins',          'kody.collins@airadigmsolutions.com'),
  ('Kurt Paradis',          'kurt.paradis@airadigmsolutions.com'),
  ('Luisander Ruiz',        'luisander.ruiz@airadigmsolutions.com'),
  ('Matt O''Brien',         'matt.obrien@airadigmsolutions.com'),
  ('Richard Wilson',        'richard.wilson@airadigmsolutions.com'),
  ('Sean Sutherland',       'sean.sutherland@airadigmsolutions.com'),
  ('Stavros Themeilis',     'stavros.themeilis@airadigmsolutions.com'),
  ('Thomas Ryan',           'thomas.ryan@airadigmsolutions.com'),
  ('Tyler LeBlanc',         'tyler.leblanc@airadigmsolutions.com'),
  ('Vinny Fitzpatrick',     'vinny.fitzpatrick@airadigmsolutions.com'),
  ('Alex Barajas',          'alex.barajas@kitchenenergysolutions.com'),
  ('Luis Rosendo',          'luis.rosendo@airadigmsolutions.com'),
  ('Zander Caron-Mitchell', 'zander.caron-mitchell@airadigmsolutions.com'),
  ('Markel Neely',          'markel.neely@airadigmsolutions.com'),
  ('Andres Bohorquez',      'andres.bohorquez@kitchenenergysolutions.com'),
  ('Daniel Lemus',          'daniel.lemus@airadigmsolutions.com'),
  ('Justin Holton',         'justin.holton@airadigmsolutions.com'),
  ('Phillip Michels',       'phillip.michels@airadigmsolutions.com'),
  ('Shane Reich',           'shane.reich@airadigmsolutions.com'),
  ('Chris Conejo',          'chris.conejo@airadigmsolutions.com'),
  ('Darwin Gomez',          'darwin.gomez@airadigmsolutions.com'),
  ('Eric Watkins',          'eric.watkins@airadigmsolutions.com'),
  ('Frederic Bahati',       'frederic.bahati@airadigmsolutions.com'),
  ('Jef Tucker',            'jef.tucker@airadigmsolutions.com'),
  ('Jonathan Gonzalez',     'jonathan.gonzalez@airadigmsolutions.com'),
  ('Keith Parker',          'keith.parker@airadigmsolutions.com'),
  ('Leonardo Cruz',         'leonardo.cruz@airadigmsolutions.com'),
  ('Marco Gaspar',          'marco.gaspar@airadigmsolutions.com'),
  ('Philip Lamb',           'philip.lamb@airadigmsolutions.com'),
  ('Tristan Taylor',        'tristan.taylor@airadigmsolutions.com'),
  ('Tim Bollinger',         'tim.bollinger@airadigmsolutions.com'),
  ('Adam Freeman',          'adam.freeman@airadigmsolutions.com'),
  ('Andrew Lacobee',        'andrew.lacobee@airadigmsolutions.com'),
  ('Brian Randolph',        'brian.randolph@airadigmsolutions.com'),
  ('Cameron Smith',         'cameron.smith@airadigmsolutions.com'),
  ('Ibriheem Muhammad',     'ibriheem.muhammad@airadigmsolutions.com'),
  ('Alfredo Salas',         'alfredo.salas@airadigmsolutions.com'),
  ('Austin Winters',        'austin.winters@airadigmsolutions.com'),
  ('Corey Sharrow',         'corey.sharrow@airadigmsolutions.com'),
  ('DeAndre Black',         'deandre.black@airadigmsolutions.com'),
  ('Grant Gugel',           'grant.gugel@airadigmsolutions.com'),
  ('Henry Boyle',           'henry.boyle@airadigmsolutions.com'),
  ('Joe Figone',            'joe.figone@airadigmsolutions.com'),
  ('Josh Earle',            'josh.earle@airadigmsolutions.com'),
  ('Josh Stepnick',         'josh.stepnick@airadigmsolutions.com'),
  ('Justin Bowman',         'justin.bowman@airadigmsolutions.com'),
  ('Nicholas Gray',         'nicholas.gray@airadigmsolutions.com'),
  ('Stranten Seui-Purdy',   'stranten.seui-purdy@airadigmsolutions.com'),
  ('Wayne Hamilton',        'wayne.hamilton@airadigmsolutions.com'),
  ('Wilson Rice',           'wilson.rice@airadigmsolutions.com'),
  ('James O''Brien',        'james.obrien@airadigmsolutions.com')
) AS v(name, email)
WHERE lower(trim(t.name)) = lower(trim(v.name));

-- ── 1b. Id-keyed fixes for technicians not in the directory ───────────────────
-- Alex Baichu (id 1) is not in the employee directory (which lists Alex Barajas,
-- a different person), so set his email directly.
UPDATE technicians SET email = 'alex.baichu@airadigmsolutions.com' WHERE id = 1;

-- ── 2. Verify: technicians still missing an email (need attention) ────────────
-- These are technicians whose table name did not match any directory name
-- (nicknames / spelling). Paste these back and we'll fix them by id.
SELECT id, name, region
FROM technicians
WHERE email IS NULL
ORDER BY name;

-- ── 3. Verify: directory names that matched no technician (ignored) ───────────
SELECT v.name
FROM (VALUES
  ('Anatoliy Ilyuk'), ('Andrew Parziale'), ('Corey Crockett'), ('Dom Jean-Louis'),
  ('Don Beauchesne'), ('Dylan Conner'), ('Eric Olson'), ('Gary St. Clair'),
  ('Jimmy Anderson'), ('James Dupass'), ('Jeremy Wickson'), ('Jonny Cascarano'),
  ('Kody Collins'), ('Kurt Paradis'), ('Luisander Ruiz'), ('Matt O''Brien'),
  ('Richard Wilson'), ('Sean Sutherland'), ('Stavros Themeilis'), ('Thomas Ryan'),
  ('Tyler LeBlanc'), ('Vinny Fitzpatrick'), ('Alex Barajas'), ('Luis Rosendo'),
  ('Zander Caron-Mitchell'), ('Markel Neely'), ('Andres Bohorquez'), ('Daniel Lemus'),
  ('Justin Holton'), ('Phillip Michels'), ('Shane Reich'), ('Chris Conejo'),
  ('Darwin Gomez'), ('Eric Watkins'), ('Frederic Bahati'), ('Jef Tucker'),
  ('Jonathan Gonzalez'), ('Keith Parker'), ('Leonardo Cruz'), ('Marco Gaspar'),
  ('Philip Lamb'), ('Tristan Taylor'), ('Tim Bollinger'), ('Adam Freeman'),
  ('Andrew Lacobee'), ('Brian Randolph'), ('Cameron Smith'), ('Ibriheem Muhammad'),
  ('Alfredo Salas'), ('Austin Winters'), ('Corey Sharrow'), ('DeAndre Black'),
  ('Grant Gugel'), ('Henry Boyle'), ('Joe Figone'), ('Josh Earle'),
  ('Josh Stepnick'), ('Justin Bowman'), ('Nicholas Gray'), ('Stranten Seui-Purdy'),
  ('Wayne Hamilton'), ('Wilson Rice'), ('James O''Brien')
) AS v(name)
LEFT JOIN technicians t ON lower(trim(t.name)) = lower(trim(v.name))
WHERE t.id IS NULL
ORDER BY v.name;
