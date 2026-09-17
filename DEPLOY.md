# Deploying RowdyRoboVac

The game works with no backend at all — without credentials every network call is
a no-op and events stay on the device. These steps add the backend and put it
online.

Steps 1, 2, 5 and 7 need an account or a Godot install, so they are yours.
Everything else is already wired.

---

## 1. Create the Supabase project

1. At <https://supabase.com/dashboard>, create a new project.
2. Pick a region near your school and save the database password somewhere safe
   (this game never needs it).
3. Wait for provisioning to finish.

> Use a **new project**, not the one behind MOSAIC or an earlier study. The event
> taxonomy is different, and mixing two instruments in one `events` table makes
> every analysis query start with a filter you will eventually forget.

## 2. Create the tables

Open **SQL Editor**, paste [`supabase/schema.sql`](supabase/schema.sql), run it.
Safe to re-run.

Then confirm RLS is actually on — this is the check worth doing by hand:

```sql
select tablename, rowsecurity from pg_tables where schemaname = 'public' and tablename in ('sessions','events','scores');
```

All three rows must show `rowsecurity = true`. If they do not, one student can
read every other student's session.

## 3. Get the keys

**Project Settings → API**:

- **Project URL** → `supabase_url`
- **anon / public** key → `supabase_anon_key`

The anon key is *meant* to be public; it ships in the build and anyone can read
it from devtools. RLS is what protects the data.

> **Never** put the `service_role` key in this game, in `config.json`, or in the
> repo. It bypasses RLS completely. Use it only from your own machine when
> pulling data for analysis.

## 4. Fill in the credentials

Put both values in [`config.json`](config.json) at the project root:

```json
{
  "supabase_url": "https://YOUR-PROJECT-REF.supabase.co",
  "supabase_anon_key": "your-anon-public-key"
}
```

`config.json` is **gitignored**. Copy `config.example.json` to start.

On a web build the game fetches `/config.json` from whatever host it is served
from, **not** the copy baked into the `.pck`. That indirection is the point: you
can repoint an already-deployed build at a different Supabase project by editing
`web/config.json` and redeploying, with no Godot and no re-export.

## 5. Test on desktop

Open the project in Godot and play it. In Supabase → **Table Editor** you should
see one `sessions` row and a stream of `events` rows with `seq` starting at 1 and
no gaps.

## 6. Export the web build

**Vercel cannot run the Godot exporter**, so the build is produced here and
uploaded. `web/` is gitignored: `index.pck` bakes in whatever `config.json` held
at export time, so committing it would publish your Supabase key, and each
export is about 40MB of git history.

```powershell
.\tools\export-web.ps1 -Godot "C:\path\to\Godot_v4.5-stable_win64.exe"
```

> **The Godot version must match your installed export templates.** Check with
> `ls $env:APPDATA\Godot\export_templates`. Right now that directory has
> **4.5.stable** only, and `project.godot` declares `4.5` — so export with a
> **Godot 4.5.stable** editor. Opening the project in 4.6.x will migrate the
> project files as a side effect, which is not something to discover the week of
> a study.

The preset builds with **thread support off**. That means no `SharedArrayBuffer`,
which means no `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`
headers to get right and nothing extra to debug on school Chromebooks. The
project already renders with GL Compatibility, so nothing is lost.

Serve `web/` locally and play it through before deploying:

```powershell
python -m http.server 8000 --directory web
```

## 7. Deploy to Vercel

The build folder is uploaded directly — there is no git-triggered deploy, and
nothing for Vercel to build:

```bash
cd web
npx vercel deploy --prod
```

First run asks you to log in and name the project; after that it is the same two
lines every time. Deploying the folder rather than the repo is deliberate: a
push-to-deploy setup would happily ship a stale build whenever you pushed source
without re-exporting.

[`tools/vercel.json`](tools/vercel.json) is copied into `web/` by the export
script, because `web/` is the deploy root. It sets the security headers and
deliberately has **no rewrites** — a single-page-app rewrite like MOSAIC's would
swallow `index.wasm` and `index.pck`, and a Godot build loads those by exact
path.

There are no environment variables to set. The credentials travel in
`web/config.json`, which is part of the uploaded folder.

**The full loop for any change** is: edit → `tools/export-web.ps1` → play
through locally → `npx vercel deploy --prod`.

---

## Study-day checklist

- Full run on the actual classroom hardware, not a laptop standing in for it.
- Test on the school network, not your office wifi — a proxy that blocks the
  Supabase domain fails silently by design.
- Airplane mode mid-session: the game continues, events flush when the network
  returns.
- Refresh mid-session: same session id, no duplicate `sessions` row.
- **Free Supabase projects pause after about a week idle** and take a minute or
  two to wake. Wake it the morning of, and **test the wake path at least once** —
  the first student otherwise hits a dead endpoint.
- The web build is about **40MB** on first load (36MB of that is the engine
  itself, `index.wasm`). Load it once on a classroom device and confirm how long
  that takes on the school network — and remember every student downloads it.

## If a device never reached the network

Queued events sit in `user://event_queue.json` (IndexedDB on web) together with
the session row in `user://session.json`, and both go up on the next load of the
same browser profile. The fix is usually just to reopen the page on that same
device while it has a network — the student does not need to re-enter anything.

On desktop the CSV at `user://student_data.csv` is still written, as it always
was. On web that path is IndexedDB inside the student's own browser and is not
recoverable after the fact — the queue is the real record there.

## Pulling the data

From your own machine, with the service_role key (never in the game):

```sql
select s.id, s.first_name, s.last_initial, s.grade, min(e.server_ts) filter (where e.type = 'session_start') as started, max(e.server_ts) filter (where e.type = 'session_end') as ended, bool_or(e.type = 'session_end') as completed from sessions s left join events e on e.session_id = s.id group by s.id order by started;
```

More starter queries — time per phase, run-vs-submit counts, and the actual
programs students wrote — are at the bottom of `supabase/schema.sql`.
