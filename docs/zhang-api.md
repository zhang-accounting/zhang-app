# zhang HTTP API contract (for the Flutter client)

Source of truth: `/Users/kilerd/Projects/zhang` @ `main` (commit `966c8c6`), routes in
`zhang-server/src/lib.rs`, handlers in `zhang-server/src/routes/*.rs`, DTOs in
`zhang-server/src/request.rs` / `response.rs`. Every sample response below was captured from a running
server (`target/debug/zhang`, version `0.1.0`, build date `2026-10-02`) on a copy of
`examples/main.zhang` plus a small extra file (prices, a budget, a BTC lot, a document, one unbalanced
transaction, one failing balance check). Samples are trimmed with `…` where noted, never edited otherwise.

Ledger timezone during capture: `Asia/Tokyo` (UTC+9, server system timezone). Operating currency: `CNY`.

---

## 1. Conventions (read this first)

### 1.1 Transport

* Base URL: `http://<host>:<port>` (default port `8000`). All API paths start with `/api/`.
* Request bodies: `Content-Type: application/json` (except document uploads: `multipart/form-data`).
  Missing/other content type on JSON endpoints → `415` plain text.
* CORS is fully permissive (`access-control-allow-origin: *`) – irrelevant for mobile, matters only for Flutter web.
* Request body limit: 250 MB.
* Gotcha: unknown paths (e.g. `GET /api/nope`) do **not** 404. They hit the fallback and return
  `200 text/plain` "hello zhang, seems you are trying to access the frontend UI…". Wrong method on a known
  path returns `405` with empty body. Never treat a `200` as success without checking `content-type: application/json`.
* Non-API extras served by the framework (`gotcha`): `GET /openapi.json` (generated OpenAPI spec),
  `GET /scalar`, `GET /redoc`. They are **not** behind Basic auth. This document is authoritative where they disagree.

### 1.2 Response envelope

| Situation | Status | Body |
|---|---|---|
| Success with payload | `200` | `{"data": <payload>}` (`content-type: application/json`) |
| "Created" endpoints (balance POSTs, account document upload, file PUT) | `201` | **empty body, no content-type** |
| Handler error: not found | `404` | `{"message":"not found","origin":"with_rejection"}` |
| Handler error: bad request | `400` | `{"message":"bad request","origin":"with_rejection"}` |
| Handler error: anything else (invalid account, IO, SQL, bad enum in path) | `500` | `{"message":"<text>","origin":"with_rejection"}` e.g. `"core error: account is invalid"`, `"io error: Matching variant not found"`, `"sql error: …"` |
| Query-string deserialization failure (`/api/statistic/*`, `/api/budgets*`, `/api/errors`) | `400` | **plain text**, e.g. `Failed to deserialize query string: missing field \`to\`` |
| Query-string failure on `/api/journals` | `400` | **empty body** (custom `serde_qs` extractor) |
| JSON body type mismatch / missing field | `422` | **plain text**, e.g. `Failed to deserialize the JSON body into the target type: missing field \`metas\` at line 1 column 185` |
| JSON syntax error | `400` | plain text (`Failed to parse the request body as JSON…`) |
| Wrong/missing Content-Type on JSON endpoint | `415` | plain text ``Expected request with `Content-Type: application/json` `` |
| Basic auth enabled and missing/wrong credentials | `401` | empty body, header `www-authenticate: Basic` |
| Server panic (see §5) | — | **connection closed with no response** (curl reports status `000`). Treat as a network error. |

Client rule: on non-2xx, try to parse JSON `{"message": …}`; if that fails, use the raw text body; if empty, use the status code.

### 1.3 Authentication (HTTP Basic, optional)

* Enabled with `zhang serve <path> --auth user:pass` or env `ZHANG_AUTH=user:pass` (the CLI flag wins).
  The value must contain `:` — otherwise auth is **silently disabled** (verified: `--auth nocolon` → unauthenticated 200).
  The split is at the first `:`, so the password may itself contain `:` (verified with `ZHANG_AUTH='bob:pw:with:colon'`).
* Client must send `Authorization: Basic base64("user:pass")` on **every** `/api/*` request, including `/api/sse`
  and document downloads. The scheme name is case-sensitive: `basic …` → 401.
* Failure: `401 Unauthorized`, empty body, `www-authenticate: Basic` (no realm), no CORS headers.
  CORS preflight `OPTIONS` is also rejected with 401 (only matters for Flutter web).
* There is no login endpoint, token, or session. To "test credentials", call `GET /api/info`.

Verified transcript (server started with `--auth 'alice:s3cret'`):

```
$ curl -si http://127.0.0.1:18001/api/info
HTTP/1.1 401 Unauthorized
www-authenticate: Basic
content-length: 0

$ curl -si -u alice:wrong http://127.0.0.1:18001/api/info      -> HTTP/1.1 401 Unauthorized
$ curl -si -u alice:s3cret http://127.0.0.1:18001/api/info     -> HTTP/1.1 200 OK
{"data":{"title":"My Accounting","version":"0.1.0","build_date":"2026-10-02"}}
$ curl -H "Authorization: Basic $(printf 'alice:s3cret' | base64)" …/api/info   -> 200
$ curl -H "Authorization: basic $(printf 'alice:s3cret' | base64)" …/api/info   -> 401
$ curl --max-time 2 …/api/sse                                   -> 401
$ curl …/openapi.json  (no creds)                               -> 200 (not protected)
```

### 1.4 Amounts and decimals

* **`Amount`** = `{"number": "<decimal string>", "commodity": "<string>"}`.
  `number` is an arbitrary-precision decimal (Rust `BigDecimal`) **serialized as a JSON string**.
  * Scale is preserved from the source, not normalized to the commodity precision: `"-21"`, `"-32.50"`, `"100.00"`,
    `"132768.0"`, `"-474.229"` all occur. Format for display using the commodity `precision` from `/api/commodities`.
  * **Exponent notation occurs**: verified `"1E-8"`, `"-1E+3"`, and the ledger file itself then contains `1E-8`.
    Parse with a decimal parser that accepts exponents; never use `double`.
* **`CalculatedAmount`** = `{"calculated": Amount, "detail": {"<commodity>": "<decimal string>", …}}`.
  * `detail` = raw per-commodity sums (no conversion). For account amounts it always contains the operating
    currency key (value `"0"` if none).
  * `calculated` = everything converted to the operating currency (option `operating_currency`) using `price`
    directives **from that commodity directly to the operating currency**. Commodities without such a direct price
    (e.g. BTC priced only in USD) contribute **0** to `calculated` but still appear in `detail`.
  * Server bug: conversion uses the **earliest** price on or before the date, not the latest
    (sample: USD prices 7.1 on 2023-06-10 and 7.25 on 2023-09-01 → calculations used 7.1).
    If correctness matters, compute conversions client-side from `detail` + `/api/commodities` `latest_price_*`.
* Map key order in `detail` (and every other JSON object keyed by commodity/date/account type) is arbitrary.
* **Requests**: send `number` as a JSON **string** in plain notation (`"-32.50"`). JSON numbers are accepted but
  floats are expanded to their exact binary value — verified: `"number": 1.1` was written to the ledger as
  `1.100000000000000088817841970012523233890533447265625 CNY`.
* Signs follow double-entry bookkeeping (sum of all postings of a transaction = 0 per commodity):

| Account type | Normal sign of balance | Meaning of the sign |
|---|---|---|
| `Assets` | positive | money you have |
| `Liabilities` | negative | money you owe (`-382` = owe 382) |
| `Equity` | negative | opening balances etc. |
| `Income` | negative | `-200` = earned 200 |
| `Expenses` | positive | `88.50` = spent 88.50 |

  UI should flip the sign for Liabilities/Income/Equity when presenting "owed"/"earned".

### 1.5 Dates, datetimes, timezone

* Ledger timezone = option `timezone` (IANA name, read it from `GET /api/options`; always present). If the ledger
  does not set it, the server's system timezone is used (here `Asia/Tokyo`).
* **Response `datetime` fields** (journals, account journals, documents, prices, account `date`, …) are
  `NaiveDateTime` strings `YYYY-MM-DDTHH:MM:SS` with **no offset**, expressed in the **ledger timezone**.
  Date-only directives appear as `T00:00:00`. (chrono would append `.fff…` if sub-second precision existed;
  parse leniently.)
* **`timestamp` fields** are Unix epoch **seconds** (true instants), e.g. `"datetime":"2023-09-10T23:00:00"` ↔
  `"timestamp":1694354400` (= 14:00Z = 23:00 JST).
