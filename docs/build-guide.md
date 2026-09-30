# Household Expenses — From-Scratch Build Guide (Podman-only)

**How to use this guide:** Do the work yourself. This document tells you *what* to build and *in what order*, not *how to paste finished code*. Look up Rails / Podman docs when you need syntax. Your product decisions live in `docs/product-decisions.md`.

**Rule of engagement for your mentor:** Ask for explanations, checklists, and “what should I do next?” — not full file contents or copy-paste implementations.

---

## 0. Mindset

1. **Runtime is always Podman** — Postgres, Redis, Rails, Sidekiq, Mailpit run as containers. Your Mac only needs Podman, a text editor (Cursor), and git.
2. **Source code lives on the host**, mounted into the Rails container as a volume. You type every line in the editor; the container runs it.
3. **Ship-ready shape** — If it runs with `podman compose up`, the same compose file is the basis for other machines / servers later.
4. **Build vertical slices** — Prefer “one thin feature working end-to-end” over scaffolding every model up front.
5. **Follow the product doc** — When unsure, re-read the product decisions; do not invent conflicting rules.

---

## 1. Prerequisites (host only)

Install / verify on your machine:

- Podman (you already have it)
- Podman Compose (or `podman compose` plugin — confirm with Podman docs for your version)
- Git
- Cursor / editor

You do **not** need a local Postgres, Redis, or a permanently installed Rails app server for day-to-day running. You *may* use a one-off Ruby container to generate the Rails app so even `rails new` is not “local forever.”

Optional on host: Ruby/rbenv only if you personally want IRB outside containers. Not required for this plan.

---

## 2. Phase A — Empty project shell

**Goal:** A git repo and folder that will hold Rails + compose files.

1. Create a directory (this repo: `Expenses` under Documents/Repositories).
2. `git init`
3. Add a `.gitignore` suitable for Rails (you can start minimal: ignore `.env`, `tmp/`, `log/`, `vendor/bundle`, credentials keys, etc., and refine later).
4. Copy or link your product decisions doc into the repo (e.g. `docs/product-decisions.md`) so requirements travel with the code.
5. Create a short `README.md` that states: what the app is, and that **Podman Compose is the only supported way to run it**.

**Checkpoint:** Empty repo, git working, docs present. No app yet.

---

## 3. Phase B — Compose topology (before Rails)

**Goal:** Define the services your product needs, with names and networks, even if Rails is not there yet.

Plan these services in a compose file (you write it):

| Service | Role |
|---------|------|
| `db` | PostgreSQL — primary data |
| `redis` | OTP TTL, cache, Sidekiq queue |
| `mailpit` | Catches outbound email in dev (OTP) |
| `web` | Rails API (Puma) — add after `rails new` |
| `sidekiq` | Background jobs — same image/code as `web` |

Also decide now:

- A shared Docker/Podman **network**
- **Volumes** for Postgres data (and optionally Mailpit)
- An `.env.example` listing variables (no secrets committed): database URL pieces, Redis URL, SMTP host pointing at `mailpit`, Rails secret, etc.
- A real `.env` for local compose (gitignored)

Bring up **only** `db`, `redis`, and `mailpit` first. Confirm:

- Postgres accepts connections from another container on the compose network  
- Redis responds to ping from another container  
- Mailpit UI is reachable from the host (check Mailpit’s published port in its docs)

**Checkpoint:** Infra containers healthy. No Rails yet.

---

## 4. Phase C — Generate Rails API inside Podman

**Goal:** Create a Rails API app without relying on a long-lived local Rails install.

Approach:

1. Use a one-off / interactive container from an official Ruby image (version you choose, e.g. 3.3.x), with your project directory mounted.
2. Install Rails inside that container session (or use a image that already has it — your choice).
3. Run `rails new` with **API mode**, Postgres as database, and skip things you do not need for an API (you decide flags by reading `rails new --help`).
4. Generate into the current project folder carefully (avoid nesting an extra directory if you already created the repo root).

Then you write:

- A `Containerfile` (or Dockerfile) for the app image: Ruby base, install OS deps, `bundle install`, default command to start Puma  
- Wire `web` (and later `sidekiq`) in compose to build from that Containerfile  
- Mount the app source as a volume in development so edits apply without rebuilding every time (rebuild when Gemfile changes)

Configure Rails to talk to services by **compose service hostname** (`db`, `redis`, `mailpit`), not `localhost`, from inside containers.

**Checkpoint:** `podman compose up` starts `web`; hitting a health or root API route responds. `rails db:prepare` (or equivalent) runs against container Postgres.

---

## 5. Phase D — Rails baseline wiring (still no product features)

Do these yourself, one at a time:

1. **Database** — `database.yml` / DATABASE_URL aimed at `db`  
2. **Redis** — connection config for cache and later Sidekiq  
3. **Sidekiq** — gem, initializer, process in compose; verify a dummy job runs  
4. **Mail** — SMTP settings pointed at Mailpit; send a test mail from Rails console in the `web` container and see it in Mailpit UI  
5. **CORS** — only when you have a browser client; can wait  
6. **Zeitwerk / API-only** — confirm you are not serving HTML views  

