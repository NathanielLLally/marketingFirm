# Mail Flow — `mail.happytailspawcare.com`

> Generated 2026-06-25 from live `/etc/postfix/*`, the milters, the reinjection
> scripts, and the PostgreSQL `mx` schema. NOTE: `main.cf` and `master.cf` were
> open in `vim` while this was written, so on-disk config may be mid-edit.

---

## 1. Components at a glance

| Port / socket            | Service                  | Role                                                                 |
|--------------------------|--------------------------|---------------------------------------------------------------------|
| `25/smtp`                | `smtpd`                  | Inbound MX                                                           |
| `587/submission`         | `smtpd` (TLS+SASL)       | Authenticated client submission                                     |
| `465/smtps`              | `smtpd` (wrapper TLS)    | Authenticated client submission                                     |
| `127.0.0.1:8891`         | **opendkim**             | Milter #1 — DKIM sign/verify                                        |
| `127.0.0.1:8893`         | **rate-limit-milter.pl** | Milter #2 — tags mail with `X-Rate-Limit-Reached` (Sendmail::PMilter, prefork ×10) |
| `domainratelimit` (pipe) | `smtp.pl` (vmail)        | Re-injection gate: either records a synthetic bounce, or relays to :10026 |
| `127.0.0.1:10026`        | `smtpd` (no milters)     | Re-injection entry point for paced mail                             |
| `10026cleanup`           | `cleanup`                | Strips `Received: ... 127.0.0.1` headers on reinjection             |
| PostgreSQL `mx.*`        | `plperlu` + triggers     | Rate/bounce state store + log-scraping feedback loop                |

Milter chain (applied to BOTH smtpd and locally-injected mail):
`smtpd_milters = inet:127.0.0.1:8891 inet:127.0.0.1:8893`,
`non_smtpd_milters = $smtpd_milters`, `milter_default_action = accept` (fail-open).

---

## 2. Top-level message flow

```
                      ┌─────────────────────────────────────────────┐
   inbound 25 ───────▶│                  smtpd                       │
   submit 587/465 ───▶│   smtpd_recipient_restrictions:             │
   local sendmail ───▶│     check_recipient_access (autoreply)       │
                      │     permit_mynetworks                        │
                      └───────────────┬─────────────────────────────┘
                                      │ MILTERS (in order)
                                      ▼
                      ┌──────────────────────────────┐
                      │ 8891 opendkim   (DKIM)        │
                      └───────────────┬──────────────┘
                                      ▼
                      ┌──────────────────────────────────────────────┐
                      │ 8893 rate-limit-milter.pl                     │
                      │  envrcpt: look up recipient MX in Postgres    │
                      │  eom:                                         │
                      │   • "rate delay" reason ⇒ 4xx SMFIS_TEMPFAIL  │ ──▶ sender retries later
                      │   • any other reason   ⇒ add header           │
                      │       X-Rate-Limit-Reached: <reason>          │
                      └───────────────┬──────────────────────────────┘
                                      ▼
                      ┌──────────────────────────────┐
                      │ cleanup                       │
                      │  header_checks (regexp):      │
                      │   X-Rate-Limit-Reached ⇒      │
                      │     FILTER domainratelimit:   │   (overrides transport)
                      │   MAILER-DAEMON/no-reply/     │
                      │   bounce subj ⇒ REDIRECT      │ ──▶ bounces@happytailspawcare.com
                      └───────────────┬──────────────┘
                                      ▼
                      ┌──────────────────────────────┐
                      │ qmgr  → transport_maps        │
                      │        (pcre:transport.pcre)  │
                      └───────────────┬──────────────┘
                                      ▼
        ┌─────────────────────────────┼───────────────────────────────────┐
        ▼                             ▼                                     ▼
  *happytailspawcare.com   accuratelead/leadt/winblows98          /.*/  (everything else)
        │                             │                                     │
        ▼                             ▼                                     ▼
   localmail: (local)         mynetwork: (smtp,                    domainratelimit:  ◀── default!
   Maildir delivery            no fallback relay)                  pipe → smtp.pl
```

