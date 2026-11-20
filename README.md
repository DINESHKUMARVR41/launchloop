# LaunchLoop

**Build it. Deploy it. Get discovered. Improve it. Grow it.**

LaunchLoop is an independent discovery, feedback and growth companion for AI app builders and indie developers. It is not an official Embarko integration, and is not affiliated with or endorsed by Embarko.

## Stack

- React 18 + TypeScript + Vite
- Framer Motion for purposeful interface motion
- Express 4 API server
- Supabase Auth, Postgres and Row Level Security
- Gemini API (server-side only)
- Recharts and `qrcode.react`

## Features

- Responsive landing page and public app directory (search, category filters, sort, skeleton loading and empty states).
- AnimatePresence route transitions, staggered section entrances, animated feedback/QR/toast/chart surfaces, mobile-nav entrance and reduced-motion support.
- Application submission, public showcase, tags, technology stack, edit/delete management and QR sharing.
- Discovery search, category filters and newest/oldest/name sorting.
- Public bug reports, feature requests, experience notes and 1–5 ratings without visitor sign-in.
- Creator email/password registration, login, logout and session persistence when Supabase is configured.
- Authenticated application ownership (`applications.user_id`) and owner-scoped management / analytics.
- Creator dashboard with actual showcase views, outbound clicks, feedback and ratings. The seven-day chart is event-backed; no synthetic traffic is generated. Sample apps never emit analytics events. Event writes are deduplicated per application/type/browser-tab session with a database unique index.
- Evidence-backed feedback analysis with counts calculated from the source records, exact-message grounding for AI priorities/tasks, priority rationale and acceptance criteria. When Gemini is missing or fails, explicitly labelled rule-based/template fallbacks are returned.
- Platform-specific launch assets with selectable tone; Gemini generation is grounded in the stored application description. Template fallbacks are persistently labelled as non-AI.
- Improvement Copilot prompts for Claude, ChatGPT and Cursor, including product context, evidence, expected outcome, acceptance criteria and test steps.
- Local browser demo mode with clearly marked sample apps and sample feedback.
- Delete-own-application action in the creator workspace.

## Requirements

- Node.js 20 or newer (Node 22 recommended)
- npm 10+
- Supabase project for shared persistence and secure creator accounts (optional for local demo)
- Gemini API key for Gemini-powered analysis/content (optional; fallbacks remain available)

## Windows PowerShell setup

```powershell
# 1. Extract the ZIP and enter the project directory
Set-Location .\launchloop

# 2. Install dependencies
npm install

# 3. Create local environment file
Copy-Item .env.example .env

# 4. Start Vite and the Express API together
npm run dev
```

Open the Vite URL printed in the terminal (normally `http://localhost:5173`). The API listens on `http://localhost:8787`.

For a local no-credential demo, leave Supabase and Gemini values blank (or remove the placeholder values). Local submissions, feedback and events are stored in browser `localStorage`; they are not shared between browsers or devices. Local creator-name identity is explicitly a demo convenience, not authentication.

## Supabase setup

### New Supabase project

