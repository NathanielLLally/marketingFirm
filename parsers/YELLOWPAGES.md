# Yellow Pages Crawlers

Scripts in `parsers/` that harvest business listings from yellowpages.com,
what each one is for, how to run it, and the PostgreSQL schema they expect.

There are **two generations** of crawler here. Only the first is current.

| Generation | Entry point | State lives in | Status |
|---|---|---|---|
| 2 — DB-backed queue | `yellow_pages.pl` | PostgreSQL | **Current** |
| 1 — file/CSV-backed | `ypSpider_treeParser.pl`, `ypSpider.pl` | `parsers/data/*.html` | Superseded |

---

## Quick start (current crawler)

```sh
# 0. one-time: create the schema (see "Database schema" below)
psql -d postgres -f etc/yellow_pages.sql

# 1. one-time: discover categories and per-city category URLs
./parsers/yellow_pages.pl bootstrap

# 2. (re)build the crawl queue from the discovered URLs
./parsers/yellow_pages.pl pending

# 3. run a worker — one per crawler host, no argument
./parsers/yellow_pages.pl

# 4. watch progress from another terminal
./parsers/stats_yp.pl
```

Results land in `yellow_pages.yellow_pages_loading`. Promote them into the
curated `yp.yellow_pages` table yourself; nothing does that automatically.

---

## Configuration

`yellow_pages.pl` reads `~/.yellow_pages.conf` via `Config::Tiny`
(`parsers/yellow_pages.pl:46`). For backward compatibility, it falls back
to `~/.obiseo.conf` if the primary file is not found. Note that
`stats_yp.pl` reads `etc/obiseo.conf` instead (`parsers/stats_yp.pl:44`)
— different paths, so a host running both may need separate files or
symlinks.

```ini
[dB]
dsn  = dbi:Pg:dbname=postgres;host=127.0.0.1
user = postgres
pass =

; optional: the crawler fleet the queue is sharded across.
; Omit this and the queue is sharded to the local host alone.
[crawler]
hosts = mail.obiseo.net,mail.accurateleadinfo.com,mail.leadtinfo.com
```

### Sharding and the `[crawler]` section

A worker only claims rows whose `host` column matches its own
`Sys::Hostname::hostname()`. The fleet used to be a hardcoded list of four
`mail.*` hosts inside the SQL, so a box outside that list queued work it
could never claim and printed `got -1` forever.

The fleet now comes from `[crawler] hosts`, defaulting to **the local
hostname only** — the one value that guarantees a worker can claim what it
queued. Set `hosts` explicitly when running a real multi-box fleet, and
make sure every name matches what `hostname` prints on that box.

The config file is not in the repo (it holds a password). Every DB-backed
script in `parsers/` and `bin/` uses the same `[dB]` section.

### Dependencies

See `DEPS.md`. Beyond that list, the current crawler needs
`Modern::Perl`, `Try::Tiny`, `Coro`, `AnyEvent`, `AnyEvent::HTTP`,
`AnyEvent::UserAgent`, `PURI`, `Config::Tiny`,
`HTML::TreeBuilder::Select`, and `Time::Piece` (for `stats_yp.pl`).

---

## `yellow_pages.pl` — the current crawler

One script, three modes, selected by the first positional argument
(`parsers/yellow_pages.pl:65`).

### Mode A — bootstrap: `yellow_pages.pl <anything-but-"pending">`

Any argument other than the literal `pending` runs discovery:

1. `GET https://www.yellowpages.com/categories`, scrape every
   `href` matching `categories/([\w-]+)`, upsert into
   `yellow_pages.yellow_pages_categories`.
2. For each known category, `GET .../categories/<category>`, scrape the
   per-city links and upsert into `yellow_pages.yellow_pages_citycat`.
3. Truncate `yellow_pages.pending_yp` and refill it from
   `yellow_pages.yellow_pages_citycat`, then `exit`.

The HTTP calls go through `AnyEvent::UserAgent` (async), and each phase waits
on **its own** condvar before moving on. This matters: an `AnyEvent` condvar
is single-use, so once Step 1's has fired every later `recv()` on it returns
immediately. Sharing one condvar across both phases made Step 2 return
before a single HTTP callback ran, leaving `yellow_pages_citycat` empty and
every downstream queue rebuild a no-op. Don't collapse these back into one
condvar.

Bootstrap exits non-zero if it discovers no city URLs, rather than reporting
success on an empty queue.

### Mode B — rebuild queue: `yellow_pages.pl pending`

Truncates `yellow_pages.pending_yp` and refills it from
`yellow_pages.yellow_pages_citycat`, prefixing `https://www.yellowpages.com`
and sharding each row to a random host from the configured fleet:

