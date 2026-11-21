# zhang HTTP API contract (v0.2, as used by the Flutter client)

Source of truth: zhang `origin/main` @ `07d7fde7` (v0.2 series): routes in `zhang-server/src/lib.rs`, handlers in
`zhang-server/src/routes/*.rs`, built-in queries in `zhang-server/src/builtin.rs`, DTOs in
`zhang-server/src/response.rs`. Every shape below was checked with curl against a debug build serving the test ledger
described in [`dev.md`](dev.md) (`examples/main.zhang` + the 2023-09 extras + a few 2026 entries; ledger timezone
`Asia/Tokyo`, operating currency `CNY`). `test/fixtures/*.json` are captures from that server.

The app targets **zhang ≥ 0.2 only**. The v0.1 contract this file used to describe (zhang `966c8c6`) is in git
history (`git show b37c5b0:docs/zhang-api.md`); [`compat-v0.2.md`](compat-v0.2.md) lists every difference.

---

## 1. Conventions

### 1.1 Version gate

`GET /api/info` → `{"data":{"title","version","build_date","format","reload_failure"}}`.
`format` (`"zhang"` / `"beancount"`) exists only on v0.2. The version string cannot be used: source builds of v0.2
still report `"0.1.0"`. No `format` → the app shows "server too old" (connection test and instead of the tabs) and
requests nothing else (`ServerInfo.isSupported`, `serverGateProvider`, `AppShell`).

### 1.2 Transport, envelope, errors

* Base URL `http(s)://<host>:<port>`, all API paths under `/api/`. JSON bodies need `Content-Type: application/json`
  (else `415`).