Recently observed relay counts (`/var/log/maillog`): `domainratelimit 919`,
`localmail 123`, `gmail 3`. Almost all outbound goes through the rate-limit pipe.

---

## 3. The rate-limit / re-injection subsystem (the heart of it)

```
              transport: domainratelimit  (master.cf pipe, user=vmail)
              argv: /home/vmail/smtp.pl 127.0.0.1 10026 ${queue_id}
                                      │
                                      ▼
          ┌───────────────────────────────────────────────────────────┐
          │ smtp.pl  reads full message on STDIN                       │
          │                                                            │
          │  IF message contains  X-Rate-Limit-Reached: <reason>       │
          │     → parse reason / target MX                             │
          │     → INSERT mx.smtp_status(qid,status='5.7.1 550 ...',    │
          │              result='bounced', addr, mx)                   │
          │     → exit EX_UNAVAILABLE  ===> MESSAGE DROPPED (no send)  │
          │                                                            │
          │  ELSE  (not rate-limited)                                  │
          │     → Email::Sender → SMTP 127.0.0.1:10026  (re-inject)    │
          └───────────────────────────────┬───────────────────────────┘
                                           ▼
          ┌───────────────────────────────────────────────────────────┐
          │ 127.0.0.1:10026 smtpd                                      │
          │   -o receive_override_options = no_unknown_recipient_      │
          │        checks, no_milters     (milters NOT re-run)         │
          │   -o cleanup_service_name = 10026cleanup                   │
          │        → reinject_header_checks: IGNORE Received:127.0.0.1 │
          │   -o mynetworks = 127.0.0.0/8 ; relay = permit_mynetworks  │
          └───────────────────────────────┬───────────────────────────┘
                                           ▼
                              back into qmgr → transport_maps → actual delivery
```

Two distinct enforcement outcomes from the milter:

1. **`rate delay`** (last DB status for that MX was < 60s ago) → milter returns
   `SMFIS_TEMPFAIL` at `eom` → **4xx**, the sending side defers and retries
   later. This is the throttle.
2. **`domain block` / `≥3 user blocks` / `count ≥ limit`** → milter adds the
   `X-Rate-Limit-Reached` header → `header_checks` FILTERs it into the
   `domainratelimit` pipe → `smtp.pl` records a synthetic `5.7.1 550` bounce in
   Postgres and **drops** the message.
3. **No header** (under all limits) → through the pipe → re-injected at :10026 →
   delivered.

---

## 4. The milter's decision logic (`rate-limit-milter.pl`, `envrcpt`)

For each recipient, resolve recipient domain → MX (`Net::DNS`), skip if MX is
self (`mail.happytailspawcare.com`), else run three Postgres checks. First one to
set `$header` wins; header is attached at `eom`.

```
recipient @domain ──▶ MX lookup ──▶ svr (mx host)
        │
        ├─[A] recency:  select epoch(now()-max(updated)) from mx.smtp_status
        │               where mxdomain = mx.mxdomain(svr)
        │               seconds <= 60   ⇒ "mx domain rate delay for <svr>"   (⇒ TEMPFAIL)
        │
        ├─[B] bounces:  select * from mx.smtp_bounces where mxdomain=mx.mxdomain(svr)
        │               domain_block > 0 ⇒ "domain based bounce within 7 days"
        │               user_block  >= 3 ⇒ "3+ user based bounces within 7 days"
        │
        └─[C] volume:   count(*) from mx.smtp_status (mxdomain, last 1 day)
                        vs mx.rate_limits.limit  (default 49)
                        count >= limit ⇒ "count at limit <limit> ... rejecting"
```

`mx.rate_limits` today: `leadtinfo.com=2`, `google.com=49`, `outlook.com=49`.
`mx.mxdomain()` collapses a host to its registrable domain (handles `co.uk`-style
2-label public suffixes via a small TLD set).

---

## 5. The PostgreSQL feedback loop (how the DB gets populated)

This is what makes the limits self-driving — every delivery attempt's status is
fed back into `mx.smtp_status`, which the milter then reads.

