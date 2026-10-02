# Udharwise API

Udharwise shared-expense backend (Rails API). Run with **Podman Compose** only.

## Stack

| Service | Role |
|---------|------|
| `web` | Rails API (Puma) |
| `sidekiq` | Background jobs (OTP email) |
| `db` | PostgreSQL |
| `redis` | OTP store + Sidekiq |
| `mailpit` | Dev email UI → http://localhost:8025 |

## Quick start

```bash
cp .env.example .env   # if needed
podman compose up -d
podman compose exec web bin/rails db:migrate
```

API: http://localhost:3000  

## Auth

### Request OTP
```bash
curl -s -X POST http://localhost:3000/api/v1/auth/otp/request \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com"}'
```
OTP is emailed via **Sidekiq** → Mailpit.

### Login (existing user)
```bash
curl -s -X POST http://localhost:3000/api/v1/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","code":"123456"}'
```

### Signup / onboarding (new email)
1. Request OTP  
2. Verify with code only → `onboarding_required` (OTP kept)  
3. Verify again with same code + `phone` + `handle` → JWT  

```bash
curl -s -X POST http://localhost:3000/api/v1/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"email":"new@example.com","code":"123456","phone":"+910000000099","handle":"newbie"}'
```

### Authenticated calls
```bash
curl -s http://localhost:3000/api/v1/groups \
  -H "Authorization: Bearer TOKEN"
```

## Main API surface

| Method | Path | Notes |
|--------|------|--------|
| POST | `/api/v1/auth/otp/request` | |
| POST | `/api/v1/auth/otp/verify` | login or onboarding |
| GET | `/api/v1/me` | JWT |
| GET/POST | `/api/v1/groups` | |
| POST | `/api/v1/groups/:id/archive` | |
| POST | `/api/v1/groups/:id/unarchive` | |
| GET | `/api/v1/groups/:id/balances` | |
| GET | `/api/v1/groups/:id/simplify` | preview transfers |
| POST | `/api/v1/groups/:id/invites` | `{ "handle": "bob" }` |
| POST | `/api/v1/invites/:id/accept` | |
| POST | `/api/v1/invites/:id/decline` | |
| GET/POST | `/api/v1/groups/:id/expenses` | |
| POST | `/api/v1/groups/:id/expenses/:id/settle_share` | full share only |
| GET | `/api/v1/groups/:id/expenses_export` | CSV |
| GET | `/api/v1/groups/:id/audit_logs` | |
| GET | `/api/v1/groups/:id/audit_logs/export` | CSV |
| GET | `/api/v1/users/search?handle=` | |

Docs: `docs/product-decisions.md`, `docs/build-guide.md`

## Money

Amounts are **integer paise** (₹1 = 100). No floats.