* Success: `200 {"data": <payload>}`. A few writes answer `200 {"data":"Ok"}`, `{"data":null}` or
  `{"data":{"replaced":[]}}`; the account document upload still answers `201` with an empty body. On zhang ≥ 0.3
  (PR #818) `POST` and `PUT /api/transactions` answer `{"data":{"id","version"}}` (§4.3).
* Errors are **always** JSON `{"message": "…"}` (no `origin`):

| Status | When | Example `message` | App exception |
|---|---|---|---|
| 400 | bad parameter / name the ledger cannot read back | `parameter :to of report.flows is missing`, `size must be between 1 and 1000`, `invalid account "Foo:Bar": …`, `invalid tag "two words": …` | `ApiServerError(400)` |
| 401 | credentials missing / wrong | `unauthorized` (no `WWW-Authenticate` header) | `ApiUnauthorized` |
| 403 | document outside the ledger directory | `the document ../../etc/hosts is outside the ledger's directory…` | `ApiUnauthorized(403)` |
| 404 | unknown account / commodity / transaction / built-in query, missing document | `not found`, `there is no built-in query nope.nope`, `there is no transaction …` | `ApiNotFound` |
| 404 / 405 | route the server does not have (API version mismatch) | `no route GET /api/statistic/summary`, `no route GET /api/accounts/X/balances: the path takes another method` | `isMissingRoute == true` → "API mismatch" message |
| 409 | reload failed / file changed | `the ledger failed to reload, so the version loaded before is still shown…` | `ApiServerError(409)` |
| 412 | `If-Match` names another version (zhang ≥ 0.3: `PUT`, `DELETE`, update preview) | `the transaction … is not the version the If-Match header names: …` | `ApiServerError(412)` |
| 428 | `DELETE /api/transactions/{id}` without `If-Match` (zhang ≥ 0.3) | `the request needs an If-Match header with the version of the transaction…` | `ApiServerError(428)` (never sent without it) |
| 415 / 422 | wrong content type / body does not deserialize | `Failed to deserialize the JSON body into the target type: missing field \`metas\`…` | `ApiServerError` |

  A `200` that is not JSON (a URL that is not a zhang API) is an `ApiParseError`.

### 1.3 Authentication

* Password sign-in (`--auth user:pass` / `ZHANG_AUTH`) enables HTTP Basic on every `/api/*` route (SSE and document
  downloads included). The app sends `Authorization: Basic base64(user:pass)`; the scheme is case-insensitive on v0.2.
  Basic is not rate-limited and needs no session.
* `GET /api/auth/status` (no credentials needed) →
  `{"enabled","authenticated","methods":{"password","passkey"},"passkey_registered","user","title","app_login",
  "app_login_pkce","app_return_schemes"}` (`app_login` / `app_return_schemes` only on servers with the app login
  handoff, zhang PR #786; `app_login_pkce` only on servers whose handoff takes PKCE and `state`, zhang PR #819).
  The connection test calls it after a `401`: `enabled && !methods.password` (passkey only, `ZHANG_PASSKEY` without
  `ZHANG_AUTH`) → `ApiPasskeyOnly`; with `app_login` the message points to the "Browser" auth type, otherwise to
  "enable password sign-in". Not consulted for "Browser" profiles (their `401` means the session ended).
* **Browser sign-in** ("Browser" auth type, `AuthType.session`; design in [`passkey-login.md`](passkey-login.md)):
  1. `GET /api/auth/status`: `!enabled` → "sign-in not needed"; `enabled && !app_login` (or `zhang-app` not in
     `app_return_schemes`) → "upgrade zhang (PR #786)". `app_login_pkce` decides step 3.
  2. Every sign-in draws fresh `SignInSecrets`: a PKCE (RFC 7636) code verifier and a `state`, 32 bytes each from
     `Random.secure()`, base64url without padding. The system browser (`flutter_web_auth_2`, iOS
     `ASWebAuthenticationSession` / Android Custom Tabs, ephemeral) opens
     `<base>/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback&code_challenge=<BASE64URL(SHA256(verifier))>&code_challenge_method=S256&state=<state>`;
     the user signs in with a passkey or password on zhang's own login page, which then calls
     `POST /api/auth/app/code {"return_to","code_challenge","code_challenge_method","state"}` and navigates to
     `zhang-app://auth/callback?code=<base64url>&state=<state>` (60 s, single use). Only `S256` is accepted; `plain`
     or another method gets no code (the page shows the server's `400`). A browser that was signed in already first
     asks "Sign in to the app as <user>?" with the scheme and host of `return_to` and creates the code only after
     "Continue" (RFC 8252 §8.6, client impersonation); the app's ephemeral session normally shows the login form.
  3. The app accepts exactly that URL: one well-formed `code`, at most one `state`, nothing else
     (`BrowserSignIn.codeFromCallback`). The `state` must be the one it sent; a missing `state` is accepted only when
     the server lacks `app_login_pkce` (older servers ignore the extra parameters and echo none) and never reported it
     before: once a status says `app_login_pkce: true`, the base URL (scheme and host lower-cased, default port and
     trailing `/` dropped) is remembered in shared_preferences
     (`PkceServers`, `zhang.auth.pkceServers.v1`, not per profile) and a later status without the flag does not relax
     the check. A missing or other `state` → "the browser returned a sign-in this app did not start"
     (`stateMismatch`), and the code is never exchanged.
  4. `POST /api/auth/app/exchange {"code","code_verifier"}` (no credentials) → `{"data":{"token","expires_at","user"}}`
     (servers without `app_login_pkce` ignore `code_verifier`; empty counts as absent). A code issued with a challenge needs its verifier,
     one issued without refuses a verifier; a missing or wrong verifier is the same `401` as an unknown code and uses
     the code up. `401 {"message":"invalid or expired code"}` → "expired or already used"; `429` + `Retry-After` (5
     failed attempts / 15 min / client, shared with the password login) → "try again in N s" (`ApiRateLimited`).
  5. Every request then sends `Authorization: Bearer <token>` (`/api/sse` and documents too). Token, `expires_at`
     and user are kept in secure storage. The token is a stateless 30-day HMAC: `POST /api/auth/logout` (called best
     effort on "Sign out") only clears the cookie and does not revoke it; it stops working when `ZHANG_AUTH` /
     `ZHANG_SESSION_SECRET` change or the server restarts without `ZHANG_SESSION_SECRET`. The app then gets `401`
     and Home offers "Sign in again"; it also warns 3 days before `expires_at`.
* Not used by the app: `POST /api/auth/login` (cookie session `zhang_session`, 30 days, rate-limited) and
  `POST /api/auth/app/code` (both called by the login page in the browser; the live test calls them over HTTP).
* Bearer / custom-header profiles are for a reverse proxy in front of zhang (or a session token pasted by hand).

### 1.4 Amounts

* Typed endpoints: `Amount = {"number": "<decimal string>", "commodity": "CNY"}`; numbers are plain-notation strings
  with unnormalised scale (`"-21"`, `"88.50"`, `"1885.0000"`). The parser still accepts `1E-8` (harmless).
  Requests send numbers as strings, never floats.
* Built-in query cells use **`currency`**, not `commodity`: `{"number":"-12.50","currency":"USD"}` (see §3.1).
* `CalculatedAmount = {"calculated": Amount, "detail": {"<commodity>": "<decimal>"}}`; `calculated` is the value in the
  operating currency at the **latest** price on or before the date, through inverse prices and cost currencies
  (BTC 0.01 bought at 26000 USD → 1885.0000 CNY via USD 7.25). Commodities the server cannot value count 0.
* Signs are double-entry: Assets +, Liabilities −, Equity −, Income − (earned), Expenses + (spent).

### 1.5 Dates and times

* Response `datetime` fields are naive **ledger-local** wall-clock strings `YYYY-MM-DDTHH:MM:SS` (no offset);
  `timestamp` fields are epoch seconds; dates are `YYYY-MM-DD`. Built-in queries return `date` and `time`
  (`HH:MM:SS`) cells separately.
* Requests: transaction `datetime` is the **ledger's wall clock without offset** (`2026-10-03T09:30:00`, #726); the app
  sends `ZhangDates.toNaiveIso`. Date-only is refused (422). Ranges are ledger dates `YYYY-MM-DD`, both included.
* "Now" by the ledger: built-in `ledger.now` → `[["2026-10-10","11:58:15"]]` in the ledger timezone. The app keeps the
  offset to the device clock (`ledgerClockProvider`, rounded to 15 min) for today / the current month / new entries.

### 1.6 Ids, writes and reloads

* Ids (`sha256(file-offset)` as UUID) and `sequence` change when the files change; `sequence` has gaps. Never persist
  them; refetch after a reload.
* Writes (`POST`/`PUT /api/transactions`, balance POSTs, uploads) answer once the text is written; the server then
  reloads and sends SSE `Reload` (~200 ms on the test ledger). On zhang ≥ 0.3 (PR #818) every write reloads first and
  answers after, so a request sent after the answer reads what it wrote (SSE `Reload` still follows). `POST
  /api/reload` is synchronous: `200 {"data":"Ok"}` or `409` with the reason.
* Failed reloads are reported: SSE `ReloadFailed {file, message}` and `/api/info.reload_failure` (`{file, message}` or
  `null`); the server keeps serving the version it loaded before.
* Validation: names the ledger cannot read back are refused (400). An unbalanced transaction or an unknown / closed
  account is **still written** (it shows up in `journals.errors`) – call the preview first (§4.3).

---

## 2. Endpoints the app calls

| Method | Path | Used for (repository / provider) |
|---|---|---|
| GET | `/api/info` | version gate, title, `reload_failure` (`ZhangApiClient.info`, `serverGateProvider`, `serverInfoProvider`) |
| GET | `/api/auth/status` | passkey-only detection in the connection test; browser sign-in feature check (`app_login`) |
| POST | `/api/auth/app/exchange` | browser sign-in: one-time code → session token (`BrowserSignIn.exchange`) |
| POST | `/api/auth/logout` | "Sign out" of a browser sign-in profile (best effort; does not revoke the token) |
| GET | `/api/options` | operating currency, timezone (`ledgerOptionsProvider`) |
| GET | `/api/sse` | `Connected` / `Reload` / `ReloadFailed` events (`ledgerEventsProvider`) |
| POST | `/api/reload` | "Retry" on the reload-failed banner |
| POST | `/api/query/builtins`, `/api/query/builtins/{name}` | reports, errors, form data, balance history, budgets, documents (§3) |
| GET | `/api/journals?page&size&keyword&tags[i]&links[i]` | journal list, Home recent rows, transaction lookup (`JournalRepository.list`) |
| POST | `/api/transactions/preview` | validation before saving (`JournalRepository.preview`) |
| POST | `/api/transactions/{id}/preview` | edit check (unchanged transaction: posting flags) and validation before an edit (`JournalRepository.previewUpdate`) |
| POST | `/api/transactions` | create, with an `Idempotency-Key` (`JournalRepository.create`, `CreateIntent`) |
| PUT | `/api/transactions/{id}` | edit from the transaction detail (`JournalRepository.update`) |
| DELETE | `/api/transactions/{id}` | delete from the transaction detail, zhang ≥ 0.3 (`JournalRepository.delete`) |
| GET | `/api/accounts`, `/api/accounts/{name}` | account tree, account header |
| GET | `/api/accounts/{name}/journals` | account postings (incl. sub-accounts) |
| POST | `/api/accounts/{name}/balances`, `/api/accounts/batch-balances` | balance check / pad (`AccountRepository`, no screen yet) |
| GET | `/api/commodities`, `/api/commodities/{name}` | formatting (precision, symbols), lots, prices |
| GET | `/api/statistic/graph?from&to&interval` | Reports cash-flow chart |
| GET | `/api/documents/{b64path}` | document download (`DocumentRepository.download`) |

Retired on v0.2 and no longer called: `GET /api/statistic/summary`, `/api/statistic/{type}`, `/api/errors`,
`/api/for-new-transaction`, `GET /api/accounts/{name}/balances`, `GET /api/accounts/{name}/documents`,
`GET /api/documents`, `/api/budgets*`, `/api/store`, `/api/sql`.

---

## 3. Built-in queries

### 3.1 Calling them

* `POST /api/query/builtins/{name}` with `{"params": {…}, "count_total"?: true}` →
  `{"data":{"columns":[{"name","type"}],"rows":[[cell,…]],"total"?:int}}` (`total` = rows before `LIMIT`/`OFFSET`, only
  with `count_total`).
* Batch: `POST /api/query/builtins` with `[{"name","params","count_total"?}, …]` → `{"data":[result, …]}` in request
  order, computed from **one** read of the ledger (consistent figures). One failing query fails the batch.
* Every parameter is required by name; `date` parameters are `YYYY-MM-DD` (an instant is a 400), `set` parameters are
  string arrays. `GET /api/query/builtins` lists all queries with their parameters and columns.
* Errors: unknown name → 404 `there is no built-in query x`; missing / mistyped parameter → 400
  `parameter :to of report.flows is missing`, `parameter :from must be a date string YYYY-MM-DD or null`.
* Cell encoding (read by column **name** with `QueryRow`, `lib/data/models/query_result.dart`):

| Column type | JSON | Reader |
|---|---|---|
| `int`, `bool` | number / boolean | `integer`, `boolean` |
| `decimal`, `str`, `date`, `interval` | string (decimals in plain notation) | `decimal`, `string`, `date`, `dateTime(date, time)` |
| `set` | sorted string array | `stringSet` |
| `amount` | `{"number","currency"}` | `amount` → `Amount` |
| `position` | `{"units": amount, "cost": {"number","currency","date","label"} \| null}` | `QueryPosition` |
| `inventory` | `{"positions": [position, …]}` | `inventory` → `QueryInventory` |
| `metas` | `[{"key","value"}]` | `metas` |
| any | `null` | `xOrNull` variants |

  Client: `BuiltinQueryClient` (`client.builtins.run/runBatch/query/batch`).

### 3.2 The queries the app uses

| Query | Params | Columns | Used by |
|---|---|---|---|
| `report.net_worth` | `to:date, currency:str` | `balance:inventory` (with cost lots), `units:inventory`, `value:inventory` | summary `balance` |
| `report.liabilities` | `to, currency` | `units, value` (inventories) | summary `liability` |
| `report.flows` | `from, to, currency` | `type:str` (`Income`/`Expenses`/…), `units, value` | summary `income` / `expense` |
| `report.transaction_count` | `from, to` | `transactions:int` (no pads, no assertions) | summary `transactionNumber` |
| `report.account_totals` | `type:str, from, to, currency` | `account:str, units, value` | Reports breakdown (`StatisticRank.detail`) |
| `report.top_postings` | `type, from, to, currency` | `date, time, timestamp:int, account, id, payee, narration, units:amount, account_balance:amount, value:amount` (ranked by `value`) | `StatisticRank.topTransactions` |
| `accounts.balance_history` | `account:str` | `date, currency, balance:amount` (date order; the account **and its sub-accounts**) | account balance chart |
| `accounts.documents` | `account` | `date, time, account, path, transaction_id` | `AccountRepository.documents` |
| `journals.documents` | – | `date, time, path, account, transaction_id` (newest first) | `DocumentRepository.list` |
| `journals.errors` | `size:int, offset:int` (+ `count_total`) | `id, kind, file, line:int, column:int, span_start:int, span_end:int, source, metas:metas` | Home error chip / sheet |
| `journals.payees` | – | `payee` (sorted, no `Balance Check` / `Balance Pad`) | entry-form suggestions |
| `journals.accounts` | `date:date, time:str` | `account` (open at that instant) | entry-form suggestions |
| `ledger.now` | – | `date:date, time:str` (ledger timezone) | ledger clock, `journals.accounts`, budgets' default month |
| `budgets.month` | `month:date` (`YYYY-MM-01`) | `name, alias, category, currency, last_month:date, assigned:amount, activity:decimal, available:amount, closed:bool` | `BudgetRepository.list` |
| `budgets.budget` | `name` | `name, alias, category, currency, accounts:set, close:date, close_time` (no row = unknown) | `BudgetRepository.get` |
| `budgets.budget_month` | `name, month` | as `budgets.month` | `BudgetRepository.get` |
| `budgets.events` | `name, month` | `date, time, timestamp:int, type:str` (`assign` = `budget-add`; `transfer_out` with a negative amount and `transfer_in` = the two sides of a `budget-transfer`), `amount:amount` | `BudgetRepository.interval` |
| `budgets.postings` | `name, month` | `date, time, timestamp, account, id, payee, narration, units:amount, balance:amount` | `BudgetRepository.interval` |

How the app maps them:

* **Summary** (`StatisticRepository.summary`, Home card, journal month headers, Reports KPIs): one batch of the four
  `report.*` queries. Each `CalculatedAmount` is `calculated` = the `value` positions in the operating currency,
  `detail` = `units` per currency (as the web UI's `calculatedAmount`). Income / expense are the `flows` rows of type
  `Income` / `Expenses` (zero when absent).
* **Rank** (`StatisticRepository.rank`): batch `report.account_totals` + `report.top_postings` with the same params.
* **Errors**: `LedgerError` from a row; `metas` is a list (was a map); unknown kinds map to `LedgerErrorType.unknown`.

Not used yet (candidates): `journals.page` (server-side tag/link filter with a correct total), `report.net_worth_trend`,
`report.changes`, `accounts.journal_page`, `postings.between`, `commodities.*`.

---

## 4. Endpoint notes

### 4.1 `GET /api/journals`

* Query: `page` ≥ 1, `size` 1–1000 (else 400 `size must be between 1 and 1000` / `page must be at least 1`),
  `keyword` (case-insensitive substring of payee, narration, tags, links, account names), `tags[0]=x`, `links[0]=x`.
  Percent-encoded brackets (`tags%5B0%5D`) are still **silently ignored** and Dart re-encodes `[`/`]`, so the app
  filters tags client-side; `tags=x` is a 400. Past the last page → `records: []`.
* `data` is a `Pageable`: `{total_count, total_page, page_size, current_page, records}`, newest first by `sequence`.
* `Transaction` item: `{type, id, sequence, datetime, payee, narration, tags, links, flag, is_balanced, postings,
  metas, edit_drops_text}`; posting `{account, unit|null, cost|null, inferred_unit, account_before, account_after,
  metas, written:{cost, price, comment}}`. Attached documents are `document` metas.
* `BalanceCheck` item (`type_` `"C"`): its single posting is a **zero entry** (`unit: null`, `inferred_unit: "0"`,
  `account_before` = `account_after` = the checked balance). The assertion is in
  `asserted`, `checked_balance` (the account and its sub-accounts), `difference` (= asserted − checked),
  `tolerance` (decimal or null) and `passed`. Checks never move balances. The app shows `asserted` and flags
  `passed == false`.
* `BalancePad` item (`type_` `"P"`): postings `[account +padded, pad account −padded]`. A `balance … with pad` yields a
  pad **and** a check at the same datetime; the app folds the check into the pad row (`foldBalancePads`).

Sample (failing check, trimmed):

```json
{"type":"BalanceCheck","id":"df53cd51-…","sequence":220,"datetime":"2023-09-10T23:00:00","payee":"Balance Check",
 "narration":"Assets:WeChat","type_":"C",
 "postings":[{"account":"Assets:WeChat","unit":null,"cost":null,"inferred_unit":{"number":"0","commodity":"CNY"},
   "account_before":{"number":"146183","commodity":"CNY"},"account_after":{"number":"146183","commodity":"CNY"},"metas":[],"written":null}],
 "asserted":{"number":"100","commodity":"CNY"},"checked_balance":{"number":"146183","commodity":"CNY"},
 "difference":{"number":"-146083","commodity":"CNY"},"tolerance":null,"passed":false}
```

### 4.2 `GET /api/accounts/{name}/journals`

Rows of the account **and its sub-accounts** (`account` names the posting's account), newest first:
`{datetime, timestamp, account, trx_id, payee, narration, inferred_unit, account_after, asserted, checked_balance,
difference, tolerance, passed}`. `trx_id` is the **transaction id** (same as `/api/journals`): the app opens the
transaction from an account row (looked up with `/api/journals?keyword=<payee>`). Check rows have `inferred_unit` `0`
and the assertion fields. Optional `page`/`size` with `X-Total-Count` (no params = everything). Unknown account or a
parent without its own `open` → 404 (read as "no postings"); invalid name → 400.

### 4.3 Transactions

* `POST /api/transactions` body: `{datetime (ledger wall clock), payee, narration (always send, "" for none), flag
  ("*" / "!"), postings:[{account, unit: Amount|null}], metas:[{key,value}], tags:[], links:[]}` → zhang ≥ 0.3
  (PR #818): `200 {"data":{"id","version"}}`, the transaction in the ledger reloaded before the answer (`id` and
  `version` are `null` when that reload failed or the load left the transaction out); older servers: `200
  {"data":"Ok"}` (no id). `narration`, `metas`, `tags`, `links` are required keys. At most one `unit: null` posting.
* Idempotent create (zhang ≥ 0.3, PR #831): an `Idempotency-Key` header (1–128 characters of `A-Za-z0-9._~-`, else
  400 `invalid_idempotency_key: …`) is written into the transaction as its `idempotency-key` metadata – a line in
  the ledger file, listed in `metas` like any other. A create whose key a transaction of the files already has writes
  nothing and answers that transaction's `id` / `version` with the header `Idempotency-Replayed: true`, **whatever
  its body** (the key names the action, not the payload). The key is looked up in the files while the create holds
  the ledger for writing, so two creates sent at once write once, and a restart does not forget it. There is no
  time window: the key lasts as long as its metadata; once that transaction is deleted (or an edit drops the
  metadata) a create with the key writes again. A request with the header **and** its own `idempotency-key` in
  `metas` is a 400; the previews ignore the header. Older servers ignore the header (checked live against zhang
  `5c0755c9`, the commit before PR #818: two creates with one key wrote two transactions, both `200 {"data":"Ok"}`).
* How the app uses it (`CreateIntent`, `features/transaction_new/create_intent.dart`): every create sends a key, a
  random UUID v4 made once per save the user means and sent again by every attempt of it – a retry after a
  timeout or a dropped connection, "Save anyway" after the preview's warnings, a save after fixing what the server
  refused. A new entry screen, and each "save and add another", starts a new save; the simple form hands its save
  to the advanced editor. An entry dated "now" keeps the time of the first attempt the server may have written (any
  answer but a 4xx), so whichever attempt was written, the transaction is the same. A replay is a success; when an
  earlier attempt of the save sent another request (the entry was changed after a timeout), the snackbar says the
  transaction was recorded by that earlier attempt and may lack the changes. A request whose own metadata has
  `idempotency-key` (typed in the advanced editor) is sent without the header. Nothing depends on the server
  having the feature, and the answer is a bonus: a 2xx without a readable body (a proxy answering an empty body)
  is a save without an id. The key lives only as long as the entry screen: closing it, or the OS killing the app,
  after an attempt that may have been written and recording the entry again sends a new key and can write it twice.
* The `idempotency-key` metadata is bookkeeping of the save: the transaction detail does not list it, and the
  advanced editor keeps it out of the editable rows and sends it back in place, as an edit that dropped it would
  let a late retry of the creating save write the transaction again. "Copy as text" and the `PUT` of an edit keep
  it.
* `POST /api/transactions/preview` (same body; `/api/transactions/{id}/preview` for edits) →
  `{"text": string|null, "field_errors": [{posting, field, kind, value, message}], "unbalanced": [Amount]|null,
  "errors": [{error_type, metas:{…}}]}`. `unbalanced` is `[]` when balanced, `null` when a field is invalid;
  an unbalanced entry also lists `UnbalancedTransaction` in `errors`; an unopened account gives
  `AccountDoesNotExist {account_name}`. The record screen refuses to save when a field is refused, the entry is unbalanced or an account is unknown /
  closed (`TransactionPreview.isBlocked`); other ledger errors and notices (e.g. `CommodityDoesNotDefine` on a
  beancount ledger that never declares a commodity) are listed as warnings with "Save anyway".
* `PUT /api/transactions/{id}` replaces the transaction → `200 {"data":null}`; unknown / stale id → 404 (`there is no
  transaction … Reopen the journal`); plugin-generated → 400. Request postings also take `metas` and, in the ledger's own
  syntax, `cost` (`{26000 USD}`, `{{1500 USD}}`, `{}`, `{150 USD, 2024-01-15, "lot"}`), `price` (`@ 7.2 CNY`,
  `@@ 72 CNY`) and `comment` (without `;`). In an update a left-out `cost` / `price` / `comment` is kept from the
  posting it is matched to (the only one to that account, else the only one with that account and units), `null`
  removes it; posting `metas` left out are **dropped**; a posting flag cannot be sent and is kept only by that match.
* How the app edits (`CreateTransactionRequest.fromJournal`, `features/transaction_new/transaction_edit.dart`): every
  field read from `/api/journals` is sent back – payee, narration (`""` for none), flag, tags / links in written order,
  transaction metas, per posting the written unit with its decimals (`unitScale`), `metas` and `written.cost / price /
  comment` stated explicitly (`null` = none), so nothing depends on the server's posting match. Checked live: the
  values of an untouched transaction survive; the text is rewritten in the exporter's form, so these change: metadata
  lines in key order (the journal sorts them), a date-only header gains ` 00:00:00`, `{150 USD}` → `{ 150 USD }`, a
  lone narration `"x"` → `"" "x"`, `-0.00` → `0`.
* Edits are refused (with the reason) when `edit_drops_text` is true, a posting has no `written` (plugin) or the server
  reports no posting `metas` / `edit_drops_text`, or the update preview of the unchanged transaction has no `text` or
  shows a posting flag (any flag zhang reads: `*`, `!`, `&`, `?`, `%`, `#`, `A`–`Z`, e.g. `  C Expenses:Food …`).
* Unquoted posting metadata (`lot: 8`, dates, booleans): the journal reports values as strings; the update preview
  text shows which are unquoted. The server keeps a value unquoted only for the posting it matches, so once that
  posting's account changes it writes `lot: "8"`. The app mirrors the match and asks before saving such an edit.
* Ids are places in a file (`hash(file + offset)`): after another write the id of a listed transaction may name
  another one. Servers with zhang PR #818 list a `version` (hash of the transaction's text) on journal items (account
  journal rows: `trx_version`) and POST / PUT answers; the app then sends `If-Match: <version>` with the update preview
  and the `PUT` (mismatch → 412, shown as "changed on the server"), and a transaction opened from an account row whose
  `trx_version` differs from the item's `version` shows "changed". Without `version` the app reads the item by id
  (`JournalRepository.findById`) before the edit check and again right before the `PUT` and refuses unless it is still
  the same transaction; that lookup searches only 5 pages of 100 by payee (an old transaction with a common payee can
  be reported as changed) and leaves a short race before the `PUT`.
* Ids after a `PUT`: the edited transaction keeps its id (it stays at the same place in its file); transactions after
  it in the same file get new ids. The detail screen reads it again by id after the ledger reloaded and shows it only
  once it matches what was saved (else, after 15 s, it says the change is not listed yet).
* Preview errors that block a save also include `TransactionCannotInferTradeAmount`,
  `TransactionExplicitPostingHaveMultipleCommodity` (an empty amount left with several commodities – written
  unbalanced otherwise) and `TransactionHasMultipleImplicitPosting`.
* Opening what was created: when a create answers an id, the snackbar of the save offers "View" (`savedSnackBar`,
  `openWrittenTransaction`) for 6 s, which opens the transaction detail in the Home tab when the entry was recorded
  from Home, else in the Journal tab (also from Accounts and Reports, whose detail routes hang under an account), as
  `…/<id>?q=<payee, narration or first account>&v=<version>`: the detail looks the id up and says "changed" instead
  of showing another transaction if the id has moved by then. The id belongs to the ledger it was saved to: a profile
  switch hides the snackbar, and the action does nothing once that ledger session has ended. No "View" without an id
  (older servers, a failed reload), after "Save and add another" (the entry screen stays open) or for edits.
* `DELETE /api/transactions/{id}` (zhang ≥ 0.3, PR #818) → `200 {"data":null}`, answered after the reload. It needs
  `If-Match: <version>` (several, quoted or not, may be named): without it 428; when the transaction at the id has
  another version, 412 – it changed, or another transaction took the id (the ones after a deleted transaction in its
  file move and the next can take its id), or the server deleted or replaced that very version at that id lately
  (tombstones: in memory, 24 h, the last 1000, gone after a restart), so a delete sent again never removes a twin
  written alike that took the place. Unknown id 404, a transaction a plugin made or the padding of a pad 400, a file
  that changed since the load 409; nothing is deleted then. The text goes with its lines and the blank line after it;
  a comment above it and the documents it names stay. Checked live against zhang `origin/main` (c34d46df): 428
  without `If-Match`, 412 with a wrong version, 200 with the right one; of two identical entries, deleting the first
  moved the second to its id with the same version, and the same delete sent again was a 412 ("deleted or replaced
  lately") that left the second in place; a create with the `Idempotency-Key` of a deleted transaction wrote it
  again. Servers before PR #818: 405 `no route DELETE …: the path takes another method`.
* How the app deletes (`TransactionDetailScreen._delete`, `transaction_actions.dart`): the detail's overflow menu
  (⋮) → "Delete" → a confirmation naming date, payee, narration and amount → `DELETE` with `If-Match` = the
  `version` the detail shows. Offered only for transactions listed with a `version` (`canDelete`): without one
  there is no precondition and a stale positional id could name another transaction, so older servers get no
  delete. Once deleted: a snackbar, the detail closes, the lists refresh on the SSE `Reload` (or the write timer)
  as after an edit. 412 / 404 → "Changed on the server", nothing was deleted, "Refresh" goes back to the list and
  refetches it. Other errors (400, 409) show the server's message. No undo, no swipe-to-delete (decisions.md).

### 4.4 Statistic graph

`GET /api/statistic/graph?from=YYYY-MM-DD&to=YYYY-MM-DD&interval=Day|Week|Month` →
`{"from":"2023-09-01T00:00:00","to":"2023-09-05T23:59:59","balances":{date: CalculatedAmount},
"changes":{date: {AccountType: CalculatedAmount}}}`; `from`/`to` are echoed ledger-local, keys are ledger dates,
`Week`/`Month` buckets are keyed by the bucket's first day. `interval=day` (lower case) → 400.

### 4.5 Documents and commodities

* `GET /api/documents/{base64(path)}` → bytes (`content-disposition: inline; filename=…`); a `/` in the base64 works
  raw or as `%2F`; missing → 404, outside the ledger → 403, invalid base64 → 400.
* `GET /api/commodities` → `[{name, precision, prefix, suffix, rounding, group, total_amount, latest_price_date,
  latest_price_amount, latest_price_commodity}]` (`latest_price_*` only for a direct price to the operating currency);
  `GET /api/commodities/{name}` → `{info, lots (Assets/Liabilities only), prices}`; unknown → 404.

---

## 5. Remaining server gaps (client checklist)

1. Percent-encoded `tags[]`/`links[]` on `/api/journals` are ignored → client-side tag filter (or move to
   `journals.page`).
2. Unbalanced transactions and unknown / closed accounts are written anyway → preview before saving.
3. `--auth` without `:` silently disables auth (server side).
4. No budget writes. `DELETE` for transactions, the id of a create and idempotency keys need zhang ≥ 0.3 (§4.3;
   the app uses all three).
5. A source build reports version `0.1.0`; use `format` to detect v0.2.
6. `/openapi.json` is not behind auth.
7. Edits: posting flags are neither reported by `/api/journals` nor accepted in requests (kept only while the
   posting keeps its account); comment lines inside a transaction are dropped by any `PUT` (`edit_drops_text`);
   unquoted posting metadata is quoted once its posting's account changes; metadata comes back sorted by key; a
   date-only transaction cannot stay date-only (`datetime` needs a time); without `version` / `If-Match`
   (zhang PR #818) a `PUT` can hit another transaction that moved to a stale id.

Local dev server, ports and the test ledger: see [`dev.md`](dev.md).
