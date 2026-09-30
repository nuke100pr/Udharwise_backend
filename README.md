# Expenses

Shared household expense tracker (Rails API). **Run everything with Podman Compose** — Postgres, Redis, Mailpit, Rails, and Sidekiq are containers only.

Product rules: [`docs/product-decisions.md`](docs/product-decisions.md)  
Build guide: [`docs/build-guide.md`](docs/build-guide.md)

**Repo path:** `Documents/Repositories /Expenses`

---

## Command log

Commands guided in this build, in order. Re-run or re-check from here whenever you need a reminder.

### Step 1 — Confirm Podman

```bash
podman version
podman compose version
```

If `podman compose version` fails, try:

```bash
podman-compose --version
```

**Done when:** both print a version with no errors.

---

*(Later steps will be appended below as we go.)*
