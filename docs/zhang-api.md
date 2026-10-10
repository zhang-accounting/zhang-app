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
  `{"data":{"replaced":[]}}`; the account document upload still answers `201` with an empty body.
* Errors are **always** JSON `{"message": "…"}` (no `origin`):

| Status | When | Example `message` | App exception |
|---|---|---|---|
| 400 | bad parameter / name the ledger cannot read back | `parameter :to of report.flows is missing`, `size must be between 1 and 1000`, `invalid account "Foo:Bar": …`, `invalid tag "two words": …` | `ApiServerError(400)` |
| 401 | credentials missing / wrong | `unauthorized` (no `WWW-Authenticate` header) | `ApiUnauthorized` |
| 403 | document outside the ledger directory | `the document ../../etc/hosts is outside the ledger's directory…` | `ApiUnauthorized(403)` |
| 404 | unknown account / commodity / transaction / built-in query, missing document | `not found`, `there is no built-in query nope.nope`, `there is no transaction …` | `ApiNotFound` |
| 404 / 405 | route the server does not have (API version mismatch) | `no route GET /api/statistic/summary`, `no route GET /api/accounts/X/balances: the path takes another method` | `isMissingRoute == true` → "API mismatch" message |
| 409 | reload failed / file changed | `the ledger failed to reload, so the version loaded before is still shown…` | `ApiServerError(409)` |
| 415 / 422 | wrong content type / body does not deserialize | `Failed to deserialize the JSON body into the target type: missing field \`metas\`…` | `ApiServerError` |

  A `200` that is not JSON (a URL that is not a zhang API) is an `ApiParseError`.

### 1.3 Authentication

* Password sign-in (`--auth user:pass` / `ZHANG_AUTH`) enables HTTP Basic on every `/api/*` route (SSE and document
  downloads included). The app sends `Authorization: Basic base64(user:pass)`; the scheme is case-insensitive on v0.2.
  Basic is not rate-limited and needs no session.
* `GET /api/auth/status` (no credentials needed) →
  `{"enabled","authenticated","methods":{"password","passkey"},"passkey_registered","user","title"}`.
  The connection test calls it after a `401`: `enabled && !methods.password` (passkey only, `ZHANG_PASSKEY` without
  `ZHANG_AUTH`) → `ApiPasskeyOnly` ("enable password sign-in"); the app cannot do WebAuthn.
* Not used by the app: `POST /api/auth/login` (cookie session `zhang_session`, 30 days, rate-limited), passkeys.
* Bearer / custom-header profiles are for a reverse proxy in front of zhang; the server ignores `Bearer`.

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
  reloads and sends SSE `Reload` (~200 ms on the test ledger). `POST /api/reload` is synchronous: `200 {"data":"Ok"}` or
  `409` with the reason.
* Failed reloads are reported: SSE `ReloadFailed {file, message}` and `/api/info.reload_failure` (`{file, message}` or
  `null`); the server keeps serving the version it loaded before.
* Validation: names the ledger cannot read back are refused (400). An unbalanced transaction or an unknown / closed
  account is **still written** (it shows up in `journals.errors`) – call the preview first (§4.3).

---

## 2. Endpoints the app calls

| Method | Path | Used for (repository / provider) |
|---|---|---|
| GET | `/api/info` | version gate, title, `reload_failure` (`ZhangApiClient.info`, `serverGateProvider`, `serverInfoProvider`) |
| GET | `/api/auth/status` | passkey-only detection in the connection test |
| GET | `/api/options` | operating currency, timezone (`ledgerOptionsProvider`) |
| GET | `/api/sse` | `Connected` / `Reload` / `ReloadFailed` events (`ledgerEventsProvider`) |
| POST | `/api/reload` | "Retry" on the reload-failed banner |
| POST | `/api/query/builtins`, `/api/query/builtins/{name}` | reports, errors, form data, balance history, budgets, documents (§3) |
| GET | `/api/journals?page&size&keyword&tags[i]&links[i]` | journal list, Home recent rows, transaction lookup (`JournalRepository.list`) |
| POST | `/api/transactions/preview` | validation before saving (`JournalRepository.preview`) |
| POST | `/api/transactions` | create (`JournalRepository.create`) |
| PUT | `/api/transactions/{id}` | replace (`JournalRepository.update`, no screen yet) |
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
| `budgets.events` | `name, month` | `date, time, timestamp:int, type:str` (`assign`), `amount:amount` | `BudgetRepository.interval` |
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
  ("*" / "!"), postings:[{account, unit: Amount|null}], metas:[{key,value}], tags:[], links:[]}` → `200 {"data":"Ok"}`
  (no id). `narration`, `metas`, `tags`, `links` are required keys. At most one `unit: null` posting.
* `POST /api/transactions/preview` (same body; `/api/transactions/{id}/preview` for edits) →
  `{"text": string|null, "field_errors": [{posting, field, kind, value, message}], "unbalanced": [Amount]|null,
  "errors": [{error_type, metas:{…}}]}`. `unbalanced` is `[]` when balanced, `null` when a field is invalid;
  an unbalanced entry also lists `UnbalancedTransaction` in `errors`; an unopened account gives
  `AccountDoesNotExist {account_name}`. The record screen saves only a clean preview and lists the problems otherwise.
* `PUT /api/transactions/{id}` replaces the transaction → `200 {"data":null}`; posting `cost` / `price` / `comment`
  are **kept** when the keys are omitted; unknown id → 404; plugin-generated → 400.
* Not available: `DELETE /api/transactions/{id}` (405), an id in the create answer, idempotency keys.

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
4. No `DELETE` for transactions, no id from `POST /api/transactions`, no idempotency key, no budget writes.
5. A source build reports version `0.1.0`; use `format` to detect v0.2.
6. `/openapi.json` is not behind auth.

Local dev server, ports and the test ledger: see [`dev.md`](dev.md).