```
   Postfix delivers/bounces a message
            │
            │ smtp_delivery_status_filter = pgsql:pgsql.delivery_status.cf
            ▼
   INSERT INTO mx.smtp_status(status)   ← only the raw status text, qid IS NULL
            │
            │ generated columns compute on insert:
            │    mxdomain      = mx.mxdomain(mx)
            │    status_bounce = mx.classify_smtp_status(status)
            │         → "domain block ..." / "user block ..." (regex + enhanced code 5.x.x)
            ▼
   AFTER INSERT trigger  mx.after_status_insert_trigger_function
            │   (only when qid IS NULL — i.e. NOT the smtp.pl bounce rows)
            │   fork() → /var/lib/pgsql/data/smtp_status.pl
            ▼
   smtp_status.pl  scrapes `journalctl -xeu postfix`,
            correlates queue-id ↔ message-id ↔ to/from/relay/result,
            and back-fills addr / mx / relay / result on the new rows
            │
            ▼
   mx.smtp_status now has mxdomain + status_bounce populated
            │
            └──────────────▶ read back by rate-limit-milter checks [A][B][C]

   (smtp.pl's own bounce rows are inserted WITH qid set, so the trigger skips
    them — they already carry addr/mx and must not re-scrape.)
```

`mx.smtp_bounces` is a VIEW: counts `status_bounce LIKE 'domain block%'` and
`'user block%'` per `mxdomain` over the last 7 days.

---

## 6. Other rules in the path

- **Autoreply**: `check_recipient_access` → `reports@happytailspaware.com`
  FILTERs to the `autoreply` pipe (`autoreply.py`). *(note the `paware` typo vs
  `pawcare` — see concerns.)*
- **Bounce funneling**: `header_checks` REDIRECTs `MAILER-DAEMON`, `no-reply*`,
  "Undelivered Mail Returned to Sender", and `Auto-Submitted: auto-replied`
  to `bounces@happytailspawcare.com`. `canonical` maps `mailer-daemon@` →
  `no-reply@`.
- **TLS policy** (`tls_policy`): force `encrypt`/TLSv1.2 to gmail.com,
  grandstreet.group, happytailspawcare.com.
- `default_destination_recipient_limit = 2`, `..._rate_delay = 0` globally;
  `localmail`/`mynetwork` raised to 200 recipients, concurrency 50.

---

## 7. Observations / things to verify (not asserting these are bugs)

1. **Re-injection loop guard.** `transport.pcre` line 5 is `/.*/ domainratelimit:`
   with `#/.*/ smtp:` commented just below. Mail re-injected at :10026 goes back
   through `qmgr` → `transport_maps`, so a non-rate-limited message hits the
   `/.*/` catch-all → `domainratelimit` → `smtp.pl` → :10026 again. What stops
   the loop today? The queue is currently tiny (2 msgs), so in practice it isn't
   looping — but the :10026 smtpd has **no transport override**, so the
   loop-breaker isn't obvious in config. Worth confirming whether :10026 is
   meant to override `transport_maps` to `smtp:` (the commented line suggests a
   toggle).
2. **Historic `smtp.pl` failures.** `/home/vmail/smtp.log` has 32×
   `sending failed: unable to establish SMTP connection to (127.0.0.1) port
   10026` — i.e. the :10026 smtpd wasn't reachable at the time. Likely among the
   things fixed yesterday; no recent recurrences.
3. **Shared `$header` in a prefork milter.** `$header` is a file-scope lexical in
   `rate-limit-milter.pl`, reused across up to 100 requests per child. It's reset
   at `eom`, but `abort` does not clear it — an aborted transaction could leak a
   stale reason onto the next message in that child. (`milter_default_action =
   accept` means milter crashes fail open.)
4. **Typo:** autoreply key is `reports@happytailspa**w**are.com` but the domain
   is `happytailspa**wc**are.com`, so the autoreply FILTER may never match.
5. `header_checks` (active = `regexp:`) and `header_checks.pcre` are near-
   duplicates; only the `regexp:` one is wired in `main.cf`.