**Checkpoint:** Compose stack = db + redis + mailpit + web + sidekiq. Email and a background job proven.

---

## 6. Phase E — Build order for product features

Build in this sequence so each step is testable. After each step: migrate, boot stack, hit endpoints with curl or an API client **from the host** against published ports.

### E1. Users & uniqueness

- Migration for users: email, phone, handle (store handle with or without `@` — pick one convention and stick to it; uniqueness indexes on all three)  
- Model validations matching the product doc  
- No passwords  

### E2. Email OTP auth

- Endpoint to request OTP for an email  
- Store OTP in Redis with TTL; rate-limit attempts  
- Sidekiq (or mailer) sends the email  
- Endpoint to verify OTP → issue JWT  
- A simple “current user” mechanism for later controllers  

**Prove:** Request OTP → see email in Mailpit → verify → receive token → call a protected “me” endpoint.

### E3. Handle search

- Endpoint: search users by handle (for invites)  
- Do not expose unnecessary private fields  

### E4. Groups & membership

- Groups table + archive timestamp  
- Memberships (user_id, group_id); unique pair  
- Create group → creator becomes member  
- List my groups  
- Archive / unarchive group (member only)  
- **Lock policy:** if group archived, reject mutating expense/invite/settlement actions with a clear error  

### E5. Invites

- Invites table: group, inviter, invitee, status  
- Create invite by handle (member, group not locked)  
- Accept / decline (invitee only)  
- Accept creates membership; enforce “no remove member” by simply never building that endpoint  

### E6. Expenses & participants

- Expenses: group, creator, total_paise, description, archived_at, etc.  
- Participants: user, share_paise, paid_paise  
- Validations: members only; sums equal total; at least one payer (`paid_paise > 0`)  
- Archive / unarchive expense (member; blocked if group locked)  
- List/filter active vs archived  

### E7. Settlement

- Per-expense settle flow  
- Balance computation from participants (who paid vs share)  
- Simplify: net balances → minimal transfers (study the debt-simplification algorithm; implement and test with pencil cases first)  
- Block when group locked  

### E8. Audit logs

- Append-only log rows per group  
- Record actor, action, entity, metadata on create/update/archive/invite/settle  
- Prefer a small service object called from controllers/models rather than scattering log writes  

### E9. CSV export

- Endpoint streaming or generating CSV for a group’s expenses  
- Large exports → Sidekiq + download later (can be a second iteration)  

### E10. Hardening pass

- Pagination on list endpoints  
- Serializers for stable JSON shapes  
- Rate limits on OTP  
- Request specs (RSpec) running **inside** the test container or CI service containers  
- OpenAPI optional later  

---

## 7. How to work day to day

1. Start stack: compose up  
2. Edit code on the host  
3. Run Rails commands **inside** the `web` container (`podman compose exec web ...`) — migrations, console, tests  
4. Watch Sidekiq logs when testing OTP/mail  
5. Use Mailpit UI to read OTPs  
6. Commit small vertical slices  

When Gemfile changes: rebuild the app image, then up again.

---

## 8. What “ship to other platforms” means here

You are already designing for portability if:

- All dependencies are services in compose  
- Config is environment variables  
- No reliance on host-installed Postgres/Redis  
- One Containerfile builds the app  
- README documents: install Podman → copy `.env.example` → compose up → migrate  

Later (not now): swap Mailpit for real SMTP, add a reverse proxy, use managed Postgres/Redis in production, same app image.

---

## 9. First session checklist (do this next)

Do only this in your first coding session:

1. Create repo folder + git + README + docs copy  
2. Write compose for `db`, `redis`, `mailpit` + `.env.example`  
3. Start those three; verify health  
4. Generate Rails API via a Ruby container into the repo  
5. Write Containerfile + add `web` service  
6. Connect Rails to Postgres; run setup/migrate  
7. Confirm an HTTP response from the API container  

Stop there. Do not start Users/OTP until that checkpoint is green.

---

## 10. How to ask for help without getting code dumped

Good prompts:

- “I finished Phase B; Postgres won’t accept connections from other containers — what should I check?”  
- “For OTP in Redis, what keys and TTL strategy should I choose?”  
- “Does my group lock policy match the product doc?”  
- “Review my approach for share_paise vs paid_paise validation — concepts only.”  

Avoid: “Write the User model for me” / “Paste the compose file.”

---

## 11. Suggested learning parallel track

While building Phases A–D, skim (conceptually):

- Rails API mode: routes, controllers, strong params  
- ActiveRecord migrations & validations  
- Redis mental model (keys, TTL)  
- Sidekiq job lifecycle  
- JWT structure (header/payload/signature) at a high level  
- Podman volumes, networks, compose depends_on / healthchecks  

You do not need to master all of Ruby before Phase E1 — learn the next concept when the next feature needs it.

---

**Next action for you:** Confirm Podman (Step 1 in README), then write compose for db + redis + mailpit.