```sql
insert into yellow_pages.pending_yp (url,host)
select concat('https://www.yellowpages.com', c.url) as url,
       (?::text[])[1 + floor(random() * array_length(?::text[], 1))::int] as host
  from yellow_pages.yellow_pages_citycat c
on conflict do nothing;
```

Two things here are load-bearing:

- **The `www.` prefix.** `https://yellowpages.com/...` 301-redirects to the
  homepage. The worker followed that redirect, parsed the homepage as an
  empty listing page, found no `div.info`, and marked the URL `status = 200`
  — so the crawl "succeeded" while extracting nothing.
- **The array subscript, not a `LATERAL` join.** `random()` is volatile so
  the subscript is re-evaluated per row. A `cross join lateral (... order by
  random() limit 1)` is *uncorrelated* and assigns every row the same host —
  verified against PostgreSQL. Don't "simplify" it back.

Mode B now `exit`s when done instead of falling through into the worker
loop, and exits non-zero when `yellow_pages_citycat` is empty, pointing you
at bootstrap.

### Mode C — worker: `yellow_pages.pl` (no arguments)

This is what you run on each crawler box. It claims work by hostname:

```sql
select url from yellow_pages.pending_yp where resolved is null and host = ?
```

with `?` bound to `Sys::Hostname::hostname()`. A box whose hostname is not
in the configured fleet gets zero rows — but it now says so explicitly,
distinguishing an empty queue from a sharding mismatch and naming the hosts
the queue *is* assigned to, instead of printing `got -1` and exiting.

For each page fetched (max `$maxReqs = 10` in flight, `$maxQueue = 10`
queued — `:56-57`):

- **Pagination.** Reads `<span class="showing-count">` for
  `Showing 1-N of M`, computes the page count, and enqueues
  `<url>?page=2..n` rows into `yellow_pages.pending_yp` tagged with the
  local hostname (`:228-245`).
