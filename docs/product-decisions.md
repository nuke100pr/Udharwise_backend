# Household Expenses — Product Decisions

**Status:** Agreed for v1  
**Last updated:** 2026-09-30  
**Working title:** Household Expenses (Splitwise-style shared expense tracker)

---

## 1. Product vision

Build a backend-first application for recording household / shared expenses.

People form **invite-only groups**, log expenses in **INR** with **dynamic integer splits**, settle balances (including **simplified settlement**), export data, and keep a full **audit trail**. Groups and expenses are **archived** instead of deleted. Auth is **email OTP** with unique identities (`email`, `phone`, `@handle`).

---

## 2. Goals (v1)

1. Multi-user **groups** with invite-only membership  
2. Group-scoped expenses that never cross groups  
3. Settle expenses and simplify group settlements  
4. Export expenses as **CSV**  
5. **Audit logs** for CRUD (and related actions) per group  
6. **Archive / unarchive** for groups and expenses (no hard delete as the primary UX)  
7. **Email OTP** login  
8. Unique **email**, **phone**, and **@handle** per user  
9. Permanent membership once accepted (no removals)

---

## 3. Non-goals (v1)

- Multi-currency (INR only)  
- SMS OTP  
- Removing members from a group  
- Hard-deleting groups or expenses as the normal path  
- Public / join-by-link groups without invite acceptance  
- Floating-point money amounts  

---

## 4. Users & identity

| Rule | Decision |
|------|----------|
| Email | Required, **unique** |
| Phone | Required, **unique** |
| Handle | Required, **unique**, **no leading `@`** in storage (e.g. `prakhar`); UI may display `@prakhar` |
| Login | **Email OTP only** (no password in v1) |
| After OTP | Issue API token (**JWT**) |
| OTP delivery | Email via Action Mailer; local: Mailpit in Podman |
| OTP storage | Short-lived codes + rate limits in **Redis** |

### Auth flow

1. User submits email  
2. System emails a short-lived OTP  
3. User submits email + OTP  
4. On success, system returns JWT (and creates the user if this is first login / completes onboarding for handle + phone as designed in implementation)

---

## 5. Groups

| Rule | Decision |
|------|----------|
| Membership | A group has multiple users |
| Isolation | Groups are distinct; expenses/transactions of one group are **mutually exclusive** from others |
| Creation | Creator becomes a member (and is the initial admin/creator for tooling if needed) |
| Joining | **Invite only** |
| Invite flow | Creator (or entitled member — v1: inviter is a group member) searches user by **handle** (global search; client may send `@name` and API strips `@`) → sends invite → invitee **accepts** → membership created |
| Removal | **No member can be removed** once added |
| Delete | Do not delete groups; **archive / unarchive** instead |

### Archive / lock behavior (groups)

| Action | Who can do it |
|--------|----------------|
| Archive group | **member** |
| Unarchive group | **member** |

When a group is **archived**:

- Group is **inactive / locked**  
- **No new expenses**  
- **No archive / unarchive of expenses**  
- No money-changing mutations (expenses, settlements, invites) — treat as **read-only**  
- Reads remain allowed (list expenses, balances, audit logs, CSV export)

Unarchiving the group restores normal mutations.

---

## 6. Invites

| Rule | Decision |
|------|----------|
| Discovery | Global search by `@handle` |
| Acceptance | Invitee is added **only after accept** |
| Decline | Invite can be declined (no membership) |
| Scope | Invite is for one group; cannot pull another group’s data |

---

## 7. Expenses (transactions)

| Rule | Decision |
|------|----------|
| Scope | Belongs to exactly one group |
| Currency | **INR only** |
| Money storage | Integer **paise** (₹1 = 100 paise); no floats |
| Split | **Dynamic**: 1..N group members; each has a variable integer share |
| Payers | At least one payer; multiple payers allowed; payers must be group members |
| Validation | Sum of participant **shares** = expense **total**; sum of **paid** amounts = expense **total** |
| Delete | Do not delete; **archive / unarchive** |
| Membership constraint | Participants must be members of that group |

### Archive behavior (expenses)

| Action | Who can do it |
|--------|----------------|
| Archive expense | **member** of the group |
| Unarchive expense | **member** of the group |

Constraints:

- If the **group is archived**, expenses cannot be archived or unarchived  
- Archived expenses are excluded from **active** balance / settlement math  
- Archived expenses remain available for history, audit logs, and CSV export (as defined in API)

### Suggested expense shape

```text
Expense
  group_id
  created_by_user_id
  description / note
  total_paise          # integer INR paise
  archived_at          # null = active
  settled state        # per product: mark expense settled and/or via settlement records

ExpenseParticipant
  expense_id
  user_id              # must be group member
  share_paise          # portion of the bill owed/allocated
  paid_paise           # amount this person paid toward the bill (0 if not a payer)
```

**Example**

Dinner total ₹500 (`50000` paise). A paid the full bill; split A ₹200, B ₹200, C ₹100:

