# Deploy Udharwise API (Vercel frontend + AWS EC2 Podman)

| Piece | Where |
|-------|--------|
| Frontend PWA | [Vercel](https://vercel.com) |
| API + Postgres + Redis | AWS EC2 Ubuntu + Podman Compose |
| HTTPS | Caddy (Let's Encrypt) on the instance |

Password signup/login works without email. OTP needs SMTP + Sidekiq later (`--profile sidekiq`).

## 1. EC2 after launch

1. **Security group inbound:** TCP `22`, `80`, `443` from `0.0.0.0/0` (SSH can be locked to your IP later).
2. Note the **Public IPv4** address.
3. From your Mac:

```bash
chmod 400 ~/Downloads/YOUR_KEY.pem
ssh -i ~/Downloads/YOUR_KEY.pem ubuntu@YOUR_PUBLIC_IP
```

4. On the instance:

```bash
sudo apt update
sudo apt install -y podman podman-compose git
```

## 2. DNS

Create an **A record**: `api.yourdomain.com` → EC2 public IP. Wait until it resolves (`dig +short api.yourdomain.com`).

## 3. Deploy the API on the instance

Push this repo to GitHub (private), then on the EC2 box:

```bash
git clone https://github.com/YOUR_USER/udharwise-api.git
cd udharwise-api
cp .env.production.example .env
nano .env   # fill SECRET_KEY_BASE, JWT_SECRET, POSTGRES_PASSWORD, API_DOMAIN, RAILS_ALLOWED_HOSTS
```

Generate secrets on your laptop if needed:

```bash
openssl rand -hex 64
openssl rand -hex 32
```

Start:

```bash
podman compose -f compose.prod.yml up -d --build
podman compose -f compose.prod.yml logs -f web
```

Health: `https://api.yourdomain.com/up`  
(Leave `FRONTEND_ORIGINS` as a placeholder until Vercel exists, then update `.env` and `podman compose -f compose.prod.yml up -d web`.)

## 4. Frontend on Vercel

1. Deploy the PWA repo on Vercel.
2. Env: `API_UPSTREAM_URL=https://api.yourdomain.com` (no trailing slash).
3. On EC2 `.env` set `FRONTEND_ORIGINS=https://YOUR_APP.vercel.app` and recreate `web`.

## 5. Smoke test

Open the Vercel URL → sign up → create group / expense. Phone: Install app (HTTPS).

## Files

- [`compose.prod.yml`](./compose.prod.yml) — db, redis, web, caddy (+ optional sidekiq profile)
- [`Caddyfile`](./Caddyfile) — TLS + reverse proxy to Rails
- [`.env.production.example`](./.env.production.example)