- **Extraction.** For each `div.info` block, pulls the fields listed in
  [Field mapping](#field-mapping) and inserts one row into
  `yellow_pages.yellow_pages_loading` (`:249-328`).
- **Bookkeeping.** `update yellow_pages.pending_yp set resolved = now(),
  status = 200` on success; on any non-success response the actual status
  code is recorded and the row marked resolved. Previously only 404 was
  recorded, so a 403 or 5xx left the row `resolved is null` forever and the
  queue never drained.

The outer `do { ... } while` re-queries for unresolved rows and loops until
the queue drains (`:216-350`).

`SIGHUP` prints the process start time and arguments — useful for checking
on a long-running worker (`:67-70`).

#### Field mapping

| DB column | Source in the listing HTML |
|---|---|
| `name` | first element of class `business-name` |
| `website` | `href` of class `track-visit-website` |
| `tags` | literal `BBB-Accredited` if class `bbb-rating` present, else `""` |
| `phone` | class `phone`, falling back to `phones phone primary` |
| `address` | class `street-address`, falling back to `adr`, else the sentinel `123 Anystreet, HV` |
| `city`, `state`, `zip` | class `locality`, split by `/(.*?),.?(\w\w).?(\d+)/` |
| `category` | trailing path segment of the crawled URL |

Two things to know about this mapping. The `address` fallback writes a
**sentinel string**, not NULL — filter `address <> '123 Anystreet, HV'`
downstream. And the INSERT is built dynamically from whichever keys got
populated (`:315-322`), so the column list varies row to row; a listing
with no parseable locality simply omits `city`/`state`/`zip`.

### Bot protection (read this before planning a big crawl)

As of 2026-09, yellowpages.com returns **HTTP 403 to most automated
requests** for listing pages, independent of `User-Agent` — it's edge bot
protection, not a UA check. A verification run got exactly one page through
out of ten concurrent requests; the rest were blocked or timed out.

So a full crawl will mostly record 403s rather than listings. The code path
is correct end to end (the one page that succeeded yielded 10 business rows
with names, phones, and localities), but throughput is limited by the site,
not the script. Before scheduling a long run, sample a handful of URLs and
check the status distribution:

```sql
select status, count(*) from yellow_pages.pending_yp group by status;
```

Because non-200 statuses are now recorded, that query is meaningful — a
wall of 403s means the crawl is blocked, not slow.

### Known rough edges

- `yellow_pages.yellow_pages_loading` has no unique constraint and the
  INSERT has no `ON CONFLICT`, so re-crawling duplicates rows.
  De-duplicate on promotion.
- `%seen`, `%disperse`, `$disperseTime`, `$maxSameDomain` are declared
  (`:53-60`) but never used — leftovers from `extractEmail.pl`, which
  shares this script's skeleton.
- No `robots.txt` handling and no per-domain rate limiting beyond the
  global `$maxReqs = 10`. Politeness comes from sharding across four hosts.

---

## `stats_yp.pl` — progress monitor

```sh
./parsers/stats_yp.pl
```

Samples the queue every 10 seconds and prints remaining URLs, completed
requests, requests/minute, and an ETA (`Time::Seconds->pretty`).

**It queries the wrong table.** The SQL at `parsers/stats_yp.pl:64` reads
`pending`, which is `extractEmail.pl`'s queue, not
`yellow_pages.pending_yp`. To monitor a Yellow Pages crawl, change both
`from pending` occurrences to `from yellow_pages.pending_yp`. Adding
`and host = <this host>` scopes it to one shard.

---

## Generation 1 — the file-backed spiders

Kept for reference. They predate the `yellow_pages.pending_yp` queue and
store state as HTML files under `parsers/data/`. None of them touch
PostgreSQL.

### `ypSpider_treeParser.pl`

The original crawler. Takes no arguments. Reads
`parsers/QandACategory.list` (61 categories) and
`parsers/PopularCities.list` (50 cities) through `DBD::CSV`, forms the
**cartesian product** as search URLs:

```
https://www.yellowpages.com/search?search_terms=<cat>&geo_location_terms=<city>&page=1
```

Then runs two passes with `LWP::Parallel::UserAgent` (subclassed as
`chattyUA` for connect/failure/return logging): pass 1 fetches page 1 of
each query to read `Showing 1-30 of N` and derive the page count, pass 2
fetches the remaining pages. Every response is cached to
`./data/<query>.html`, and a cached file short-circuits the fetch — so
re-running resumes rather than re-downloading.

`mkdir -p ./data` first; it dies if the directory is missing.

Note `PopularCities.list:41` reads `San DiegomCA` — a typo for
`San Diego,CA` that silently produces a malformed geo term.

### `ypSpider.pl`

```sh
./parsers/ypSpider.pl <basename-of-csv-in-cwd>
```

Not a Yellow Pages crawler — it is the **downstream website crawler**,
seeded from a YP result CSV. Reads the CSV via `DBD::CSV` (pass the
basename; the `.csv` extension is implied by `f_ext`), builds a
website→phone map, fetches each business website in parallel, pipes each
response through `parseURL.pl --output=url` to harvest links, fetches those
links, and appends a link tree to `data/<url>`.

This is the direct ancestor of `parsers/extractEmail.pl`, which does the
same job against the `pending` / `email` tables. Prefer `extractEmail.pl`.

### `ypSpider_html5debug.pl`

An abandoned spike: same category×city setup as `ypSpider_treeParser.pl`,
but pipes responses through an external `html5debug` command and
`Data::Serializer` instead of `HTML::TreeBuilder`. It hits an unconditional
`exit` at `:142` after dumping the first response. Not runnable.

---

## Supporting utilities

### `parseYP.csv.pl`

```sh
./parsers/parseYP.csv.pl saved_page.html   # or: cat page.html | ./parsers/parseYP.csv.pl
```

Standalone listing-page → CSV extractor. Same `div.info` selector logic as
`yellow_pages.pl`, but emits quoted CSV on stdout instead of inserting. Use
it to re-process the cached `data/*.html` from the generation-1 spiders, or
to eyeball what a page yields before running a crawl.

Two quirks: it collects a `@headers` array but never prints it, so output
has no header row (columns are the alphabetical field order:
`Address,City,Email,Name,Phone,State,Tags,Website,Zip`). And it
**synthesizes a fake email** per row of the form
`bogus_<address>@<name>.com` (`:149-152`) — do not load that column
anywhere.

### `parseURL.pl`

```sh
cat page.html | ./parsers/parseURL.pl --output=url
./parsers/parseURL.pl --file=page.html --output=fqdn --output=query
./parsers/parseURL.pl --help
```

General URL extraction over arbitrary text, via `URI::Find`. `--output`
is repeatable and selects parts: `url`, `fqdn`, `query`, `params`, `path`,
`scheme`, `email`, plus `domain`, `host`, `tld`, `authority`, `fragment`.
`--count` prints the match count, `--verbose` dumps the parse tree.

The generation-1 spiders shell out to this (through `IPC::Run`) both for
link harvesting and to derive cache filenames from query strings, so it
must be on `PATH` — `DEPS.md` does this by symlinking `parsers/*.pl` into
`~/bin`.

### Data files

- `parsers/QandACategory.list` — 61 service categories, CSV with a
  `Category` header.
- `parsers/PopularCities.list` — 50 US cities, CSV with `City,State`.

Only the generation-1 spiders read these. `yellow_pages.pl` discovers its
categories from the site itself.

---

## Database schema

`etc/yellow_pages.sql` creates a dedicated `yellow_pages` schema and the
four crawler tables inside it, with `CREATE SCHEMA IF NOT EXISTS` /
`CREATE TABLE IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS`, so it's safe to
run against a fresh database or one that already has some of these
objects — e.g. from an older checkout, before the `host` sharding column
was added to `yellow_pages.pl` on 2025-07-12, or from before these tables
lived in their own schema (`public.pending_yp` etc.). Callers must
schema-qualify references to these tables, or `SET search_path` to
include `yellow_pages`.

### Crawler tables (`yellow_pages` schema)

```sql
-- work queue; one row per URL to fetch
CREATE TABLE yellow_pages.pending_yp (
    url      varchar(2000) NOT NULL PRIMARY KEY,
    resolved timestamp with time zone,   -- NULL = not yet fetched
    status   integer,                    -- HTTP status, only 200/404 recorded
    host     varchar(255)                -- worker hostname() this URL is sharded to
);

-- categories discovered from /categories
CREATE TABLE yellow_pages.yellow_pages_categories (
    id       integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    category varchar(255) UNIQUE
);

-- per-city category listing paths, e.g. /los-angeles-ca/plumbers
CREATE TABLE yellow_pages.yellow_pages_citycat (
    id  integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    url varchar(2000) UNIQUE
);

-- raw scrape landing zone; no constraints, duplicates expected
CREATE TABLE yellow_pages.yellow_pages_loading (
    id       integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    address  varchar(255),
    city     varchar(80),
    name     varchar(255),
    phone    varchar(255),
    state    varchar(2),
    tags     varchar(255),
    website  varchar(2000),
    zip      varchar(11),
    category varchar(255)
);
```

`etc/yellow_pages.sql` also adds a partial index,
`yellow_pages.pending_yp (host) WHERE resolved IS NULL` — the worker's hot
query is `where resolved is null and host = ?` against a table that grows
to one row per listing page across 61 categories × every US city.

The `UNIQUE` constraints on `yellow_pages_categories.category` and
`yellow_pages_citycat.url` are load-bearing: both crawler inserts use
`on conflict ... do nothing` and depend on them.

### Curated table (`yp` schema)

`etc/tables.sql:9` defines the promotion target — same columns as
`yellow_pages.yellow_pages_loading` plus a foreign key to the shared
`domain` table:

```sql
CREATE TABLE yp.yellow_pages (
    id       integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    address  varchar(255),
    city     varchar(80),
    name     varchar(255),
    phone    varchar(255),
    state    varchar(2),
    tags     varchar(255),
    website  varchar(2000),
    zip      varchar(11),
    category varchar(255),
    did      integer REFERENCES domain(id)
);
```

Requires `CREATE SCHEMA yp;` and the `public.domain` table
(`etc/tables.sql:27`). No script in `parsers/` writes to `yp.yellow_pages`
or populates `did` — that promotion step is manual, and the queries in
`etc/scratch.sql` are what exists of it.

### Where the data goes next

`etc/scratch.sql` holds the hand-run SQL that feeds the rest of the
pipeline. The load-bearing ones:

```sql
-- seed the website crawler (extractEmail.pl's queue) with YP websites
insert into pending (url)
select yp.website from yellow_pages yp
  left join email e on yp.website = e.website
 where length(yp.website) > 0 and e.website is null
on conflict do nothing;                              -- scratch.sql:43

-- seed MX verification
insert into mx_domain
select domain(website) from yellow_pages where length(website) > 0
on conflict do nothing;                              -- scratch.sql:47

-- build the send list from verified addresses
insert into track_email (email,name,website) ...     -- scratch.sql:58
```

So the full chain is:

```
yellowpages.com
   → yellow_pages.pl        → yellow_pages.yellow_pages_loading
   → (manual promotion)     → yp.yellow_pages
   → scratch.sql:43         → pending
   → extractEmail.pl        → email
   → scratch.sql:47 + whois.pl / mx verification
   → scratch.sql:58         → track_email  → bin/sendMail*.pl
```

Note `yp.yellow_pages` (the curated promotion table) is a separate table
in a separate `yp` schema — not one of the four `yellow_pages`-schema
crawler tables above, despite the similar name.

`etc/verified_yphdrurl_singleton.sql` defines a view over
`yp.yellow_pages ⋈ email ⋈ mx.verified` that picks one verified,
non-Gmail address per domain, excluding domains that map to more than one
business name.