| Member | share_paise | paid_paise |
|--------|-------------|------------|
| A | 20000 | 50000 |
| B | 20000 | 0 |
| C | 10000 | 0 |

`sum(share) = 50000 = total` and `sum(paid) = 50000 = total`.

---

## 8. Settlement

| Feature | Decision |
|---------|----------|
| Settle each expense | Supported — mark / record settlement for an expense |
| Simplify settlement | Supported — compute net balances across the group and reduce to a minimal set of transfers |
| Money | Netting and transfers in integer paise only |
| Locked groups | Settlements cannot be created while the group is archived |

**Simplify (concept):**  
If A owes B 100 and B owes C 100, simplification can reduce to A pays C 100 (fewer transfers, same net).

---

## 9. Export

| Rule | Decision |
|------|----------|
| Format | **CSV** |
| Scope | Expenses for a given group |
| Includes | Active and archived expenses (exact columns TBD in API design) |
| Execution | Sync for small exports; Sidekiq job if large |

---

## 10. Audit logs

| Rule | Decision |
|------|----------|
| Scope | Per **group** |
| What is logged | CRUD and related actions (create/update/archive/unarchive expenses, invites, settlements, group archive/unarchive, etc.) |
| Typical fields | actor user, action, entity type/id, timestamp, metadata/payload snapshot |
| Retention | Keep for group lifetime (v1: no auto-purge) |

---

## 11. Permissions summary

| Capability | Allowed for |
|------------|-------------|
| Archive / unarchive **group** | Group member |
| Archive / unarchive **expense** | Group member (blocked if group is archived) |
| Add expense | Group member (blocked if group is archived) |
| Invite by @handle | Group member (blocked if group is archived) |
| Accept / decline invite | Invitee |
| Remove member | **Never** |
| Settle / simplify | Group member (blocked if group is archived) |
| Export CSV | Group member |
| View audit logs | Group member |

> Earlier draft said “only admin can archive groups.” **Superseded:** members can archive and unarchive groups and expenses.

---

## 12. Domain entities (v1)

| Entity | Purpose |
|--------|---------|
| User | Identity: email, phone, @handle; OTP login |
| OtpChallenge | Short-lived email OTP (backed by Redis in practice) |
| Group | Shared expense container; archive lock |
| GroupMembership | User ↔ group; permanent after accept |
| GroupInvite | Pending invite by handle |
| Expense | Group-scoped transaction |
| ExpenseParticipant | Dynamic split lines (share + paid) |
| Settlement | Settlement / simplify transfer records |
| AuditLog | Per-group action history |

---

## 13. Technical stack (intended)

| Layer | Choice |
|-------|--------|
| API | Ruby on Rails, API mode |
| DB | PostgreSQL |
| Cache / OTP / queues | Redis |
| Jobs | Sidekiq (email OTP, heavy CSV) |
| Containers | Podman (rails, postgres, redis, sidekiq, mailpit) |
| Auth token | JWT after email OTP |
| Money | Integer paise, INR |
| Lists | Pagination on collection endpoints |
| JSON shaping | API serializers |
| Local email | Mailpit |

---

## 14. High-level API areas

- **Auth:** request OTP, verify OTP  
- **Users:** profile / me, search by `@handle`  
- **Groups:** create, list mine, archive, unarchive  
- **Invites:** create, list, accept, decline  
- **Expenses:** create, update (rules TBD), list (paginated), archive, unarchive  
- **Settlements:** settle expense, simplify preview, confirm simplify  
- **Export:** group expenses CSV  
- **Audit logs:** list by group  

---

## 15. Decision log (chronological)

| Topic | Decision |
|-------|----------|
| Currency | INR only; store paise as integers |
| Expense split | Dynamic 1..N members; variable integer shares; multi-payer; sums must equal total |
| OTP | Email only |
| Group archive permission | Member (not admin-only) |
| Expense archive permission | Member |
| Unarchive group / expense | Member |
| Archived group | Locked / inactive: no new expenses; no expense archive/unarchive; read-only for mutations |
| Membership | Invite-only via @handle; accept required; no removals |
| Soft delete pattern | Archive/unarchive for groups and expenses |
| Settlement | Per-expense settle + group simplify |
| Export | CSV |
| Audit | CRUD (+ related) logs per group |
| Identity uniqueness | Email, phone, @handle |

---

## 16. Open for implementation (not blocking product intent)

These do not change the product rules above; they are engineering details to finalize while building:

- Exact onboarding order (when phone / @handle are set relative to first OTP)  
- Whether expense **updates** are allowed after create, or only archive  
- Exact CSV columns  
- Exact simplify algorithm presentation (preview vs auto-apply)  
- Project folder name (suggested: `household-expenses`)  
- JWT refresh / logout / revoke strategy  

---

## 17. One-line summary

**Invite-only INR expense groups with dynamic integer splits, email-OTP auth, member-controlled archive locking, settlements + simplify, CSV export, and full per-group audit logs — no member removals, no float money.**