* **Date fields** (`date` in balance history, `acquisition_date`, graph map keys) are `YYYY-MM-DD`.
* Exceptions (inconsistent, be careful):
  * `/api/statistic/summary` echoes `from`/`to` as UTC **with** `Z`: `"2023-08-31T15:00:00Z"`.
  * `/api/statistic/graph` and `/api/statistic/{type}` echo `from`/`to` as naive **UTC** wall time **without** `Z`:
    `"2023-08-31T15:00:00"` (that is 00:00 JST on 09-01, not 15:00 local).
* **Request datetimes** (`datetime` in transaction bodies, `from`/`to` query params) must be RFC 3339 **with offset**:
  `2023-09-01T00:00:00+09:00`, `2023-08-31T15:00:00Z`, `2023-08-31T15:00:00.000Z` (JS `toISOString`) all work.
  Naive (`2026-10-02T11:00:00`) and date-only (`2023-09-01`) are rejected (422 / 400).
  In query strings `+` must be percent-encoded as `%2B` (an unencoded `+` becomes a space → 400).
  The server converts the instant to the ledger timezone before writing (`2026-10-02T09:30:00.000Z` was written as
  `2026-10-02 18:30:00` in a JST ledger).

### 1.6 Accounts, transactions, flags, ids

* Account names: `Type:Seg:Seg…`, first segment exactly one of `Assets`, `Liabilities`, `Equity`, `Income`,
  `Expenses` (case-sensitive, plural). Anything else → "account is invalid" (500) where parsed.
  In URL paths the `:` may be sent raw or as `%3A`; non-ASCII must be percent-encoded (standard path encoding).
* There is no "expense/income/transfer" type in the API. Everything is a transaction with postings:

| Intent | Postings (unit `null` = let the server infer the balancing amount) |
|---|---|
| Expense paid from cash/bank | `Assets:WeChat -32.50 CNY`, `Expenses:PersonalDiet:Lunch null` |
| Expense on credit card | `Liabilities:CreditCard:Apple -26 CNY`, `Expenses:PersonalDiet:Dinner null` |
| Income | `Income:GrandLordCompany:Salary -2709 CNY`, `Assets:CitiBank:9999 2358 CNY`, `Expenses:GrandLordCompany:Tax null` |
| Transfer | `Assets:CitiBank:9999 -100 CNY`, `Assets:WeChat null` |
| Pay off credit card | `Assets:CitiBank:9999 -500 CNY`, `Liabilities:CreditCard:Apple null` |

  Rules: per commodity the units must sum to 0; **at most one** posting may have `unit: null`. The server does
  **not** validate on write — an unbalanced or otherwise invalid transaction is written anyway and later shows up as
  `is_balanced: false` in `/api/journals` and as an entry in `/api/errors`.
  Suggested client classification of existing transactions: has an `Expenses:*` posting → expense; has
  `Income:*` → income; only `Assets`/`Liabilities` → transfer; `Equity` → opening/adjustment.
* Cost/price (`{26000 USD}`, `@ 7.1 CNY`) can be *read* (`cost` in journal postings, commodity lots) but **cannot be
  written** through the API: the create/update body only has `account` + `unit` per posting. Cross-currency
  transactions created via the API will therefore be unbalanced.
* Response `flag` (transactions): `"*"` (complete/Okay), `"!"` (Warning/pending), or any custom single character.
  Balance items carry `type_` `"C"` (check) / `"P"` (pad) instead.
* Request `flag`: `"Okay"` | `"Warning"` | any single character string (`"*"`, `"!"`, …); omit or `null` → `"Okay"`.
  (`"BalancePad"`/`"BalanceCheck"` are also accepted but must not be used for transactions.) Anything else (e.g.
  `"Pending"`) → 422.
* **IDs are not stable.** A transaction id is `sha256("<file path>-<byte offset of the directive>")` formatted as a
  UUID. Inserting/editing text earlier in the same file changes the ids of everything after it. `sequence` is the
  chronological index and is renumbered whenever an earlier-dated transaction is added. Never persist ids or
  sequences across reloads; refetch after every mutation / SSE `Reload`.

### 1.7 Writes are eventually consistent (reload model)

Every mutation (POST/PUT) writes text into the ledger files and then **asynchronously** reloads the whole ledger.
The HTTP response is returned before the reload finishes (measured: new transaction visible in `/api/journals`
~30 ms after the POST on this ~200-transaction ledger; grows with ledger size). Recommended client flow:
mutate → wait for SSE `{"type":"Reload"}` (or poll briefly) → refetch.

**Reload failures are silent.** If the written text makes the ledger unparsable/unprocessable, the reload fails, the
server keeps serving the old in-memory state, no SSE event is sent, and the server will refuse to start next time.
Verified: `POST /api/accounts/batch-balances` with a `Pad` on `Assets:Crypto 0.01 BTC` (a commodity held at cost)
wrote `balance Assets:Crypto 0.01 BTC with pad Equity:OpenBalancing`; afterwards every reload failed with
`Process Error: TransactionCannotInferTradeAmount` until the line was removed by hand. Client hint: if a mutation
returns 2xx but no SSE `Reload` arrives within a few seconds, warn the user.

