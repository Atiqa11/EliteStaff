# LEGALYNX

A private, responsive legal practice workspace. The first build implements the client directory, client profiles, invoice and payment records, and record-driven dashboard summaries.

> **Data note:** No client, payment, or matter demo records are included. Until Supabase is connected, record counts and save actions are intentionally unavailable.

## Technology

- React 18, Vite 6, TypeScript
- Supabase Auth, Postgres, Row Level Security, and private Storage
- Netlify static hosting and SPA routing

## Run locally

1. Install Node.js 20 or newer.
2. Install dependencies: `npm install`
3. Copy `.env.example` to `.env.local` and add the Supabase project values. To run the Netlify AI function locally, use Netlify Dev and also configure the server-only OpenAI values below.
4. Apply `supabase/migrations/202611220001_initial_schema.sql` in the Supabase SQL Editor (or with the Supabase CLI).
5. Start the app: `npm run dev`
6. Create a workspace account from the sign-in page. If email confirmation is enabled, confirm the signup email before signing in.

Without the Supabase values, the interface opens in setup mode. It does not simulate authentication or claim that records were saved. To use Netlify Functions locally, install the Netlify CLI and run `npx netlify dev` instead of `npm run dev`; add the server variables to `.env` for that local process.

## Supabase setup

Create a Supabase project, then copy **Project URL** and the browser-safe **anon/publishable key** from Project Settings → API. Set:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

The migration creates the initial client, matter, task, calendar, invoice, payment, time-entry, public-overview, and client-document tables. Row Level Security limits every row to its authenticated owner. The `client-documents` Storage bucket is private and object paths are scoped to the signed-in user. Never put a Supabase `service_role` key or any AI provider secret in a `VITE_` variable.

## Environment variables

| Variable | Used by | Purpose |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | Browser app | Supabase project endpoint |
| `VITE_SUPABASE_ANON_KEY` | Browser app | Public client key; database RLS is the access boundary |
| `SUPABASE_URL` | Netlify Function | Supabase endpoint used to validate the signed-in user |
| `SUPABASE_ANON_KEY` | Netlify Function | Public Supabase key used for session validation |
| `OPENAI_API_KEY` | Netlify Function | Private OpenAI API credential; never add a `VITE_` prefix |
| `OPENAI_MODEL` | Netlify Function | Model enabled for your OpenAI API project |

The Lynx AI assistant sends only the question and optional jurisdiction entered by the signed-in user. It never attaches client records automatically. The Netlify function verifies the user's Supabase session before calling the OpenAI Responses API and does not store responses. A privacy notice appears beside the question form. OpenAI keys must remain in Netlify Function environment variables, never in a `VITE_` variable.

## Build

```sh
npm run build
npm run preview
```

Netlify uses `npm run build` and publishes `dist/`. `netlify.toml` contains the SPA fallback required for direct navigation and refresh.

## Deploy through Netlify and GitHub

1. Push the reviewed source to the GitHub repository's `main` branch.
2. In Netlify, choose **Add new site → Import an existing project**, select GitHub, and choose `Atiqa11/EliteStaff`.
3. Set the build command to `npm run build` and publish directory to `dist` (also declared in `netlify.toml`).
4. Add `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OPENAI_API_KEY`, and `OPENAI_MODEL` in **Site configuration → Environment variables** for the Deploy contexts you use. Keep the OpenAI key private and scope function values to Functions if Netlify offers the context.
5. Trigger a deploy. Netlify will also run new deploys for later pushes to the connected branch.
6. Add the final Netlify domain to Supabase Auth → URL Configuration (Site URL and redirect URLs), then verify signup and sign-in.

## Current module coverage

- Clients: searchable, filterable, sortable grid/list directory, pagination, favorites, profile fields, edit, archive, confirmed delete, private files, and invoice history.
- Finance: invoice creation, payment recording with balance validation, payment history, and automatic balance/status calculations from transactions.
- Overview: daily task/event/hearing/deadline counts and practice totals are calculated from the signed-in user's real records.
- Matters, tasks, and meetings: private record views backed by the included tables. Other sidebar modules are reserved for follow-on implementation.

This is an initial module implementation, not a deployed site. Do not upload confidential case/client information until your Supabase policies and account settings have been reviewed in your own project.