1. Create a Supabase project.
2. Open **SQL Editor**.
3. Run `supabase/schema.sql`.
4. In Supabase **Authentication → Providers**, enable Email.
5. Configure the email confirmation policy you want. With confirmation enabled, new users must confirm their email before signing in.
6. Copy the project URL and anon/publishable key into `.env`:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
7. For shared public feedback and event tracking, also configure `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in the Node server environment only. The URL may match `VITE_SUPABASE_URL`; the service-role key must never be exposed to the browser.
8. Restart Vite and the Node API.

### Existing LaunchLoop database

If you already ran the original schema, run `supabase/migrations/002_auth_ownership.sql` instead of re-running the fresh schema. Back up the database first. Legacy applications receive a nullable `user_id` because their historical creator names cannot safely be mapped to authenticated users. Those legacy records remain publicly discoverable but are not manageable by a newly authenticated creator until ownership is assigned by an administrator.

### Security model

- Public visitors can read published applications.
- Only authenticated creators can insert applications, and `user_id` must match `auth.uid()`.
- Creators can update/delete only their own application rows.
- Feedback is public to read and submit through the rate-limited Node API; visitors do not need an account.
- Showcase-view and outbound-click events are written through the rate-limited Node API after it verifies the published application.
- Only authenticated owners can read event rows belonging to their applications.
- Creator profiles are provisioned from `auth.users` by a database trigger.
- Do not put a Supabase service-role key in the frontend or in any `VITE_` variable.

The anon key is expected to be present in a browser application; Row Level Security is the security boundary. The service-role secret is required by the Node API for persistent anonymous feedback and event writes. Anonymous clients have no direct insert privileges on feedback or event tables. The Express endpoints validate input, verify the target application, and apply an in-memory IP rate limit. For multi-instance/serverless deployments, replace the in-memory limiter with a shared Redis-backed limiter and consider CAPTCHA/Turnstile plus a moderation workflow for public feedback.

## Gemini setup

1. Create a Gemini API key.
2. Set `GEMINI_API_KEY` in the server environment only.
3. Optionally set `GEMINI_MODEL` (default `gemini-2.0-flash`).
4. Restart the Node API.

Never prefix the Gemini key with `VITE_`. The `/api/analyze` endpoint verifies creator ownership for real applications and loads the actual stored feedback before analysis. `/api/generate` verifies ownership and uses the stored application name/description for real projects; demo records use their labelled sample content. `/api/feedback` and `/api/events` validate and persist anonymous visitor submissions using the server-only Supabase service key. All `/api/*` endpoints are rate-limited. If Gemini is not configured or returns an invalid/unavailable response, the server returns a clearly labelled non-AI fallback.

## Environment variables

| Variable | Runtime | Required | Purpose |
|---|---|---:|---|
| `VITE_SUPABASE_URL` | Browser build | No (demo mode) | Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | Browser build | No (demo mode) | Supabase anon/publishable key protected by RLS |
| `SUPABASE_URL` | Node server only | Production writes: yes | Supabase project URL for server-side write routes (may equal `VITE_SUPABASE_URL`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Node server only | Production writes: yes | Supabase service-role secret used only by the server for rate-limited public feedback/event writes |
| `GEMINI_API_KEY` | Node server only | No | Gemini API key |
| `GEMINI_MODEL` | Node server only | No | Gemini model identifier |
| `PORT` | Node server | No | API port; default `8787` |
| `CLIENT_ORIGIN` | Node server | Production: yes | Exact comma-separated browser origins allowed by CORS |
| `TRUST_PROXY_HOPS` | Node server | Host-dependent | Number of trusted reverse-proxy hops for correct client IP rate limiting; set to the value documented by your host |

## Production build and run

```powershell
npm run build
npm run server
```

The Vite build writes `dist/`. Express serves `dist/` and the `/api/*` routes from the same Node process. Configure the deployment platform to run `npm start` (or `node server/index.js`) after the build. In production, set `CLIENT_ORIGIN` to the exact deployed origin, for example `https://your-launchloop-domain.example`. If the host terminates TLS or uses a reverse proxy, ensure `/api/*` is forwarded to the same Node service.

Health check:

```text
GET /api/health
```

Expected response includes `ok: true`, `aiConfigured` and `supabaseWritesConfigured` booleans. This health response does not prove database or Gemini connectivity; verify those separately.

## Embarko deployment checklist

1. Import this existing project/repository into an Embarko deployment that supports a Node.js server process.
2. Use Node 20+.
3. Install dependencies with `npm install`.
4. Build with `npm run build`.
5. Start with `npm start`.
6. Add the environment variables above in the deployment environment (never commit `.env`). Keep `SUPABASE_SERVICE_ROLE_KEY` and `GEMINI_API_KEY` in server-only secret settings; do not prefix either with `VITE_`.
7. Set `CLIENT_ORIGIN` to the deployed HTTPS origin.
8. Ensure the platform exposes the Node service port using its expected `PORT` variable and forwards `/api/*` to the Node process.
9. Run the public app URL and `/api/health`.
10. Test registration, sign-in, publishing, public feedback, creator-only analytics, Gemini analysis and launch generation on the deployed URL.

No public deployment is included or claimed by this source package. Verify the final public URL and health endpoint after the hosting platform completes deployment.

## Testing report / known verification limits

Checks completed in the preparation environment:
- `node --check server/index.js` — passed.
- TypeScript compiler transpilation/syntax checks for `src/App.tsx`, `src/lib/data.ts`, `src/lib/types.ts` and `src/main.tsx` — passed (syntax only; not a full typecheck).
- `package.json` JSON parsing — passed.

The following checks still need to be run in an environment where npm dependencies can be installed and external credentials are available:

- `npm install`
- `npm run build`
- Browser-level responsive and end-to-end testing
- Supabase SQL execution and RLS policy tests
- Email registration/confirmation and session lifecycle
- Live Gemini analysis/content generation
- Production host routing and public URL health check

Dependency installation was attempted, but npm registry DNS resolution failed (`EAI_AGAIN registry.npmjs.org`) and the install was interrupted. `node_modules` was therefore not available; a successful production build or full browser journey must not be claimed until those commands have actually passed.

See [`TESTING-REPORT.md`](./TESTING-REPORT.md) for the exact checks completed, dependency/build blockers, external-credential gaps and the manual release checklist.

## Demo data

The sample apps **FocusFlow**, **PixelChef** and **SprintBoard** are labelled `SAMPLE`. Their static sample feedback is also labelled `SAMPLE FEEDBACK`. New feedback left on a sample showcase is stored separately in local demo storage and retrieved alongside the static sample feedback. Sample apps do not emit analytics events. Local demo data is browser-specific and is not shared across devices.

## Independent product notice

LaunchLoop is an independent community product created for the #DeployWithEmbarko competition. It is not an official Embarko integration.