New directives are written to the file given by option `directive_output_path`
(default `data/{{year}}/{{month_str}}.zhang`, using the directive's date in the ledger timezone), and
`include "data/2026/10.zhang"` is appended to the main file if that file was not yet included.

---

## 2. Endpoint index

| # | Method | Path | Purpose | Success |
|---|---|---|---|---|
| 1 | GET | `/api/sse` | Server-sent events (Connected / Reload / NewVersionFound) | 200 stream |
| 2 | POST | `/api/reload` | Trigger ledger reload | 200 `{"data":"Ok"}` |
| 3 | GET | `/api/info` | Ledger title + server version | 200 |
| 4 | GET | `/api/store` | Raw internal store dump (debug, unstable) | 200 |
| 5 | GET | `/api/options` | All ledger options | 200 |
| 6 | GET | `/api/errors` | Ledger validation errors (paged) | 200 |
| 7 | GET | `/api/files` | Ledger source files | 200 |
| 8 | GET | `/api/files/{b64path}` | Read a source file | 200 |
| 9 | PUT | `/api/files/{b64path}` | Overwrite a source file | 201 empty |
| 10 | GET | `/api/for-new-transaction` | Payees + open account names for the entry form | 200 |
| 11 | GET | `/api/journals` | Transactions + balance items (paged, filterable) | 200 |
| 12 | POST | `/api/transactions` | Create transaction | 200 `{"data":"Ok"}` |
| 13 | PUT | `/api/transactions/{id}` | Replace transaction | 200 `{"data":null}` |
| 14 | POST | `/api/transactions/{id}/documents` | Attach files to transaction (multipart) | 200 `{"data":"Ok"}` |
| 15 | GET | `/api/accounts` | All accounts with current balance | 200 |
| 16 | GET | `/api/accounts/{name}` | One account | 200 / 404 |
| 17 | POST | `/api/accounts/{name}/documents` | Attach files to account (multipart) | 201 empty |
| 18 | GET | `/api/accounts/{name}/documents` | Account documents | 200 |
| 19 | GET | `/api/accounts/{name}/journals` | Account postings (unpaged) | 200 |
| 20 | GET | `/api/accounts/{name}/balances` | Daily balance history per commodity | 200 |
| 21 | POST | `/api/accounts/{name}/balances` | Balance check or pad (dated now) | 201 empty |
| 22 | POST | `/api/accounts/batch-balances` | Many balance checks/pads | 201 empty |
| 23 | GET | `/api/documents` | All documents | 200 |
| 24 | GET | `/api/documents/{b64path}` | Download document bytes | 200 binary |
| 25 | GET | `/api/commodities` | Commodities with totals + latest price | 200 |
| 26 | GET | `/api/commodities/{name}` | Commodity detail: lots + price history | 200 |
| 27 | GET | `/api/statistic/summary` | Net worth, liability, income, expense for a range | 200 |
| 28 | GET | `/api/statistic/graph` | Daily net-worth series + daily changes per account type | 200 |
| 29 | GET | `/api/statistic/{account_type}` | Per-account totals + top 10 postings for a type | 200 |
| 30 | GET | `/api/budgets` | Budgets for a month | 200 |
| 31 | GET | `/api/budgets/{name}` | One budget for a month | 200 / 404 |
| 32 | GET | `/api/budgets/{name}/interval/{year}/{month}` | Budget events + postings in a month | 200 / 404 |
| 33 | GET | `/api/plugins` | Loaded WASM plugins | 200 |
| 34 | POST | `/api/sql` | Run read-only SQL (DuckDB) over the ledger | 200 |

Route precedence: `/api/statistic/summary` and `/api/statistic/graph` win over `/api/statistic/{account_type}`;
`POST /api/accounts/batch-balances` is a static route.

---

## 3. Endpoint reference

### 3.1 Common

#### GET `/api/info`
No params. Response `data`: `{title: string|null, version: string, build_date: string}`. `title` = option `title`.

```json
{"data":{"title":"My Accounting","version":"0.1.0","build_date":"2026-10-02"}}
```

#### GET `/api/options`
No params. Response `data`: array of `{key: string, value: string}` (all values are strings, order arbitrary).
Always contains the built-ins `operating_currency`, `timezone`, `default_rounding`, `default_balance_tolerance_precision`,
`default_commodity_precision`, `default_booking_method`, `directive_output_path`, plus `title` and any custom `option`s.

```json
{"data":[
  {"key":"title","value":"My Accounting"},
  {"key":"default_rounding","value":"RoundDown"},
  {"key":"default_balance_tolerance_precision","value":"2"},
  {"key":"default_booking_method","value":"FIFO"},
  {"key":"timezone","value":"Asia/Tokyo"},
  {"key":"default_commodity_precision","value":"2"},
  {"key":"directive_output_path","value":"data/{{year}}/{{month_str}}.zhang"},
  {"key":"operating_currency","value":"CNY"}
]}
```

#### GET `/api/errors`
Query (all optional): `page` (u32, default 1, values < 1 treated as 1), `size` (u32, default 100; **`size=0` crashes
the request**). Bad integers → 400 plain text. Response `data`: `Pageable<ErrorEntity>` (see §3.3 `/api/journals` for
`Pageable`). `ErrorEntity`:

| field | type | notes |
|---|---|---|
| `id` | string | error id (for transaction errors equals the transaction id) |
| `span` | object\|null | `{start: int, end: int` (byte offsets in file)`, content: string` (source text)`, filename: string\|null` (relative path)`}` |
| `error_type` | string enum | `UnbalancedTransaction`, `TransactionCannotInferTradeAmount`, `TransactionHasMultipleImplicitPosting`, `TransactionExplicitPostingHaveMultipleCommodity`, `AccountBalanceCheckError`, `AccountDoesNotExist`, `AccountClosed`, `CommodityDoesNotDefine`, `NoEnoughCommodityLot`, `CloseNonZeroAccount`, `BudgetDoesNotExist`, `DefineDuplicatedBudget`, `MultipleOperatingCurrencyDetect`, `ParseInvalidMeta` |
| `metas` | object string→string | context, e.g. `txn_id`, `account_name` |

The web UI uses `page`, `size=10` and shows `total_count` as the error badge.

```json
{"data":{"total_count":2,"total_page":1,"page_size":100,"current_page":1,"records":[
  {"id":"ffdb27ad-bf2d-7315-2b65-381e04f13b2f",
   "span":{"start":745,"end":834,
           "content":"2023-09-08 11:00:00 \"Oops\" \"Unbalanced\"\n  Assets:Paypal -10 CNY\n  Expenses:Clothing 9 CNY",
           "filename":"data/2023/12.zhang"},
   "error_type":"UnbalancedTransaction",
   "metas":{"txn_id":"ffdb27ad-bf2d-7315-2b65-381e04f13b2f"}},
  {"id":"9bc091c4-5de3-08b6-eb05-e2806277c9ea",
   "span":{"start":836,"end":885,"content":"2023-09-10 23:00:00 balance Assets:WeChat 100 CNY","filename":"data/2023/12.zhang"},
   "error_type":"AccountBalanceCheckError",
   "metas":{"account_name":"Assets:WeChat"}}
]}}
```

#### POST `/api/reload`
No body. Queues an asynchronous full reload (at most one pending; extra requests are coalesced) and returns
immediately `{"data":"Ok"}`. Completion is signalled only via SSE `Reload` (failures are silent, see §1.7).
The server also watches local ledger files and reloads on modification (local `fs` source only; not fully reliable —
an external rewrite of an included file was not picked up in testing, so call this after external edits).

#### GET `/api/sse`
`text/event-stream`. Each event is a single `data:` line containing JSON; no `event:` or `id:` fields (all events are
default "message" events). Comment lines (`: ping`) arrive roughly every 10–15 s as keep-alive.

| payload | when |
|---|---|
| `{"type":"Connected"}` | immediately on connect |
| `{"type":"Reload"}` | after each **successful** ledger reload (refetch everything you display) |
| `{"type":"NewVersionFound","version":"0.1.10"}` | checked every 60 s while ≥1 SSE client is connected, if GitHub has a newer zhang release |

Captured (connect, then `POST /api/reload` after 1 s, 14 s window):

```
HTTP/1.1 200 OK
content-type: text/event-stream
cache-control: no-cache

data: {"type":"Connected"}

: ping

data: {"type":"NewVersionFound","version":"0.1.10"}

data: {"type":"Reload"}

: ping
```

Requires the Basic auth header when auth is enabled. Reconnect on drop; the web client treats `onerror` as "server offline".

#### GET `/api/store`
Returns `{"data": <entire internal store>}` with keys `accounts, budgets, commodities, commodity_lots, documents, errors,
metas, options, postings, prices, transactions`. Internal/debug, large, unstable shape — do not use.

### 3.2 Files (raw ledger text)

Path parameter `{b64path}` = **standard base64 (with `=` padding)** of the file path relative to the ledger root,
e.g. `data/2023/12.zhang` → `ZGF0YS8yMDIzLzEyLnpoYW5n`. Invalid base64 crashes the request. If the base64 string
contains `/`, the route cannot match (raw) or crashes (percent-encoded) — see §5.

#### GET `/api/files`
Response `data`: `(string|null)[]` – every file visited while loading (relative paths). Sample:
`{"data":["main.zhang","data/2023/12.zhang"]}`

#### GET `/api/files/{b64path}`
Response `data`: `{path: string, content: string}`. A non-existent path returns `200` with `"content":""`.

```json
{"data":{"path":"data/2023/12.zhang","content":"1970-01-01 commodity BTC\n  precision: 8\n  group: \"Crypto\"\n\n1970-01-01 open Assets:Crypto BTC\n…"}}
```

#### PUT `/api/files/{b64path}`
Body `{"content": "<full new file text>"}`. Overwrites the file (no syntax validation), triggers reload, returns
`201` empty. A broken file → silent reload failure (§1.7). Not needed for a mobile MVP.

### 3.3 Transactions

#### GET `/api/for-new-transaction`
No params. Response `data`:

| field | type | notes |
|---|---|---|
| `payee` | string[] | distinct non-empty payees of all transactions, **unordered**; includes the synthetic `"Balance Check"` and `"Balance Pad"` (filter them out) |
| `account_name` | string[] | names of all **open** accounts, unordered (closed accounts excluded) |

No commodity-per-account constraints, tags or links are provided; derive commodities from `/api/accounts`
`amount.detail` keys / `/api/commodities`.

```json
{"data":{
  "payee":["The Zhang Book Group","Doge Random House","UNIQLO","隆江猪脚饭","Nike","KFC","Mcdonald","Github Restaurant","Vans","Supermarket","Oops","Balance Check","Scgolastic","Exchange","Balance Pad","Adidas","H & M","GrandLordCompany","Amazon"],
  "account_name":["Income:Publisher:Scgolastic","Income:CitiBank:Interest","Liabilities:CreditCard:Apple","Expenses:PersonalDiet:Lunch","Income:GrandLordCompany:Salary","Expenses:Medical", "…22 total…","Assets:WeChat","Expenses:Transportation","Income:Remuneration","Assets:Paypal"]
}}
```

#### GET `/api/journals`
Paged list of transactions **and** balance check/pad items, newest first.

Query parameters (all optional; parsed with `serde_qs`):

| name | type | default | semantics |
|---|---|---|---|
| `page` | u32 | `1` | 1-based; `0` is treated as `1`; past the end → `records: []` with 200 |
| `size` | u32 | `100` | page size, no upper bound; **`size=0` crashes the request** |
| `keyword` | string | none | case-insensitive substring match against payee, narration, any tag, any link, or any posting account name (OR). Empty string matches everything |
| `tags` | string set | none | transaction matches if it has **any** of the given tags |
| `links` | string set | none | transaction matches if it has **any** of the given links |

`keyword`, `tags`, `links` are AND-combined. Balance items have no tags/links, so a `tags`/`links` filter excludes them.

**Array encoding gotcha (verified):** `tags`/`links` must use bracket syntax with **literal, un-encoded** brackets:
`?tags[0]=weekly&tags[1]=food` or `?tags[]=weekly`. `?tags=weekly` → `400` (empty body).
Percent-encoded brackets (`tags%5B0%5D=weekly`) are **silently ignored** (returns unfiltered results).
Dart's `Uri(queryParameters: …)` percent-encodes `[`/`]`, so build this query string by hand
(encode only the values with `Uri.encodeQueryComponent`).

Ordering: by `sequence` descending. `sequence` is the chronological order of the whole ledger (by transaction
datetime, ties by file order), so this is "newest first by date", **not** by insertion time. Pagination is plain
offset/limit over live data: a newly created older-dated transaction shifts later pages.

Response `data` = `Pageable`:

| field | type | notes |
|---|---|---|
| `total_count` | int | number of matching items |
| `total_page` | int | `ceil(total_count / page_size)` |
| `page_size` | int | echo of `size` |
| `current_page` | int | echo of normalized `page` |
| `records` | JournalItem[] | tagged union on `type` |

`JournalItem` when `type == "Transaction"`:

| field | type | notes |
|---|---|---|
| `type` | `"Transaction"` | |
| `id` | uuid string | transaction id (use for PUT / document upload; unstable, §1.6) |
| `sequence` | int | chronological index |
| `datetime` | naive datetime | ledger timezone |
| `payee` | string | `""` if none. Note: a transaction written with only one string has that string as **narration** and payee `""` |
| `narration` | string\|null | |
| `tags` | string[] | without `#` |
| `links` | string[] | without `^` |
| `flag` | string | `"*"`, `"!"` or custom |
| `is_balanced` | bool | `false` if an `UnbalancedTransaction` error exists for it |
| `postings` | Posting[] | see below |
| `metas` | `{key, value}[]` | transaction metadata; attached documents appear as `{"key":"document","value":"attachments/…"}` |

`JournalItem` when `type == "BalanceCheck"` or `"BalancePad"`: `{type, id, sequence, datetime, payee, narration,
type_, postings}` — `payee` is `"Balance Check"` / `"Balance Pad"`, `narration` is the account
(`"Assets:WeChat"`) or `"pad <account> to <pad account>"`, `type_` is `"C"` / `"P"` (note the trailing underscore).
No `tags`, `links`, `flag`, `is_balanced`, `metas` keys.

`Posting`:

| field | type | notes |
|---|---|---|
| `account` | string | |
| `unit` | Amount\|null | as written in the ledger (`null` = implicit/auto-balanced posting) |
| `cost` | Amount\|null | per-unit cost (`{26000 USD}`), null if none |
| `inferred_unit` | Amount | effective amount of this posting (use this for display) |
| `account_before` | Amount | running balance of this account in `inferred_unit.commodity` before the posting |
| `account_after` | Amount | … after the posting |

For a balance check, the single posting is the adjustment the check implies; on a *failing* check the running
balance is reset to the asserted amount (sample below: asserted 100, actual 146094.50 → posting -145994.50, error in
`/api/errors`).

Sample `GET /api/journals?page=1&size=3` (first record shown in full, rest trimmed):

```json
{"data":{"total_count":202,"total_page":68,"page_size":3,"current_page":1,"records":[
  {"type":"Transaction","id":"0a25388b-66a0-cf83-c510-0411ccff76d9","sequence":202,
   "datetime":"2023-09-16T21:56:16","payee":"隆江猪脚饭","narration":"Eating Dinner",
   "tags":[],"links":[],"flag":"*","is_balanced":true,
   "postings":[
     {"account":"Assets:CitiBank:9999","unit":{"number":"-21","commodity":"CNY"},"cost":null,
      "inferred_unit":{"number":"-21","commodity":"CNY"},
      "account_before":{"number":"164630","commodity":"CNY"},"account_after":{"number":"164609","commodity":"CNY"}},
     {"account":"Expenses:PersonalDiet:Lunch","unit":null,"cost":null,
      "inferred_unit":{"number":"21","commodity":"CNY"},
      "account_before":{"number":"1182","commodity":"CNY"},"account_after":{"number":"1203","commodity":"CNY"}}],
   "metas":[]},
  {"type":"Transaction","id":"a52330c7-5f6b-2db2-1e6c-beed2d1fabab","sequence":201,"datetime":"2023-09-16T17:05:48", "…":"…"},
  {"type":"Transaction","id":"1cd3cea9-2a7b-979b-feb7-b96e8f27da0c","sequence":200,"datetime":"2023-09-15T16:01:07", "…":"…"}
]}}
```

Balance check and pad items (from the same endpoint):

```json
{"type":"BalanceCheck","id":"9bc091c4-5de3-08b6-eb05-e2806277c9ea","sequence":186,
 "datetime":"2023-09-10T23:00:00","payee":"Balance Check","narration":"Assets:WeChat","type_":"C",
 "postings":[{"account":"Assets:WeChat",
   "unit":{"number":"-145994.50","commodity":"CNY"},"cost":null,
   "inferred_unit":{"number":"-145994.50","commodity":"CNY"},
   "account_before":{"number":"146094.50","commodity":"CNY"},
   "account_after":{"number":"100.00","commodity":"CNY"}}]}

{"type":"BalancePad","id":"8c2704fe-ef7a-272c-2286-b757719ae95c","sequence":3,
 "datetime":"2023-05-31T01:01:01","payee":"Balance Pad",
 "narration":"pad Assets:CitiBank:9999 to Equity:OpenBalancing","type_":"P",
 "postings":[
   {"account":"Assets:CitiBank:9999","unit":{"number":"158059","commodity":"CNY"},"cost":null,
    "inferred_unit":{"number":"158059","commodity":"CNY"},
    "account_before":{"number":"0","commodity":"CNY"},"account_after":{"number":"158059","commodity":"CNY"}},
   {"account":"Equity:OpenBalancing","unit":null,"cost":null,
    "inferred_unit":{"number":"-158059","commodity":"CNY"},
    "account_before":{"number":"-281465","commodity":"CNY"},"account_after":{"number":"-439524","commodity":"CNY"}}]}
```

Posting with cost (BTC bought at a USD cost):

```json
{"account":"Assets:Crypto","unit":{"number":"0.01","commodity":"BTC"},"cost":{"number":"26000","commodity":"USD"},
 "inferred_unit":{"number":"0.01","commodity":"BTC"},
 "account_before":{"number":"0","commodity":"BTC"},"account_after":{"number":"0.01","commodity":"BTC"}}
```

Filter examples (verified counts on the sample ledger):
`?keyword=Supermarket` → 1, `?keyword=SUPERMARKET` → 1, `?keyword=Expenses:Groceries` → 1, `?keyword=%E9%9A%86%E6%B1%9F` (隆江) → 34,
`?tags[0]=weekly` → 1, `?tags[]=weekly` → 1, `?links[0]=receipt-001` → 1, `?tags=weekly` → 400, `?page=abc` → 400 empty body.

#### POST `/api/transactions`
Creates a transaction. Body (`CreateTransactionRequest`):

| field | type | required | notes |
|---|---|---|---|
| `datetime` | RFC 3339 string with offset | yes | converted to ledger timezone; written at second precision |
| `payee` | string | yes | may be `""` |
| `narration` | string\|null | no (key may be omitted) | **send a string (use `""` for none).** If `null`/omitted the directive is written with a single string, which the parser treats as the *narration*: the payee is lost (verified: payee `"NoFlag"` came back as `payee:""`, `narration:"NoFlag"`) |
| `flag` | string\|null | no | `"Okay"` (default), `"Warning"`, or one char like `"*"`/`"!"` |
| `postings` | `{account: string, unit: Amount\|null}[]` | yes | `unit` key may be omitted (= null). Extra keys are ignored |
| `metas` | `{key: string, value: string}[]` | **yes** (may be `[]`) | missing → 422 |
| `tags` | string[] | **yes** (may be `[]`) | without `#` |
| `links` | string[] | **yes** (may be `[]`) | without `^` |

Response: `200 {"data":"Ok"}` (not 201). Errors: 422 (shape), 415 (content type), 500 `"core error: account is invalid"`
(bad account type prefix). Nothing else is validated (balance, account existence, open status, commodity).

**Round trip (verified).** Request:

```json
POST /api/transactions
{
  "datetime": "2026-10-02T09:30:00.000Z",
  "payee": "Mobile Test Cafe",
  "narration": "Flat white",
  "flag": "Okay",
  "postings": [
    { "account": "Assets:WeChat", "unit": { "number": "-32.50", "commodity": "CNY" } },
    { "account": "Expenses:PersonalDiet:Lunch", "unit": null }
  ],
  "metas": [ { "key": "source", "value": "zhang-app" } ],
  "tags": ["mobile"],
  "links": ["order-42"]
}
```

Response:

```
HTTP/1.1 200 OK
content-type: application/json
content-length: 13

{"data":"Ok"}
```

Text appended to `data/2026/10.zhang` (and `include "data/2026/10.zhang"` appended to `main.zhang`):

```
2026-10-02 18:30:00 * "Mobile Test Cafe" "Flat white" #mobile ^order-42
  Assets:WeChat -32.50 CNY
  Expenses:PersonalDiet:Lunch
  source: "zhang-app"
```

Then `GET /api/journals?page=1&size=1`:

```json
{"data":{"total_count":203,"total_page":203,"page_size":1,"current_page":1,"records":[
  {"type":"Transaction","id":"7c785595-5694-c51e-dd34-115dc2cddeb1","sequence":203,
   "datetime":"2026-10-02T18:30:00","payee":"Mobile Test Cafe","narration":"Flat white",
   "tags":["mobile"],"links":["order-42"],"flag":"*","is_balanced":true,
   "postings":[
     {"account":"Assets:WeChat","unit":{"number":"-32.50","commodity":"CNY"},"cost":null,
      "inferred_unit":{"number":"-32.50","commodity":"CNY"},
      "account_before":{"number":"59.00","commodity":"CNY"},"account_after":{"number":"26.50","commodity":"CNY"}},
     {"account":"Expenses:PersonalDiet:Lunch","unit":null,"cost":null,
      "inferred_unit":{"number":"32.50","commodity":"CNY"},
      "account_before":{"number":"1203","commodity":"CNY"},"account_after":{"number":"1235.50","commodity":"CNY"}}],
   "metas":[{"key":"source","value":"zhang-app"}]}
]}}
```

Other verified variants: `"flag":"!"` → written as `!`; no `flag` key → `*`; `"datetime":"2026-10-02T11:00:00"` → 422
`datetime: premature end of input`; `"flag":"Pending"` → 422; `{"account":"Foo:Bar"}` → 500 `core error: account is invalid`.

How the web UI builds this body (`frontend/src/components/TransactionEditForm.tsx`): `datetime = date.toISOString()`,
each posting's amount text `"<number> <commodity>"` is split on the space into `unit`, an empty amount → `unit: null`,
`tags: []`, `links: []`, `metas` from key/value rows; valid when every posting has an account and at most one amount is empty.

#### PUT `/api/transactions/{id}`
Replaces the transaction text in its source file (same file, same position, even if the date changes). Body: same as
POST. Response `200 {"data":null}`. Unknown id or non-UUID → `400 {"message":"bad request",…}`.

Everything not in the body is lost: posting `cost`/`price`, posting comments, and existing `tags`/`links`/`metas`
(including `document` metas) unless you send them back. To edit safely, start from the `/api/journals` record:
copy `tags`, `links`, `metas` (with `document` entries), and for each posting send `unit` (not `inferred_unit`).
The edited transaction keeps its id; later transactions in the same file may get new ids. (The web UI sends
`tags: []` / `links: []`, i.e. it drops them — do not copy that behaviour.)

Verified: PUT on `04b947dd-…` with payee `"NoFlag Edited"` → `{"data":null}`; journals then show the new
payee/narration under the same id.

#### POST `/api/transactions/{id}/documents`
`multipart/form-data`, one or more file parts (any field name; the web UI uses `file`). **Each part must have a
`filename` and a `Content-Type`**, otherwise the request crashes. Each file is stored at
`attachments/<random uuid>/<filename>` under the ledger root and a meta line `  document: "attachments/…"` is
inserted into the transaction text. Response `200 {"data":"Ok"}`. Unknown id → 400; non-UUID id → crash.

```
$ curl -X POST .../api/transactions/7c785595-5694-c51e-dd34-115dc2cddeb1/documents -F "file=@photo.png;type=image/png"
HTTP/1.1 200 OK
{"data":"Ok"}
# transaction now has metas: [{"key":"source","value":"zhang-app"},
#   {"key":"document","value":"attachments/13f9ced5-57ad-44ff-b2f6-d23fd7b2f329/photo.png"}]
```

### 3.4 Accounts

#### GET `/api/accounts`
No params. Response `data`: `AccountEntity[]`, **unordered**, includes closed accounts.

| field | type | notes |
|---|---|---|
| `name` | string | full account name |
| `status` | `"Open"`\|`"Close"` | |
| `alias` | string\|null | from account meta `alias` |
| `amount` | CalculatedAmount | current balance (as of now) |

```json
{"data":[
  {"name":"Liabilities:CreditCard:Apple","status":"Open","alias":null,
   "amount":{"calculated":{"number":"-474.229","commodity":"CNY"},"detail":{"CNY":"-382","USD":"-12.99"}}},
  {"name":"Assets:Crypto","status":"Open","alias":null,
   "amount":{"calculated":{"number":"0","commodity":"CNY"},"detail":{"CNY":"0","BTC":"0.01"}}},
  {"name":"Assets:Paypal","status":"Open","alias":null,
   "amount":{"calculated":{"number":"132768.0","commodity":"CNY"},"detail":{"USD":"-260","CNY":"134614"}}},
  "… 22 accounts total …"
]}
```

(`Assets:Crypto` calculated is 0 because BTC has no direct BTC→CNY price; `-474.229` = -382 + -12.99 × 7.1.)

#### GET `/api/accounts/{name}`
Response `data`: `{date, type, name, status, alias, amount}` — `date` = open date (naive datetime), `type` = account type
string. Unknown or invalid name → `404 {"message":"not found",…}`.

```json
{"data":{"date":"1970-01-01T00:00:00","type":"Assets","name":"Assets:Paypal","status":"Open","alias":null,
 "amount":{"calculated":{"number":"132768.0","commodity":"CNY"},"detail":{"CNY":"134614","USD":"-260"}}}}
```

#### GET `/api/accounts/{name}/journals`
All postings of the account (no pagination), newest first (datetime desc, then sequence desc). Includes balance
check/pad pseudo-postings (payee `"Balance Check"`/`"Balance Pad"`). Unknown valid name → `[]`; invalid type
prefix → 500 `core error: account is invalid`.

`AccountJournal` fields: `datetime` (naive, ledger tz), `timestamp` (epoch s), `account`, `trx_id`, `payee` (string|null),
`narration` (string|null), `inferred_unit` (Amount: this posting), `account_after` (Amount: running balance after it).

**Bug:** here `trx_id` is the *posting* id, not the transaction id — it does not match `/api/journals` ids and cannot be
used for PUT/upload. (In `/api/statistic/{type}` and budget interval results `trx_id` *is* the transaction id.)
To open the transaction, search `/api/journals?keyword=<payee>` and match on datetime.

```json
{"data":[
  {"datetime":"2023-09-13T14:25:00","timestamp":1694582700,"account":"Assets:WeChat",
   "trx_id":"e7c19293-4205-3209-a353-87dd81d2675c","payee":"Github Restaurant","narration":"Fried Chicken",
   "inferred_unit":{"number":"-25","commodity":"CNY"},"account_after":{"number":"59.00","commodity":"CNY"}},
  {"datetime":"2023-09-10T23:00:00","timestamp":1694354400,"account":"Assets:WeChat",
   "trx_id":"811eb670-aa18-7125-3d96-3a3ccdd52349","payee":"Balance Check","narration":"Assets:WeChat",
   "inferred_unit":{"number":"-145994.50","commodity":"CNY"},"account_after":{"number":"100.00","commodity":"CNY"}},
  "… 56 items total …"
]}
```

#### GET `/api/accounts/{name}/balances`
Daily end-of-day balance history, per commodity. Response `data`: `{"balance": {"<commodity>": [{date: "YYYY-MM-DD",
balance: Amount}]}}`. One entry per day on which the account had a posting in that commodity (gaps = unchanged).
**Arrays are not sorted** — sort by `date`. Unknown account → `{"balance":{}}`; invalid type prefix → 500.

```json
{"data":{"balance":{
  "USD":[{"date":"2023-09-06","balance":{"number":"-260","commodity":"USD"}}],
  "CNY":[{"date":"2023-08-03","balance":{"number":"134857","commodity":"CNY"}},
         {"date":"2023-08-29","balance":{"number":"134702","commodity":"CNY"}},
         "… 46 entries, unsorted …",
         {"date":"2023-06-26","balance":{"number":"134980","commodity":"CNY"}}]
}}}
```

#### POST `/api/accounts/{name}/balances`
Balance assertion (check) or pad, **dated "now"** in the ledger timezone (second precision; no date parameter).
Body is tagged on `type` (case-sensitive):

```json
{"type":"Check","amount":{"number":"20.50","commodity":"CNY"}}
{"type":"Pad","amount":{"number":"134000","commodity":"CNY"},"pad":"Equity:OpenBalancing"}
```

Extra keys are ignored (the web UI sends `{account_name, amount, pad: "", type: "Check"}` — works). Response `201`,
empty body. Invalid account → 500. `"type":"check"` → 422. A check that does not match the actual balance is still
written; it produces an `AccountBalanceCheckError` in `/api/errors`. A pad makes the account equal `amount` by posting
the difference against the `pad` account. Avoid pads on commodities held at cost (§1.7). Written as:

```
2026-10-02 17:22:37 balance Assets:WeChat 20.50 CNY
2026-10-02 17:22:39 balance Assets:Paypal 134000 CNY with pad Equity:OpenBalancing
```

#### POST `/api/accounts/batch-balances`
Body: array of `{"type":"Check","account_name":…, "amount":Amount}` or `{"type":"Pad","account_name":…, "amount":Amount,
"pad":"<account>"}`. Same semantics as above, all dated now. Response `201`, empty body (verified with a 2-item body).
Example body:

```json
[{"type":"Check","account_name":"Liabilities:CreditCard:Apple","amount":{"number":"-382","commodity":"CNY"}},
 {"type":"Pad","account_name":"Assets:WeChat","amount":{"number":"0","commodity":"CNY"},"pad":"Equity:OpenBalancing"}]
```

#### POST `/api/accounts/{name}/documents`
Multipart upload, same part rules as the transaction upload. Each file is stored at `attachments/<uuid>/<filename>` and
a `document` directive dated now is appended, e.g. `2026-10-02 17:22:55 document Assets:WeChat "attachments/2a13…/photo.png"`.
Response `201`, empty body. Account existence is not checked; invalid type prefix → 500.

#### GET `/api/accounts/{name}/documents`
Response `data`: `DocumentEntity[]` of documents attached to exactly this account (see §3.5; here `extension` is always
`null` and `trx_id` always `null`).

```json
{"data":[{"datetime":"2023-09-07T00:00:00","filename":"receipt.txt","path":"attachments/receipt.txt",
          "extension":null,"account":"Assets:Paypal","trx_id":null}]}
```

### 3.5 Documents

#### GET `/api/documents`
All documents (account documents and transaction `document:` metas), newest-added first. `DocumentEntity`:

| field | type | notes |
|---|---|---|
| `datetime` | naive datetime | directive date (account docs) or transaction datetime |
| `filename` | string | base name |
| `path` | string | path relative to ledger root – use for download |
| `extension` | string\|null | despite the name, a **MIME type** guessed from the path (`"image/png"`, `"text/plain"`) |
| `account` | string\|null | set for account documents |
| `trx_id` | string\|null | transaction id for transaction documents |

```json
{"data":[
  {"datetime":"2026-10-02T18:30:00","filename":"photo.png","path":"attachments/13f9ced5-57ad-44ff-b2f6-d23fd7b2f329/photo.png",
   "extension":"image/png","account":null,"trx_id":"7c785595-5694-c51e-dd34-115dc2cddeb1"},
  {"datetime":"2026-10-02T17:22:55","filename":"photo.png","path":"attachments/2a1363e0-7ac6-4bb8-b026-60656452284b/photo.png",
   "extension":"image/png","account":"Assets:WeChat","trx_id":null},
  {"datetime":"2023-09-07T00:00:00","filename":"receipt.txt","path":"attachments/receipt.txt",
   "extension":"text/plain","account":"Assets:Paypal","trx_id":null}
]}
```

#### GET `/api/documents/{b64path}`
`{b64path}` = standard base64 (with padding) of `path`. Returns raw bytes, `content-type: application/octet-stream`
(always; use the MIME from `extension`), `content-disposition: inline; filename="<name>"`.

```
$ curl -si http://127.0.0.1:18000/api/documents/YXR0YWNobWVudHMvcmVjZWlwdC50eHQ=
HTTP/1.1 200 OK
content-type: application/octet-stream
content-disposition: inline; filename="receipt.txt"
content-length: 14

hello receipt
```

Caveats (verified): a non-existent path returns `200` with an **empty body** (and that empty result is cached
permanently in `.cache/data/` under the server's working directory — later uploads to the same path are never served).
If the base64 string contains `/` (happens for some non-ASCII file names), the download is impossible: raw `/` hits the
fallback (200 text/plain), `%2F` crashes. Invalid base64 crashes.

### 3.6 Commodities

#### GET `/api/commodities`
Response `data`: `CommodityListItem[]` (order not guaranteed):

| field | type | notes |
|---|---|---|
| `name` | string | |
| `precision` | int | display decimals |
| `prefix` / `suffix` | string\|null | display symbol (`"¥"`, `"$"`) |
| `rounding` | `"RoundDown"`\|`"RoundUp"` | |
| `group` | string\|null | commodity meta `group` |
| `total_amount` | decimal string | sum held in Assets + Liabilities accounts |
| `latest_price_date` | naive datetime\|null | latest price **to the operating currency** only |
| `latest_price_amount` | decimal string\|null | |
| `latest_price_commodity` | string\|null | always the operating currency when present |

```json
{"data":[
  {"name":"CNY","precision":2,"prefix":"¥","suffix":null,"rounding":"RoundDown","group":null,
   "total_amount":"298631.00","latest_price_date":null,"latest_price_amount":null,"latest_price_commodity":null},
  {"name":"USD","precision":2,"prefix":"$","suffix":null,"rounding":"RoundDown","group":null,
   "total_amount":"-272.99","latest_price_date":"2023-09-01T00:00:00","latest_price_amount":"7.25","latest_price_commodity":"CNY"},
  {"name":"BTC","precision":8,"prefix":null,"suffix":null,"rounding":"RoundDown","group":"Crypto",
   "total_amount":"0.01","latest_price_date":null,"latest_price_amount":null,"latest_price_commodity":null}
]}
```

#### GET `/api/commodities/{name}`
Response `data`: `{info: CommodityListItem, lots: Lot[], prices: Price[]}`.
`Lot` = `{account, amount (decimal string), cost: Amount|null, price: Amount|null, acquisition_date: "YYYY-MM-DD"|null}`
(lots in **all** account types, including Expenses). `Price` = `{datetime (naive), amount: Amount}` (all target
commodities, chronological). **Unknown commodity crashes the request** (connection closed) — only request names from the list.

```json
{"data":{
  "info":{"name":"USD","precision":2,"prefix":"$","suffix":null,"rounding":"RoundDown","group":null,"total_amount":"-272.99",
          "latest_price_date":"2023-09-01T00:00:00","latest_price_amount":"7.25","latest_price_commodity":"CNY"},
  "lots":[
    {"account":"Assets:Paypal","amount":"-260","cost":null,"price":null,"acquisition_date":null},
    {"account":"Liabilities:CreditCard:Apple","amount":"-12.99","cost":null,"price":null,"acquisition_date":null},
    {"account":"Expenses:Clothing","amount":"12.99","cost":null,"price":null,"acquisition_date":null}],
  "prices":[
    {"datetime":"2023-06-10T00:00:00","amount":{"number":"7.1","commodity":"CNY"}},
    {"datetime":"2023-09-01T00:00:00","amount":{"number":"7.25","commodity":"CNY"}}]
}}
```

BTC (lot held at cost, price only in USD → `latest_price_*` null):

```json
{"data":{"info":{"name":"BTC","precision":8,"…":"…","group":"Crypto","total_amount":"0.01","latest_price_date":null,"latest_price_amount":null,"latest_price_commodity":null},
 "lots":[{"account":"Assets:Crypto","amount":"0.01","cost":{"number":"26000","commodity":"USD"},"price":null,"acquisition_date":"2023-09-06"}],
 "prices":[{"datetime":"2023-09-01T00:00:00","amount":{"number":"26000","commodity":"USD"}}]}}
```

### 3.7 Statistics

All three take query `from` and `to` (required, RFC 3339 instants with offset, inclusive on both ends, `+` → `%2B`).
Missing → 400 plain text (`missing field \`to\``); date-only → 400 (`premature end of input`). The web UI uses
`from = <local midnight one month ago + 1s>.toISOString()`, `to = <today 23:59:59 local>.toISOString()` for the
dashboard, and a user-picked range on the report page.

#### GET `/api/statistic/summary?from=…&to=…`
Response `data`:

| field | type | meaning |
|---|---|---|
| `from`, `to` | UTC datetime **with `Z`** | echo |
| `balance` | CalculatedAmount | net worth = Assets + Liabilities balances as of `to` |
| `liability` | CalculatedAmount | Liabilities balances as of `to` (negative = owed) |
| `income` | CalculatedAmount | sum of Income postings in range (negative = earned) |
| `expense` | CalculatedAmount | sum of Expenses postings in range (positive = spent) |
| `transaction_number` | int | transactions in range — **includes** balance check/pad items (server bug) |

```
GET /api/statistic/summary?from=2023-09-01T00%3A00%3A00%2B09%3A00&to=2023-09-30T23%3A59%3A59%2B09%3A00
```

```json
{"data":{
  "from":"2023-08-31T15:00:00Z","to":"2023-09-30T14:59:59Z",
  "balance":{"calculated":{"number":"296692.771","commodity":"CNY"},"detail":{"USD":"-272.99","BTC":"0.01","CNY":"298631.00"}},
  "liability":{"calculated":{"number":"-743.229","commodity":"CNY"},"detail":{"USD":"-12.99","CNY":"-651"}},
  "income":{"calculated":{"number":"-436","commodity":"CNY"},"detail":{"CNY":"-436"}},
  "expense":{"calculated":{"number":"796.729","commodity":"CNY"},"detail":{"CNY":"704.50","USD":"12.99"}},
  "transaction_number":40}}
```

#### GET `/api/statistic/graph?from=…&to=…&interval=Day`
`interval` is **required** (`Day` | `Week` | `Month`, case-sensitive; `day` → 400) but **ignored** — output is always daily.
Response `data`:

| field | type | meaning |
|---|---|---|
| `from`, `to` | naive **UTC** datetime (no `Z`) | echo |
| `balances` | map `"YYYY-MM-DD"` → CalculatedAmount | one key for every **UTC** calendar date from `from` to `to` inclusive; value = net Assets+Liabilities balance at 23:59:59 **UTC** of that date |
| `changes` | map `"YYYY-MM-DD"` → map AccountType → CalculatedAmount | per **ledger-local** date that has postings, the sum of postings per account type (`Assets`, `Liabilities`, `Equity`, `Income`, `Expenses`; only types present) |

Because `balances` uses UTC dates, a JST client sending `2023-09-01T00:00:00+09:00` gets an extra `2023-08-31` key.
Map key order is arbitrary — sort by key.

```json
{"data":{
  "from":"2023-08-31T15:00:00","to":"2023-09-05T14:59:59",
  "balances":{
    "2023-09-02":{"calculated":{"number":"444978","commodity":"CNY"},"detail":{"CNY":"444978"}},
    "2023-08-31":{"calculated":{"number":"445065","commodity":"CNY"},"detail":{"CNY":"445065"}},
    "2023-09-05":{"calculated":{"number":"444774.271","commodity":"CNY"},"detail":{"USD":"-12.99","CNY":"444866.50"}},
    "…":"one key per day 2023-08-31 … 2023-09-05"},
  "changes":{
    "2023-09-01":{
      "Expenses":{"calculated":{"number":"53","commodity":"CNY"},"detail":{"CNY":"53"}},
      "Income":{"calculated":{"number":"-200","commodity":"CNY"},"detail":{"CNY":"-200"}},
      "Liabilities":{"calculated":{"number":"-11","commodity":"CNY"},"detail":{"CNY":"-11"}},
      "Assets":{"calculated":{"number":"158","commodity":"CNY"},"detail":{"CNY":"158"}}},
    "2023-09-05":{
      "Assets":{"calculated":{"number":"-16","commodity":"CNY"},"detail":{"CNY":"-16"}},
      "Expenses":{"calculated":{"number":"108.229","commodity":"CNY"},"detail":{"CNY":"16","USD":"12.99"}},
      "Liabilities":{"calculated":{"number":"-92.229","commodity":"CNY"},"detail":{"USD":"-12.99"}}},
    "…":"…"}
}}
```

#### GET `/api/statistic/{account_type}?from=…&to=…`
`account_type` ∈ `Assets` | `Liabilities` | `Equity` | `Income` | `Expenses` (case-sensitive; `expenses` →
`500 {"message":"io error: Matching variant not found"}`). Response `data`:

| field | type | meaning |
|---|---|---|
| `from`, `to` | naive **UTC** datetime | echo |
| `detail` | `{account: string, amount: CalculatedAmount}[]` | total per account of that type in range, sorted **ascending** by `amount.calculated.number` (Expenses: smallest first; Income: largest income first since negative) |
| `top_transactions` | AccountJournal[] (max 10) | largest postings of that type in range: Assets/Expenses sorted by number desc, Liabilities/Equity/Income asc. Compares raw numbers across commodities (12.99 USD ranks below 30 CNY). `trx_id` here is the real transaction id |

```json
{"data":{
  "from":"2023-08-31T15:00:00","to":"2023-09-30T14:59:59",
  "detail":[
    {"account":"Expenses:RemunerationTax","amount":{"calculated":{"number":"28","commodity":"CNY"},"detail":{"CNY":"28"}}},
    {"account":"Expenses:GrandLordCompany:Tax","amount":{"calculated":{"number":"30","commodity":"CNY"},"detail":{"CNY":"30"}}},
    {"account":"Expenses:Groceries","amount":{"calculated":{"number":"88.50","commodity":"CNY"},"detail":{"CNY":"88.50"}}},
    {"account":"Expenses:PersonalDiet:Dinner","amount":{"calculated":{"number":"170","commodity":"CNY"},"detail":{"CNY":"170"}}},
    {"account":"Expenses:Clothing","amount":{"calculated":{"number":"182.229","commodity":"CNY"},"detail":{"CNY":"90","USD":"12.99"}}},
    {"account":"Expenses:PersonalDiet:Lunch","amount":{"calculated":{"number":"298","commodity":"CNY"},"detail":{"CNY":"298"}}}],
  "top_transactions":[
    {"datetime":"2023-09-03T12:30:00","timestamp":1693711800,"account":"Expenses:Groceries",
     "trx_id":"107c541d-653f-cb3a-e16d-ae192ec3684c","payee":"Supermarket","narration":"Weekly groceries",
     "inferred_unit":{"number":"88.50","commodity":"CNY"},"account_after":{"number":"88.50","commodity":"CNY"}},
    {"datetime":"2023-09-01T08:00:00","timestamp":1693522800,"account":"Expenses:GrandLordCompany:Tax",
     "trx_id":"0f2fa233-33ef-cfb4-8b7f-b28e21c007f9","payee":"GrandLordCompany","narration":"Salary",
     "inferred_unit":{"number":"30","commodity":"CNY"},"account_after":{"number":"904","commodity":"CNY"}},
    "… 10 items total …"]
}}
```

### 3.8 Budgets

Budgets are defined in the ledger (`budget`, `budget-add`, `budget-transfer`, `budget-close` directives); accounts are
linked by the account meta `budget: <name>`. Activity = postings to linked accounts. The API is read-only.

#### GET `/api/budgets?year=YYYY&month=M`
Query: `year` (u32), `month` (u32, 1–12), both optional, default = current year/month of the **server** clock.
Response `data`: `BudgetListItem[]` — only budgets that exist in that month (before a budget's first event → absent;
`2023-08` → `[]`).

| field | type | notes |
|---|---|---|
| `name` | string | |
| `alias` | string\|null | |
| `category` | string\|null | group budgets by this |
| `closed` | bool | |
| `assigned_amount` | Amount | assigned this month, **including rollover** of last month's available amount |
| `activity_amount` | Amount | spent this month on linked accounts |
| `available_amount` | Amount | assigned − activity |

```json
GET /api/budgets?year=2023&month=9
{"data":[{"name":"food","alias":"Eating","category":"Living","closed":false,
  "assigned_amount":{"number":"1000","commodity":"CNY"},
  "activity_amount":{"number":"88.50","commodity":"CNY"},
  "available_amount":{"number":"911.50","commodity":"CNY"}}]}

GET /api/budgets            (server month 2026-10; rollover)
{"data":[{"name":"food","alias":"Eating","category":"Living","closed":false,
  "assigned_amount":{"number":"911.50","commodity":"CNY"},
  "activity_amount":{"number":"0","commodity":"CNY"},
  "available_amount":{"number":"911.50","commodity":"CNY"}}]}
```

#### GET `/api/budgets/{name}?year=YYYY&month=M`
Same query. Response `data`: list-item fields plus `related_accounts: string[]`. Unknown → 404.

```json
{"data":{"name":"food","alias":"Eating","category":"Living","closed":false,
 "related_accounts":["Expenses:Groceries"],
 "assigned_amount":{"number":"1000","commodity":"CNY"},
 "activity_amount":{"number":"88.50","commodity":"CNY"},
 "available_amount":{"number":"911.50","commodity":"CNY"}}}
```

#### GET `/api/budgets/{name}/interval/{year}/{month}`
Path ints (`month` 1–12; **13 crashes the request**). Unknown budget → 404. Response `data`: array, newest first,
tagged on `type`:
* `{"type":"BudgetEvent","timestamp":<epoch s>,"amount":Amount,"event_type":"AddAssignedAmount"|"Transfer"}` (no `datetime` field)
* `{"type":"Posting", …AccountJournal fields…}` — postings to linked accounts within that month (ledger timezone), real `trx_id`.

```json
{"data":[
  {"type":"Posting","datetime":"2023-09-03T12:30:00","timestamp":1693711800,"account":"Expenses:Groceries",
   "trx_id":"107c541d-653f-cb3a-e16d-ae192ec3684c","payee":"Supermarket","narration":"Weekly groceries",
   "inferred_unit":{"number":"88.50","commodity":"CNY"},"account_after":{"number":"88.50","commodity":"CNY"}},
  {"type":"BudgetEvent","timestamp":1693494000,"amount":{"number":"1000","commodity":"CNY"},"event_type":"AddAssignedAmount"}
]}
```

### 3.9 Plugins and SQL

#### GET `/api/plugins`
Response `data`: `{name: string, version: string, plugin_type: ("Processor"|"Mapper"|"Router")[]}[]`.
Sample ledger has none: `{"data":[]}`.

#### POST `/api/sql`
Body `{"sql": "<query>"}`. Runs against an in-memory DuckDB snapshot built per request. Tables: `options`, `accounts`,
`transactions`, `postings`, `transaction_tags`, `transaction_links`, `commodities`, `prices`, `commodity_lots`,
`documents`, `metas`. Response `data`: `{columns: string[], rows: {columns: {name: string, value: any}[]}[]}`.
Values: strings, ints, floats, bools, timestamps as `"2023-05-30 16:01:01 UTC"`; **DECIMAL columns come back `null`**
(cast to `VARCHAR` in SQL). SQL error → `500 {"message":"sql error: …"}`.
**Crashes (connection closed) whenever the ledger has any account `document` directive** (snapshot build bug),
which includes any ledger where the account-upload endpoint was used. Treat as optional.

```json
POST /api/sql  {"sql":"select name, type, status from accounts order by name limit 2"}
{"data":{"columns":["name","type","status"],"rows":[
  {"columns":[{"name":"name","value":"Assets:CitiBank:9999"},{"name":"type","value":"Assets"},{"name":"status","value":"Open"}]},
  {"columns":[{"name":"name","value":"Assets:Crypto"},{"name":"type","value":"Assets"},{"name":"status","value":"Open"}]}]}}
```

---

## 4. Local dev server

The binary is `zhang` from the `zhang-cli` crate. The default build is backend-only (non-API paths return a plain-text
"hello zhang" message); that is all the mobile client needs.

```sh
# 1. build (debug; first build takes several minutes). Produces /Users/kilerd/Projects/zhang/target/debug/zhang
cd /Users/kilerd/Projects/zhang && cargo build -p zhang-cli

# 2. make a throw-away ledger copy. NEVER serve the repo's examples/ dir: every write goes into the ledger dir.
rm -rf /tmp/zhang-ledger && mkdir -p /tmp/zhang-ledger /tmp/zhang-run
cp /Users/kilerd/Projects/zhang/examples/main.zhang /tmp/zhang-ledger/

# 3. run from a scratch working dir (document downloads create ./.cache/data in the CWD)
cd /tmp/zhang-run
/Users/kilerd/Projects/zhang/target/debug/zhang serve /tmp/zhang-ledger --addr 0.0.0.0 --port 8000 --no-report
#    with Basic auth:   ... --auth 'alice:s3cret'      (or: ZHANG_AUTH='alice:s3cret' zhang serve ...)
#    verbose logs:      RUST_LOG=info ZHANG_LOG=info zhang serve ...

# 4. smoke test
curl -s http://127.0.0.1:8000/api/info
# {"data":{"title":"My Accounting","version":"0.1.0","build_date":"2026-10-02"}}
```

CLI (`zhang serve --help`): `<PATH>` ledger dir; `-e/--endpoint` main file (default `main.zhang`); `--addr` (default
`0.0.0.0`); `-p/--port` (default `8000`); `--auth user:pass`; `--source fs|s3|web-dav|github` (or env
`ZHANG_DATA_SOURCE`); `--no-report` (disable hourly anonymous version report). Server starts in about a second;
a ledger that fails to process makes the process exit with `An error occur when serving zhang server: …`.
The plain `examples/main.zhang` copy loads with 0 errors and 197 journal items (its trailing
`include "data/2023/12.zhang"` points to a missing file and is ignored).

Reaching it from the app:
* iOS simulator: `http://127.0.0.1:8000`; Android emulator: `http://10.0.2.2:8000`; physical device: `http://<Mac LAN IP>:8000`
  (requires `--addr 0.0.0.0`, the default).
* Plain HTTP: Android needs cleartext allowed (`android:usesCleartextTraffic="true"` or a network-security-config for
  the dev host); iOS needs an ATS exception (`NSAllowsLocalNetworking` / `NSAllowsArbitraryLoads` in debug).
* Stop the server with Ctrl-C (or `kill <pid>`).

How the samples in this document were produced (verified 2026-10-02): ledger copy in `/tmp/zhang-api-test`
(`examples/main.zhang` + `data/2023/12.zhang` with a BTC commodity, prices, a `food` budget, tags/links/meta, a
document, one unbalanced transaction and one failing balance check), started with
`target/debug/zhang serve /tmp/zhang-api-test --addr 127.0.0.1 --port 18000 --no-report` from cwd `/tmp/zhang-api-run`;
auth checks on a second copy with `--port 18001 --auth 'alice:s3cret'`.

---

## 5. Gotchas and server bugs (client checklist)

1. Envelope is `{"data": …}` for 200s only; 201 responses have **empty bodies**; error bodies are JSON
   `{"message","origin"}`, plain text, or empty depending on the failure (§1.2).
2. Decimal numbers are strings, may use exponent notation (`"1E-8"`), scale is not normalized. Send strings, never floats.
3. Response datetimes are naive ledger-local; statistic `from`/`to` are UTC (summary with `Z`, graph/rank without).
   `timestamp` fields are epoch seconds. Request datetimes need an explicit offset.
4. `/api/journals` array filters need literal `tags[0]=x` / `tags[]=x`; percent-encoded brackets are silently ignored, `tags=x` is 400.
5. IDs and `sequence` change when files change; refetch after SSE `Reload`. `/api/accounts/{name}/journals` `trx_id` is a posting id.
6. Writes are async; reload failures are silent and can leave the ledger unloadable on next start.
7. Always send `narration` as a string (`""` if empty) or the payee becomes the narration.
8. PUT replaces the entire transaction: send back tags, links, metas (incl. `document`) and posting units.
9. No server-side validation of transactions/balances on write; check `/api/errors` (and `is_balanced`) after reload.
10. Unordered collections everywhere (accounts, payees, commodities, balance history, graph maps) — sort client-side.
11. Requests that **crash the handler** (connection closed, no HTTP response; server keeps running):
    `size=0` on `/api/journals`/`/api/errors`; unknown `/api/commodities/{name}`; budget interval month outside 1–12;
    invalid base64 or base64 containing `/` in `/api/documents/…` and `/api/files/…`; non-existent document path is
    200-empty and cached; multipart parts without filename or Content-Type; non-UUID id in
    `POST /api/transactions/{id}/documents`; `/api/sql` on ledgers with account documents.
12. `calculated` conversion uses the earliest (not latest) price and only direct `X → operating_currency` prices.
13. `/api/statistic/summary.transaction_number` counts balance check/pad items; `/api/statistic/graph` ignores `interval`.
14. `/api/for-new-transaction.payee` contains `"Balance Check"`/`"Balance Pad"`.
15. Unknown `GET /api/...` paths return `200 text/plain` (fallback), not 404.
16. Basic auth: scheme is case-sensitive, applies to `/api/sse` too, `/openapi.json` is unprotected, `--auth` without `:` disables auth silently.
