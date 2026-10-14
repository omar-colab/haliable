# Deploying the site to Netlify

Plain static deploy. **Nothing here uses Netlify AI, and nothing uses build
minutes** — `netlify.toml` has no build command, so Netlify just copies `site/`
and bundles the functions. Don't enable any AI add-on when prompted.

## One time

1. app.netlify.com → **Add new site → Import an existing project → GitHub** →
   pick `omar-colab/haliable`.
2. Build settings — leave them alone. `netlify.toml` already says:
   - publish directory `site`
   - functions directory `netlify/functions`
   - **build command: empty.** If Netlify pre-fills one, clear it.
3. Deploy. You get `random-name-123.netlify.app`.
4. **Site configuration → Change site name → `haliable`**, so the URL becomes
   `https://haliable.netlify.app`. That exact name matters — it's hardcoded in
   `Haliable/Services/Supabase/SupabaseConfig.swift` as `functionsBase`.

## Environment variables

Site configuration → Environment variables. Names are in
`netlify/functions/.env.example`; paste the values from the provider dashboards.
Never put them in the repo.

- Waitlist now: `MAILERLITE_API_KEY`, `MAILERLITE_GROUP_ID`
- Sign in with Apple, Phase 3: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`,
  `APPLE_PRIVATE_KEY`, `SUPABASE_URL`, `SUPABASE_SECRET_KEY`

## Check it worked

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://haliable.netlify.app/
curl -sS -o /dev/null -w '%{http_code}\n' https://haliable.netlify.app/privacy/
curl -sS -X POST https://haliable.netlify.app/.netlify/functions/subscribe \
  -H 'Content-Type: application/json' -d '{"email":"you+test@gmail.com"}'
```

The privacy URL is what App Store Connect asks for, so it has to be live before
Phase 5.

## Preview locally first

```bash
cd site && python3 -m http.server 8787   # then open http://127.0.0.1:8787/
```

The waitlist form won't work locally — there's no functions runtime — but every
page and link will.
