# zhang-app vs zhang server v0.2 (origin/main) — compatibility audit

Date: 2026-10-10. Audited by running the new server and the app's own tests; no Dart code was changed.

> **Status (2026-10-10, later):** the app now targets v0.2 only and implements the fixes below (version gate on
> `format`, built-in queries for #1–#8, balance assertions #9–#11, ledger-local graph #12, error shapes #13, preview
> before saving #14, SSE refresh). The current contract is [`zhang-api.md`](zhang-api.md); open items are in
> [`known-issues.md`](known-issues.md). This file is kept as the audit record.

| | |
|---|---|
| App | `feat/mvp` @ `acb27c6` |
| Old contract | `docs/zhang-api.md`, captured at zhang `966c8c6` (= `v0.1.9+153`, 2026-10-02) |
| New server | zhang `origin/main` @ `3538131d` (= `v0.2.0+289`, 294 commits after `966c8c6`) |
| Build | `git worktree add --detach /tmp/zhang-main origin/main` then `cargo build -p zhang` (the package is `zhang`, not `zhang-cli`). Debug build, no frontend feature |
| Test ledger | copy of `examples/main.zhang` + `data/2023/12.zhang` (rebuilt to match the old capture: BTC at cost, USD prices 7.1 and 7.25, a `food` budget, tags/links/metadata, posting metadata and comment, a price posting, an account document, one unbalanced transaction, one failing balance check). Ledger timezone `Asia/Tokyo`, operating currency `CNY` |
| Servers | `:18070` no auth, `:18071` `--auth demo:secret` (also restarted in other auth modes for §d) |

The built binary still reports `"version":"0.1.0"` in `/api/info` (no `.build_version` file in a source build), so the
version string cannot tell an old server from a new one. Use the new `format` key of `/api/info` instead (see §g).

---

## a) Executive summary

**The app partly works against v0.2 today.** Connecting, Basic auth, the journal list, creating a transaction and the
account tree work. Four screens are partly broken, because 8 read endpoints the app calls were removed (they now
answer `404`/`405` JSON) in the `refactor(server)!:` series #754 to #760. The web UI now gets those figures from
**built-in BQL queries** (`POST /api/query/builtins`), and the app has to do the same. Some endpoints that still exist
changed what they mean. The most important is the balance-check journal item (#718): the app now shows the wrong
amount for a balance check, and it cannot flag failed checks any more.

| Screen | State on v0.2 | Why |
|---|---|---|
| Onboarding / Settings | works | Basic auth unchanged (live test passed) |
| Home | **partly broken**: recent list OK; summary card shows an error; error chip silently hidden | `GET /api/statistic/summary` → 404; `GET /api/errors` → 404 |
| Journal | **partly broken**: list, paging and keyword search OK; month-header totals fail; failed balance checks look like passed ones; a balance check shows the checked balance instead of the asserted amount; every `balance … with pad` shows an extra "Balance Check" row | summary 404; errors 404; #718 item shape; pads emit a pad and a check |
| Transaction detail | OK for transactions; balance-check header has the wrong amount and no failed flag | #718; errors 404 |
| New transaction (record) | works (live test passed); server payee suggestions lost (the app tolerates this; history-based suggestions remain) | `GET /api/for-new-transaction` → 404 |
| Accounts tree | works; numbers changed (latest price, BTC now valued) | valuation fixes #459/#666 |
| Account detail | header and postings OK (postings now include sub-accounts); **balance chart shows an error** | `GET /api/accounts/{a}/balances` → 405 |
| Reports | **broken except the trend**: graph OK; KPIs and the category breakdown / drill-down fail | summary 404, `GET /api/statistic/{type}` → 404 |
| Budgets, documents (repositories only, no screens yet) | broken | `/api/budgets*`, `GET /api/documents`, `GET /api/accounts/{a}/documents` gone |

Checks run:

* `flutter test`: **257/257 passed**. These tests use the old fixtures and fake adapters and never call a server, so
  they cannot catch any of the breakage. The fixtures in `test/fixtures/` now describe a server that no longer exists.
* Live tests on the "iPhone 17 Pro" simulator against v0.2: **2 of 4 pass**. Onboarding and add-transaction pass.
  Browse fails at the Home summary card. Accounts/reports fails at the account balance chart. Details are in the
  "Live test results" section below.

Good news: most server bugs the app works around are fixed (see §f). Basic auth still works on every route.

### Live test results (v0.2, simulator `C72765EE…` "iPhone 17 Pro", iOS 26.5)

| Test | Command (`-d C72765EE-0200-4184-98B4-677679E629EB`) | Result |
|---|---|---|
| `onboarding_live_test` | `--dart-define=ZHANG_URL=http://127.0.0.1:18071` (Basic `demo:secret`) | **PASS** (`00:09 +1: All tests passed!`). Wrong password gives `Authentication failed (401). Check your credentials.`; the right one gives `Connected to "My Accounting" \| zhang 0.1.0 · built 2026-10-10`. The first run hung on a blank white screen after the Xcode build (the harness never attached, a tooling problem); it was killed and the rerun passed |
| `browse_live_test` | `--dart-define=ZHANG_URL=http://127.0.0.1:18070` | **FAIL** at `browse_live_test.dart:91`: `timed out waiting for Found 0 widgets with key [<'home.summary.expense'>]`. The newest journal row did render first (the `journal.row.<id>` wait at line 89 passed). Cause: `GET /api/statistic/summary` → 404. Journal paging and detail were never reached |
| `add_transaction_live_test` | `--dart-define=ZHANG_URL=http://127.0.0.1:18070 --dart-define=ZHANG_LEDGER_DIR=/tmp/zhang-v2-ledger` | **PASS** (`00:13 +1`). `ZHANG_RESULT journal 2026-10-10 03:37:18.000 "LineA 1791571026272" "integration test" Assets:WeChat -15.5 CNY \| Expenses:PersonalDiet:Lunch 15.5 CNY`; file `data/2026/10.zhang` |
| `accounts_reports_live_test` | `--dart-define=ZHANG_URL=http://127.0.0.1:18070` | **FAIL** at `accounts_reports_live_test.dart:94`: `Found 0 widgets with key [<'accountDetail.balanceChart'>]`. The account tree passed (`ZHANG_RESULT net worth ¥444,482.82`). Cause: `GET /api/accounts/Assets:Paypal/balances` → 405. The Reports part (KPIs need summary, which is 404) was never reached and would fail too |

---

## b) BREAKING changes

Effort: S ≤ ½ day, M ≈ 1–2 days, L > 2 days. "Built-in X" means `POST /api/query/builtins/X` (or one entry of the
batch `POST /api/query/builtins`) with body `{"params":{…}}`. Its answer is `{"data":{"columns":[{name,type}],"rows":[[cell,…]]}}`
(cell encoding in §b.1). Dates in `params` are ledger dates `YYYY-MM-DD`.

| # | Endpoint | Old (966c8c6) | New (3538131d) | App code affected | Fix | Effort | Server commit |
|---|---|---|---|---|---|---|---|
| 1 | `GET /api/statistic/summary?from&to` | 200 `{from,to,balance,liability,income,expense,transaction_number}` | **404** `{"message":"no route GET /api/statistic/summary"}` | `lib/data/repositories/statistic_repository.dart:17-22`, `lib/data/api/endpoints.dart:17`, `lib/data/models/statistic.dart:19-61`; consumers `lib/features/journals/journal_providers.dart:237-240` (`monthSummaryProvider` → `home/home_screen.dart:52,193`, `journals/journals_screen.dart:381`), `lib/features/stats/reports_providers.dart:41` | One batch `POST /api/query/builtins`: `report.net_worth{to,currency}`, `report.liabilities{to,currency}`, `report.flows{from,to,currency}`, `report.transaction_count{from,to}`; `currency` = option `operating_currency`. Map each `units`/`value` inventory to the existing `CalculatedAmount`: `calculated` = sum of the `value` positions in `currency`, `detail` = `units` summed per currency (the same as `frontend/src/utils/report.ts` `calculatedAmount`/`reportSummary`). Income/expense come from the `flows` rows with `type` `Income`/`Expenses`. Keep `StatisticSummary` as the app-side model | M | `79b2b7f5` (#758) |
| 2 | `GET /api/statistic/{type}?from&to` | 200 `{from,to,detail[],top_transactions[]}` | **404** | `statistic_repository.dart:32-37`, `endpoints.dart:30`, `statistic.dart:126-168`; `reports_providers.dart:58` → `stats/widgets/category_breakdown.dart` | Batch `report.account_totals{type,from,to,currency}` + `report.top_postings{type,from,to,currency}`. A totals row is `[account, units, value]` → `AccountAmount`. A top-posting row is `[date,time,timestamp,account,id,payee,narration,units,account_balance,value]` → `AccountJournalEntry(datetime: "${date}T${time}", trx_id: id, inferred_unit: units, account_after: account_balance)`. Top postings are now ranked by value in the operating currency, not by raw number | M | `79b2b7f5` (#758) |
| 3 | `GET /api/errors?page&size` | 200 `Pageable<ErrorEntity>` | **404** | `lib/data/repositories/ledger_repository.dart:25-31`, `endpoints.dart:7`, `lib/data/models/ledger_error.dart`; `journal_providers.dart:243-256` (`ledgerErrorsProvider`, `ledgerErrorIdsProvider`) → `home_screen.dart:54-62`, `journals/widgets/journal_tile.dart:72`, `journals/transaction_detail_screen.dart:82` | Built-in `journals.errors{size,offset}` with `"count_total":true`. A row is `[id,kind,file,line,column,span_start,span_end,source,metas]`, where `metas` is a list of `{key,value}` (it used to be a map) and `total` is the count. New kinds appear (seen: `CommodityNotAllowed`); the enum already maps them to `unknown`. For the "failed check" marker use the item's own `passed` (#9) instead of matching error ids | S | `67986072` (#757) |
| 4 | `GET /api/for-new-transaction` | 200 `{payee[], account_name[]}` | **404** | `lib/data/repositories/journal_repository.dart:108-110`, `endpoints.dart:10`, `lib/data/models/for_new_transaction.dart`, `lib/features/transaction_new/transaction_history.dart:228-231` | `journals.payees{}` (already sorted, no `Balance Check`/`Balance Pad`); `journals.accounts{date,time}` (open at that instant) with `date`/`time` from built-in `ledger.now{}` → `[["2026-10-10","03:21:57"]]` | S | `8f207ef6` (#760) |
| 5 | `GET /api/accounts/{a}/balances` | 200 `{"balance":{"CNY":[{date,balance}]}}` (unsorted) | **405** `{"message":"no route GET /api/accounts/Assets:Paypal/balances: the path takes another method"}` (POST still exists) | `lib/data/repositories/account_repository.dart:37-39`, `endpoints.dart:24`, `lib/data/models/account.dart:147-181`; `features/accounts/accounts_providers.dart:26-31` → `account_detail_screen.dart:44,95` | Built-in `accounts.balance_history{account}`. A row is `[date, currency, {number,currency}]`, sorted by date. Group by `currency` into `AccountBalanceHistory`. It now covers the account **and its sub-accounts** | S | `d69ecade` (#756) |
| 6 | `GET /api/accounts/{a}/documents` | 200 `DocumentEntity[]` | **405** | `account_repository.dart:41-45`, `endpoints.dart:25`, `lib/data/models/document.dart` | Built-in `accounts.documents{account}`. A row is `[date,time,account,path,transaction_id]`. Derive the file name, extension and MIME type from `path` on the client | S | `d69ecade` (#756) |
| 7 | `GET /api/documents` | 200 `DocumentEntity[]` | **404** | `lib/data/repositories/document_repository.dart:16-20`, `endpoints.dart:15`, `document.dart:16-23` (no screen yet) | Built-in `journals.documents{}`, same columns as #6, newest first | S | `d69ecade` (#756) |
| 8 | `GET /api/budgets`, `/api/budgets/{n}`, `/api/budgets/{n}/interval/{y}/{m}` | 200 typed JSON | **404** | `lib/data/repositories/budget_repository.dart:16-51`, `endpoints.dart:19,31-33`, `lib/data/models/budget.dart` (no screen yet) | `budgets.month{month:"YYYY-MM-01"}` → `[name,alias,category,currency,last_month,assigned{number,currency},activity "88.50",available,closed]`; `budgets.budget{name}` (`accounts` set = related accounts; no row = old 404); `budgets.budget_month{name,month}`; `budgets.events{name,month}` → `[date,time,timestamp,type,amount]`, where **type is now `"assign"`**, not `AddAssignedAmount`/`Transfer`; `budgets.postings{name,month}` → `[date,time,timestamp,account,id,payee,narration,units,balance]`. The app merges events and postings newest first | M | `67d04456` (#754) |
| 9 | `GET /api/journals` item `type:"BalanceCheck"` | `postings[0]` = the adjustment the check implied; `unit` = adjustment; `account_after` = **asserted** amount; a failing check reset the running balance | `postings[0]` is a zero entry: `unit:null`, `inferred_unit:"0"`, `account_before` = `account_after` = **checked balance**. New fields: `asserted`, `checked_balance`, `difference`, `tolerance`, `passed`. Checks no longer move balances | `lib/data/models/journal.dart:141-169` (fields not parsed); `journals/widgets/journal_tile.dart:231`, `journals/transaction_text.dart:45`, `journals/transaction_detail_screen.dart:262` show `posting.accountAfter` as the asserted amount (wrong for a failing check: shows 146183 instead of 100) | Parse `asserted`, `checked_balance`, `difference`, `passed`. Display `asserted`; `failed = !passed` | S | `e342b755` (#718), `c94a38ff` (#485) |
| 10 | `GET /api/journals` for `balance … with pad` | one `BalancePad` item | a `BalancePad` item **and** a `BalanceCheck` item at the same datetime (sample ledger: 3 pads + 4 checks; it used to be 3 pads + 1 check) | journal list rows; `journals/journal_grouping.dart`, `classify.dart` | Decide whether to show the check under its pad (UX only) | S | #438, #508 (pad/check pipeline) |
| 11 | `GET /api/accounts/{a}/journals` | all postings of exactly that account; `trx_id` = **posting** id; unknown → `[]`; invalid → 500; check rows had `inferred_unit` = adjustment | Rows of the account **and its sub-accounts** (the `account` field names the sub-account); `trx_id` = **transaction id** (matches `/api/journals`); unknown → **404**, invalid → **400**; assertion rows have `inferred_unit:"0"` plus `asserted`, `checked_balance`, `difference`, `tolerance`, `passed`; optional `page`/`size` with an `X-Total-Count` header (no params = everything) | `account_repository.dart:30-35`, `account.dart:98-145`; `account_detail_screen.dart:260,315` (a check row now shows `0`) | Parse the assertion fields and show `asserted`; label the sub-account on a row; treat 404 as "no postings" for virtual parents. Optional: paginate | S | `fcd91984` (#513), `e342b755` (#718), `ecdec53b` (#713) |
| 12 | `GET /api/statistic/graph` | `from`/`to` echoed as naive **UTC**; `balances` keyed by **UTC** date (an extra day for UTC+ clients); `interval` ignored | `from`/`to` echoed as naive **ledger-local** (`2023-09-01T00:00:00`…`2023-09-05T23:59:59`); keys are ledger dates; `interval` honoured (`Week`/`Month` buckets keyed by the bucket's first day, can reach outside the range); `from`/`to` may be `YYYY-MM-DD` (instants still accepted) | `lib/data/models/statistic.dart:93-94` (`parseNaiveUtc` is now wrong; the UI does not use the value); `statistic_repository.dart:24-30,39-42` | Parse `from`/`to` with `parseNaive`; send ledger dates `YYYY-MM-DD` | S | `06cd7f23` (#720), `afdebe8f` (#504) |
| 13 | Error responses | mixed: JSON `{message,origin}`, plain text, empty; 401 empty + `www-authenticate: Basic`; unknown `/api` path → 200 text | **always** `{"message": …}` (`origin` removed); 401 `{"message":"unauthorized"}`, no `WWW-Authenticate`; unknown `/api` path **404** `no route GET /api/x`; wrong method **405** JSON; PUT with an unknown transaction id **404** (was 400); invalid account name **400** (was 500); file changed / reload failed **409**; outside the ledger **403**; bad `Content-Type` 415 JSON | `lib/data/api/zhang_api_client.dart:177-232` (works); `lib/data/api/api_exception.dart:28-46` (doc comments); `core/widgets/error_view.dart` | Works as is. Recommended: map a 404 whose message starts with `no route ` to a "server API version mismatch" message instead of a generic "not found" | S | `9ad36b08` (#715), `13de1273` (#755) |
| 14 | Writes (`POST`/`PUT /api/transactions`, balances, uploads) | anything was written, even names that do not parse | Names the ledger would not read back are refused with **400** (verified: tag `"two words"` → `invalid tag "two words": it cannot be empty or contain a space…`; account `Foo:Bar` → 400). Beancount ledgers also refuse new names that beancount rejects. Unbalanced transactions and unknown or closed accounts are **still written** (they show up in `journals.errors`) | `lib/features/transaction_new/new_transaction_screen.dart:246` error surfacing; tag sanitising from `11dea33` | Show the server's `message` on a 400; better, call preview first (§e) | S | `5b475510` (#457), `5bc87438` (#710) |
| 15 | Paging (`/api/journals`, account journals) | `size=0` crashed; `page=0` → 1 | `page` ≥ 1 and `size` 1–1000, else **400** `size must be between 1 and 1000` / `page must be at least 1` | `journal_repository.dart:52` (clamps to ≥1; the `size: 500` history fetch is fine) | Also clamp to ≤ 1000 | S | `ecdec53b` (#713) |
| 16 | Valuation of `calculated` (accounts, graph, every report figure) | earliest price; only direct `X→operating` prices; BTC priced in USD = 0 | latest price on or before the date, inverse prices, cost currency (verified: `Liabilities:CreditCard:Apple` −474.229 → **−476.1775** = −382 − 12.99×7.25; `Assets:Crypto` 0 → **1885.0000**) | No code break. Test expectations, `amount.dart:49-51` doc and `docs/zhang-api.md` §1.4 are now wrong | Update docs/tests | S | `678d8e97` (#459), `f4815031` (#666) |

Non-breaking shape changes (verified, the app ignores them safely): `/api/info` +`format`, +`reload_failure`;
posting +`metas`, +`written{cost,price,comment}`; transaction +`edit_drops_text`; accounts +`amount_with_sub_accounts`,
+`balance_with_sub_accounts`, +`has_sub_accounts` (list now sorted by name); commodity lots are now only Assets and
Liabilities lots (the Expenses lot is gone), +optional `label`; option `directive_output_path` is now
`data/{{year}}/{{month_str}}.{{ext}}`; `sequence` is no longer contiguous (`max 236` for 206 items); balance POSTs
answer `200 {"data":{"replaced":[]}}` instead of `201` empty (`ZhangApiClient.send` accepts both); `POST /api/reload`
now waits for the reload and answers `409` on failure.

### b.1 Built-in query cell encoding (needed by fixes 1–8)

From `zhang-server/src/response.rs` `QueryCell` (verified in the curl output in Appendix A):

| Column type | JSON |
|---|---|
| `int`, `bool` | JSON number / boolean |
| `decimal`, `str`, `date` (`YYYY-MM-DD`), `interval` | string (decimals in plain notation) |
| `set` | sorted string array |
| `amount` | `{"number":"-12.50","currency":"USD"}` (**`currency`**, not `commodity`) |
| `position` | `{"units":amount,"cost":{"number","currency","date","label"}\|null}` |
| `inventory` | `{"positions":[position…]}` |
| `metas` | `[{"key","value"}…]` |
| any | `null` |

Errors: unknown query → 404 `there is no built-in query nope.nope`; a missing or mistyped parameter → 400
`parameter :to of report.flows is missing` or `parameter :from must be a date string YYYY-MM-DD or null`.
`GET /api/query/builtins` lists all 39 queries with their params and columns. The authoritative reference is zhang
`docs/src/content/docs/reference/builtin-queries.md`, section "Retired endpoints".

---

## c) Unchanged / compatible (verified with curl against v0.2 and by the passing live tests)

| Endpoint | Verdict | Notes |
|---|---|---|
| `GET /api/info` | compatible | +`format`, +`reload_failure` |
| `GET /api/options` | compatible | |
| `POST /api/reload` | compatible | now synchronous: `200 {"data":"Ok"}` or `409` with the reason |
| `GET /api/sse` | compatible | +event `{"type":"ReloadFailed","file":…,"message":…}`; `Connected`/`Reload`/`NewVersionFound` unchanged |
| `GET /api/journals` | compatible except #9/#10 | same envelope and `Pageable`; keyword search verified (`Supermarket` 1, `SUPERMARKET` 1, `隆江` 34); `tags[0]=`/`tags[]=` work; **percent-encoded brackets are still silently ignored** (206 = unfiltered); `tags=x` → 400 JSON |
| `POST /api/transactions` | compatible | the app's exact body (UTC `Z` datetime, `narration`, `"*"`, `unit:null`, `metas`/`tags`/`links`) → `200 {"data":"Ok"}`; the transaction was visible ~200 ms later; it was written as `2026-10-02 18:30:00 * "Mobile Test Cafe" "Flat white" #mobile ^order-42` (metadata now written right under the header). Live test passed |
| `PUT /api/transactions/{id}` | compatible (better) | `200 {"data":null}`. A posting sent without `cost`/`price`/`comment` keys **keeps** them (verified: `{ 26000 USD }` survived an app-shaped PUT) |
| `POST /api/transactions/{id}/documents` | compatible | `200 {"data":"Ok"}`; non-UUID → 400 (was a crash) |
| `GET /api/accounts` | compatible | +3 fields, sorted |
| `GET /api/accounts/{name}` | compatible | `:` raw or `%3A` both work; unknown → 404; invalid → 400 |
| `GET /api/accounts/{name}/journals` | compatible shape, changed meaning (#11) | |
| `POST /api/accounts/{name}/balances`, `POST /api/accounts/batch-balances` | compatible | 200 JSON instead of 201 empty; invalid account → 400; `"type":"check"` → 422 JSON |
| `GET /api/documents/{b64}` | compatible (better) | base64 with `/` works raw or as `%2F`; missing → 404 JSON (was 200 empty and cached) |
| `GET /api/commodities`, `GET /api/commodities/{name}` | compatible (better) | unknown → 404 (was a crash) |
| `GET /api/statistic/graph` | compatible with caveats (#12) | |
| HTTP Basic auth | compatible | see §d |

---

## d) Auth: the v0.2 flow a mobile client must implement

Source: commit `e3b4d6b3` (#466), `zhang-server/src/auth/*.rs`, zhang `docs/…/deployment/authentication.md`.
Two methods can be enabled side by side: **password** (`--auth user:pass` / `ZHANG_AUTH`) and **passkey**
(`--passkey <registration-secret>` / `ZHANG_PASSKEY`). When either is on, every `/api/*` route except `/api/auth/*`
and CORS `OPTIONS` requires a valid `zhang_session` cookie **or** a valid `Authorization: Basic` header.

**Verdict: the app's Basic-only implementation still works**, on every route including `/api/sse`, whenever the
server has the password method on (the normal `ZHANG_AUTH` setup). It does **not** work on a passkey-only server
(`ZHANG_PASSKEY` without `ZHANG_AUTH`): Basic is refused there, and a third-party mobile app cannot realistically run
WebAuthn for an arbitrary self-hosted relying-party domain (iOS associated domains and Android asset links would have
to list the user's own domain).

Verified (server `--auth demo:secret` on :18071):

```
$ curl -s -w ' %{http_code}' http://127.0.0.1:18071/api/info                       → {"message":"unauthorized"} 401   (application/json, no WWW-Authenticate)
$ curl -s -u demo:wrong   …/api/info                                               → {"message":"unauthorized"} 401
$ curl -s -u demo:secret  …/api/info                                               → {"data":{"title":"My Accounting",…,"format":"zhang","reload_failure":null}} 200
$ curl -H "Authorization: basic $(printf demo:secret|base64)" …/api/info           → 200   (scheme is now case-insensitive; was 401)
$ curl -H 'Authorization: Bearer abc' …/api/info                                   → 401
$ curl --max-time 2 …/api/sse                                                      → 401 {"message":"unauthorized"}
$ curl …/api/auth/status                                                           → 200 {"data":{"enabled":true,"authenticated":false,"methods":{"password":true,"passkey":false},"passkey_registered":false,"user":null,"title":"My Accounting"}}
$ curl -u demo:secret …/api/auth/status                                            → 200 {…"authenticated":true,…,"user":"demo",…}
$ curl -d '{"username":"demo","password":"nope"}'   -H 'Content-Type: application/json' …/api/auth/login → 401 {"message":"invalid username or password"}
$ curl -d '{"username":"demo","password":"secret"}' -H 'Content-Type: application/json' …/api/auth/login → 200 + set-cookie: zhang_session=eyJzdWIiOiJkZW1vIiwiZXhwIjoxNzk0MTYyMDA2LCJwdyI6…; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000
$ curl -b jar …/api/info                                                           → 200
$ curl -H "Cookie: zhang_session=<token>" …/api/accounts/Assets:WeChat             → 200
$ curl -H 'Cookie: zhang_session=abc.def' …/api/info                               → 401
$ curl -X POST -b jar …/api/auth/logout                                            → 200 + set-cookie: zhang_session=; …; Max-Age=0
$ curl -H "Cookie: zhang_session=<token from before logout>" …/api/info            → 200   (logout only clears the cookie; the token stays valid until exp)
$ 5× wrong /api/auth/login, then the 6th                                            → 429 {"message":"too many attempts, try again in 15 minutes"}, retry-after: 900
$ correct /api/auth/login while limited                                             → 429
$ curl -u demo:secret …/api/info while login is limited                            → 200   (Basic is not rate-limited; 7 wrong Basic attempts in a row → 401 each, never 429)
$ restart (no ZHANG_SESSION_SECRET), old cookie                                     → 401
$ restart with the same ZHANG_SESSION_SECRET=s3ss10n, old cookie                    → 200
$ --auth nocolon:   …/api/info → 200 without creds; /api/auth/status → {"enabled":false,"authenticated":true,…}   (still silently disabled)
$ --passkey regsecret (no --auth): status → {"enabled":true,"methods":{"password":false,"passkey":true},…}; -u demo:secret → 401; /api/auth/login → 400 {"message":"password login is not enabled"}; /api/auth/passkey/login/start → 400 {"message":"no passkey is registered"}
$ --auth demo:secret --passkey regsecret: passkey/register/start via http://127.0.0.1 → 400 "…the relying party id `127.0.0.1` must be a domain name (or localhost)…"; via localhost → 200 {"data":{"state_id":"…","options":{"publicKey":{…}}}}
$ curl …/openapi.json (no creds) → 200 (still unprotected)
```

### Spec for the app

1. **Discovery (new, recommended):** `GET /api/auth/status` (no auth needed) → `{enabled, authenticated,
   methods:{password, passkey}, passkey_registered, user, title}`. Onboarding can then show the username/password
   fields only when `methods.password`. When `enabled && !methods.password`, show "this server only allows passkey
   sign-in; enable ZHANG_AUTH for the mobile app". An old server answers `200 text/plain` here, which the client
   already turns into `ApiParseError`.
2. **Option A: keep HTTP Basic (no change required).** Send `Authorization: Basic base64(user:pass)` on every
   request. Failure: `401` + `{"message":"unauthorized"}` (JSON, no `WWW-Authenticate`). It is not rate-limited, and
   no session or expiry handling is needed.
3. **Option B: session cookie.** It does not save storing the password, because the app has to re-login after
   expiry or a server restart.
   * `POST /api/auth/login` `{"username","password"}` (JSON) → `200 {"data":AuthStatus}` + `Set-Cookie: zhang_session=<claims>.<sig>;
     Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000` (+`; Secure` when `X-Forwarded-Proto: https`). Errors: 401
     `invalid username or password`, 400 `password login is not enabled`, **429** + `Retry-After` after 5 failures per
     client IP (50 globally) in 15 min.
   * Send `Cookie: zhang_session=<token>` on every `/api/*` request (dio: a cookie jar or a header interceptor).
   * Expiry: 30 days from login, no refresh endpoint (log in again). Sessions also end when the server restarts
     without `ZHANG_SESSION_SECRET`, or when `ZHANG_AUTH` changes. Any `401` → log in again with the stored
     credentials, else ask the user.
   * `POST /api/auth/logout` only returns an expiring cookie. The token itself stays valid until `exp` (stateless HMAC).
4. **Passkeys:** `POST /api/auth/passkey/login/start` → `{state_id, options}` (WebAuthn `PublicKeyCredentialRequestOptions`),
   then `POST /api/auth/passkey/login/finish` `{state_id, credential}` → cookie. The RP id is the request host (must be
   a domain or localhost, HTTPS in browsers) or `ZHANG_PASSKEY_RP_ID`/`ZHANG_PASSKEY_ORIGIN`. **Not recommended for
   the app**; out of scope for the MVP.
5. Custom headers / Bearer (reverse proxy) profiles are unaffected. The server ignores `Bearer`, so a gateway must
   strip it or the server must have auth off.

Code: no change is needed in `lib/data/profiles/server_profile.dart:159-177` / `lib/data/api/auth_interceptor.dart`.
Update the comments `server_profile.dart:167` ("case-sensitive") and `api_exception.dart:28-29`
("empty body with www-authenticate"), which are now stale.

---

## e) New capabilities to adopt (prioritized)

| Pri | Capability | API | What it gives the app | Commit |
|---|---|---|---|---|
| P0 | **Built-in queries over HTTP** | `POST /api/query/builtins/{name}`, batch `POST /api/query/builtins` (one consistent read), `GET /api/query/builtins` | Required to fix #1–#8. The batch call gives Home/Reports figures from one ledger read | `e0a917b2` (#753) |
| P1 | **Balance-assertion fields** | `asserted`, `checked_balance`, `difference`, `tolerance`, `passed` on journal and account-journal rows | Correct amount and failed/passed state without fetching the error list | `e342b755` (#718) |
| P1 | **Transaction preview** | `POST /api/transactions/preview`, `POST /api/transactions/{id}/preview` → `{text, field_errors[{posting,field,kind,value,message}], unbalanced[Amount]\|null, errors[{error_type,metas}]}` | Validate before saving: show "unbalanced by …", unknown or closed account (`AccountDoesNotExist`), invalid tag, and the exact ledger text. Verified: unopened account → `errors:[{"error_type":"AccountDoesNotExist",…}]`; `Foo:Bar` → `field_errors[{kind:"invalid_account",…}]` | `5bc87438` (#710) |
| P1 | **Ledger wall-clock datetimes in requests** | `datetime: "2026-10-03T09:30:00"` (no offset) is read as the ledger's wall clock | Send `ZhangDates.toNaiveIso(tx.datetime)` on edit instead of the device-tz→UTC round trip. That fixes the time shift on edit when the device tz differs from the ledger tz (the web UI had the same bug) | `d68c0b42` (#726) |
| P1 | **`ledger.now`** | built-in `ledger.now{}` → `[date, time]` in the ledger tz | Default date for new entries and "current month" by the ledger's clock (known-issues P1 "月份/期间按设备时区计算") | `8f207ef6` (#760) |
| P1 | **Reload signalling** | SSE `Reload` / `ReloadFailed{file,message}`; `/api/info.reload_failure`; synchronous `POST /api/reload` (409 on failure) | Replace the fixed 600 ms refresh (known-issues #1) and warn when a write broke the ledger | `a66ca801` (#672) |
| P1 | **Real transaction id in account journals** | `trx_id` = transaction id | Tap a posting on the account page to open the transaction (remove the payee-search workaround) | `fcd91984` (#513) |
| P2 | **Posting cost / price / comment / metadata writes; text units** | posting `cost:"{150 USD}"`, `price:"@ 6 USD"`, `comment`, `metas[]`; `unit` may be a text such as `"-(10 + 2) / 4 CNY"` (verified → `-3 CNY`) | Cross-currency entries (decisions.md gap "posting 不支持 cost / price"); the keypad expression could be sent as is | `e1bc6fe0` (#471), `e6bbb2d8` (#671) |
| P2 | Server-side tag/link filter | built-in `journals.page{keyword,tags:[…],links:[…],size,offset}` (+`journals.postings{ids}`, `journals.balance_checks{ids}`) | Removes the client-side tag filter (Dart re-encodes `[]`), with a correct `total_count` | `b87e7470` (#512) |
| P2 | Arbitrary BQL | `POST /api/query {"query","count_total"}`, `postings.between{from,to}`, `accounts.journal_page` | Date or account filters the typed API lacks (decisions.md gap) | `4458d480` (#439), `79b5c7b0` (#450) |
| P2 | Account journal paging | `?page&size` + `X-Total-Count` | Big accounts without loading everything | `ecdec53b` (#713) |
| P2 | Sub-account totals | `amount_with_sub_accounts`, `balance_with_sub_accounts`, `has_sub_accounts` | Account tree totals straight from the server | #513 |
| P2 | Graph buckets | `interval=Week\|Month` now honoured | Year view of the Reports trend without client-side bucketing | #504 |
| P3 | `edit_drops_text` | per transaction | Warn before an edit that would drop comments | #727 |
| — | Still **absent** | `DELETE /api/transactions/{id}` → **405** `no route DELETE …`; `POST /api/transactions` still answers `{"data":"Ok"}` with **no id**; no idempotency key; no budget writes | Keep these in decisions.md as upstream gaps | — |

---

## f) Server bugs fixed: workarounds that can go

| Old bug (zhang-api.md §5) | v0.2 status (verified) | App workaround to simplify | Commit |
|---|---|---|---|
| `size=0` crashes `/api/journals` and `/api/errors` | 400 `size must be between 1 and 1000` | the clamp can stay; add an upper bound of 1000 (`journal_repository.dart:52`, `ledger_repository.dart:29`) | `ecdec53b` (#713) |
| `calculated` used the **earliest** price | latest on or before the date (USD 7.25 used) | `amount.dart:49-51` comment; zhang-api.md §1.4 advice to convert client-side | `678d8e97` (#459) |
| commodities without a direct price counted 0 | inverse prices and cost currency (BTC 0.01 → 1885.0000 CNY) | known-issues "calculated may be 0" note | `f4815031` (#666) |
| exponent notation (`"1E-8"`) | plain notation everywhere; `0.00000001 BTC` is read and written plainly; no `E±` string in accounts/journals/commodities | keep the lenient parser (harmless); drop the synthetic exponent fixture once fixtures are recaptured | `74a9f03b` (#695) |
| unknown `/api/*` path → `200 text/plain` | 404 JSON `no route GET /api/nope` | keep `unwrapEnvelope`'s text check (it still guards non-zhang URLs) | `13de1273` (#755) |
| account-journal `trx_id` is a posting id | real transaction id | `account.dart:102-104`, `account_repository.dart:31` comments; payee-search workaround | `fcd91984` (#513) |
| base64 path containing `/` cannot be downloaded | works raw and `%2F` (verified with `attachments/丿.txt` → `YXR0YWNobWVudHMv5Li/LnR4dA==`) | `document.dart:43-44` `isDownloadable`, `document_repository.dart:26-28` | `a0155a25` (#507) |
| missing document → 200 empty, cached forever | 404 `the document attachments/nope.txt does not exist`; outside the ledger → 403 | none (good) | #507 / #715 |
| unknown `/api/commodities/{name}` crashes | 404 `not found` | `commodity_repository.dart:20-21`, `commodity.dart:111-112` comments | #503 |
| budget interval month 13 crashes | endpoint gone; built-ins take a date | `budget_repository.dart:48-51` `_checkMonth` goes with the rewrite | #754 |
| `for-new-transaction` payees include `Balance Check`/`Balance Pad`, unordered | `journals.payees` excludes them and is sorted | `for_new_transaction.dart:7-18` | #760 |
| summary `transaction_number` counted balance items | `report.transaction_count` excludes pads (`flag P`) and assertions | `statistic.dart:59` comment | #758 |
| graph ignored `interval`; UTC day keys | honoured; ledger-date keys | `statistic.dart:6-7,65-67` comments | #504, #720 |
| rank compared raw numbers across currencies | ranked by value in the operating currency (12.99 USD = 94.18 CNY ranks above 88.50 CNY) | none | #758 |
| PUT dropped cost/price/comment | kept when the keys are omitted | `transaction_request.dart:47-49` caveat | `e6bbb2d8` (#671) |
| failed balance check reset the running balance | assertions never move balances | `zhang-api.md` §3.3 note | `c94a38ff` (#485) |
| multipart part without filename / non-UUID upload id crashes | 400 JSON | none | #715 and the upload extractor |
| reload failures silent | `409` on `POST /api/reload`, `/api/info.reload_failure`, SSE `ReloadFailed` | known-issues #1 | `a66ca801` (#672) |
| Basic scheme case-sensitive | case-insensitive | `server_profile.dart:167` comment | #466 |
| editing a plugin-generated transaction corrupted files | 400 "generated by a plugin and can't be edited" | none | `62ca5c88` (#664) |
| **Not fixed:** percent-encoded `tags%5B0%5D=` silently ignored on `GET /api/journals` | still ignored (206 = unfiltered) | keep the client-side filter, or move to `journals.page` (§e) | — |
| **Not fixed:** `--auth` without `:` silently disables auth | still disabled | none (server-side) | — |
| **Not fixed:** unbalanced transactions and unknown accounts are still written | still written; preview reports them | use preview | — |

---

## g) Recommended fix order

1. **Version gate + built-in query client (S–M).** Add a `BuiltinQueryClient` (`run(name, params, {countTotal})`,
   `runBatch([...])`) and a typed `QueryCell` decoder (amount `{number,currency}`, position, inventory, metas, set).
   Detect the v0.2 API by the presence of `format` in `GET /api/info`. Old servers lack it; the version string cannot
   be used because source builds report `0.1.0`. Decide early: support only v0.2 (recommended; the typed endpoints are
   not coming back, and their retirement is documented as one group per release), or keep both code paths behind the
   gate.
2. **Summary via `report.*` (M).** This unblocks the Home summary card, the Journal month headers and the Reports KPIs
   (and the browse live test).
3. **Account balance history via `accounts.balance_history` (S).** This unblocks the account-detail chart (and the
   accounts live test, up to the Reports part).
4. **Rank via `report.account_totals` + `report.top_postings` (M).** Restores the Reports breakdown and drill-down.
5. **Balance assertions (S):** parse `asserted`/`passed`, fix `journal_tile.dart:231`, `transaction_text.dart:45`,
   `transaction_detail_screen.dart:262`, `account_detail_screen.dart:315`; drop the error-id matching in
   `ledgerErrorIdsProvider`.
6. **Errors via `journals.errors` (S)** for the Home chip (count = `total`).
7. **Form data via `journals.payees`, `journals.accounts`, `ledger.now` (S).**
8. **Tests and docs (S–M):** recapture `test/fixtures/*.json` from a v0.2 server (built-in rows included); update the
   live tests (they hard-code the summary/chart expectations); rewrite `docs/zhang-api.md` for v0.2 (or point it at
   this file and the upstream built-in reference); fix the stale comments listed in §d and §f; fix
   `statistic.dart:93-94` (graph `from`/`to` are now ledger-local).
9. **Adopt the P1 capabilities (§e):** SSE `Reload`/`ReloadFailed` instead of the 600 ms timer; preview before save;
   wall-clock datetimes on edit; `ledger.now` for "today"; transaction tap-through from the account journal;
   `/api/auth/status` in onboarding.
10. **When the budgets/documents screens are built**, implement them directly on `budgets.*` and
    `journals.documents`/`accounts.documents` (the current repositories for them are dead code against v0.2).

Rough total to get back to parity on v0.2: about 4–6 dev-days (items 1–8), plus 2–3 days for the P1 adoptions.

---

## Appendix A: curl transcripts (v0.2, trimmed)

Helper used for every capture: `curl -s -D headers -o body -w '%{http_code}' <args>`, printing
`### <label> -> HTTP <status> [<content-type>] <x-total-count/set-cookie/retry-after/content-disposition>` and the
first bytes of the body. `B=http://127.0.0.1:18070` (no auth), `A=http://127.0.0.1:18071` (`demo:secret`).
Auth transcripts are in §d.

### A.1 Removed endpoints the app calls

```
$ curl "$B/api/errors?page=1&size=100"                     ### -> HTTP 404 [application/json] {"message":"no route GET /api/errors"}
$ curl $B/api/for-new-transaction                          ### -> HTTP 404 {"message":"no route GET /api/for-new-transaction"}
$ curl $B/api/documents                                    ### -> HTTP 404 {"message":"no route GET /api/documents"}
$ curl $B/api/accounts/Assets:Paypal/documents             ### -> HTTP 405 {"message":"no route GET /api/accounts/Assets:Paypal/documents: the path takes another method"}
$ curl $B/api/accounts/Assets:Paypal/balances              ### -> HTTP 405 {"message":"no route GET /api/accounts/Assets:Paypal/balances: the path takes another method"}
$ curl "$B/api/statistic/summary?from=2023-09-01T00:00:00%2B09:00&to=2023-09-30T23:59:59%2B09:00"  ### -> HTTP 404 {"message":"no route GET /api/statistic/summary"}
$ curl "$B/api/statistic/Expenses?from=…&to=…"             ### -> HTTP 404 {"message":"no route GET /api/statistic/Expenses"}
$ curl "$B/api/budgets?year=2023&month=9"                  ### -> HTTP 404 {"message":"no route GET /api/budgets"}
$ curl "$B/api/budgets/food?year=2023&month=9"             ### -> HTTP 404 {"message":"no route GET /api/budgets/food"}
$ curl $B/api/budgets/food/interval/2023/9                 ### -> HTTP 404 {"message":"no route GET /api/budgets/food/interval/2023/9"}
$ curl $B/api/store                                        ### -> HTTP 404 {"message":"no route GET /api/store"}            (not used by the app)
$ curl -d '{"sql":"select 1"}' $B/api/sql                  ### -> HTTP 404 {"message":"no route POST /api/sql"}             (not used; replaced by POST /api/query)
$ curl $B/api/nope                                         ### -> HTTP 404 {"message":"no route GET /api/nope"}
$ curl $B/hello                                            ### -> HTTP 200 [text/plain] hello zhang, seems you are trying to access the frontend UI…
$ curl -X PUT $B/api/info                                  ### -> HTTP 405 {"message":"no route PUT /api/info: the path takes another method"}
$ curl -X DELETE $B/api/transactions/846d80bc-…            ### -> HTTP 405 {"message":"no route DELETE /api/transactions/846d80bc-6824-8b70-4196-825346014589: the path takes another method"}
```

### A.2 Common

```
$ curl $B/api/info
{"data":{"title":"My Accounting","version":"0.1.0","build_date":"2026-10-10","format":"zhang","reload_failure":null}}

$ curl $B/api/options
{"data":[{"key":"default_commodity_precision","value":"2"},{"key":"operating_currency","value":"CNY"},{"key":"default_rounding","value":"RoundDown"},
 {"key":"default_balance_tolerance_precision","value":"2"},{"key":"default_booking_method","value":"FIFO"},
 {"key":"directive_output_path","value":"data/{{year}}/{{month_str}}.{{ext}}"},{"key":"title","value":"My Accounting"},{"key":"timezone","value":"Asia/Tokyo"}]}

$ curl -X POST $B/api/reload                               ### -> HTTP 200 {"data":"Ok"}
# with a syntax error appended to data/2023/12.zhang:
$ curl -X POST $B/api/reload                               ### -> HTTP 409 {"message":"the ledger failed to reload, so the version loaded before is still shown. Fix the files in the file editor: cannot parse data/2023/12.zhang: failed to parse zhang file: unexpected input at line 44, column 1"}
$ curl $B/api/info  → {"data":{…,"reload_failure":{"file":"data/2023/12.zhang","message":"cannot parse data/2023/12.zhang: failed to parse zhang file: unexpected input at line 44, column 1"}}}

$ curl -N --max-time 6 $B/api/sse     (during a balance check POST + a batch POST)
data: {"type":"Connected"}

data: {"type":"Reload"}

data: {"type":"Reload"}
…
$ curl -N --max-time 5 $B/api/sse     (broken file, reload, fixed file, reload)
data: {"type":"Connected"}

data: {"type":"ReloadFailed","file":"data/2023/12.zhang","message":"cannot parse data/2023/12.zhang: failed to parse zhang file: unexpected input at line 44, column 1"}

data: {"type":"Reload"}
```

### A.3 Journals

```
$ curl "$B/api/journals?page=1&size=3"
{"data":{"total_count":206,"total_page":69,"page_size":3,"current_page":1,"records":[
 {"type":"Transaction","id":"0a25388b-66a0-cf83-c510-0411ccff76d9","sequence":236,"datetime":"2023-09-16T21:56:16","payee":"隆江猪脚饭",
  "narration":"Eating Dinner","tags":[],"links":[],"flag":"*","is_balanced":true,"postings":[
   {"account":"Assets:CitiBank:9999","unit":{"number":"-21","commodity":"CNY"},"cost":null,"inferred_unit":{"number":"-21","commodity":"CNY"},
    "account_before":{"number":"164469.50","commodity":"CNY"},"account_after":{"number":"164448.50","commodity":"CNY"},
    "metas":[],"written":{"cost":null,"price":null,"comment":null}},
   {"account":"Expenses:PersonalDiet:Lunch","unit":null,"cost":null,"inferred_unit":{"number":"21","commodity":"CNY"},
    "account_before":{"number":"1182","commodity":"CNY"},"account_after":{"number":"1203","commodity":"CNY"},
    "metas":[],"written":{"cost":null,"price":null,"comment":null}}],
  "metas":[],"edit_drops_text":false}, …2 more…]}}

$ curl "$B/api/journals?keyword=Supermarket"     (posting metadata + comment, transaction metadata)
{"data":{"total_count":1,…,"records":[{"type":"Transaction","id":"3bcdbf6a-ae47-0f9d-679a-3c4257b87b17","sequence":201,"datetime":"2023-09-03T12:30:00",
 "payee":"Supermarket","narration":"Weekly groceries","tags":["weekly"],"links":["receipt-001"],"flag":"*","is_balanced":true,"postings":[
  {"account":"Assets:CitiBank:9999","unit":{"number":"-88.50","commodity":"CNY"},…,"metas":[],"written":{"cost":null,"price":null,"comment":null}},
  {"account":"Expenses:Groceries","unit":{"number":"88.50","commodity":"CNY"},"cost":null,"inferred_unit":{"number":"88.50","commodity":"CNY"},
   "account_before":{"number":"0.00","commodity":"CNY"},"account_after":{"number":"88.50","commodity":"CNY"},
   "metas":[{"key":"category","value":"food"}],"written":{"cost":null,"price":null,"comment":"paid by card"}}],
 "metas":[{"key":"receipt_no","value":"A-1"}],"edit_drops_text":false}]}}

$ curl "$B/api/journals?keyword=Buy&size=5"      (price and cost postings)
… {"account":"Assets:Paypal","unit":{"number":"10","commodity":"USD"},"cost":null,…,"written":{"cost":null,"price":"@ 7.2 CNY","comment":null}}
… {"account":"Assets:Crypto","unit":{"number":"0.01","commodity":"BTC"},"cost":{"number":"26000","commodity":"USD"},"inferred_unit":{"number":"0.01","commodity":"BTC"},
   "account_before":{"number":"0.00","commodity":"BTC"},"account_after":{"number":"0.01","commodity":"BTC"},"metas":[],"written":{"cost":"{ 26000 USD }","price":null,"comment":null}}

$ curl "$B/api/journals?keyword=Balance%20Check&size=2"    (failing and passing assertion)
{"type":"BalanceCheck","id":"cf93fca3-c552-b3e5-6e86-64b5e8f778ab","sequence":220,"datetime":"2023-09-10T23:00:00","payee":"Balance Check","narration":"Assets:WeChat","type_":"C",
 "postings":[{"account":"Assets:WeChat","unit":null,"cost":null,"inferred_unit":{"number":"0","commodity":"CNY"},
   "account_before":{"number":"146183","commodity":"CNY"},"account_after":{"number":"146183","commodity":"CNY"},"metas":[],"written":null}],
 "asserted":{"number":"100","commodity":"CNY"},"checked_balance":{"number":"146183","commodity":"CNY"},"difference":{"number":"-146083","commodity":"CNY"},"tolerance":null,"passed":false}
{"type":"BalanceCheck","id":"d1972649-2e84-117b-5cb8-6d93ac4573a3","sequence":30,"datetime":"2023-05-31T01:01:01",…,"narration":"Assets:CitiBank:9999",…,
 "asserted":{"number":"158059","commodity":"CNY"},"checked_balance":{"number":"158059","commodity":"CNY"},"difference":{"number":"0","commodity":"CNY"},"tolerance":null,"passed":true}

BalancePad item (from ?size=1000; type counts: Transaction 199, BalanceCheck 4, BalancePad 3; sequence strictly descending, max 236 min 25):
{"type":"BalancePad","id":"8c2704fe-ef7a-272c-2286-b757719ae95c","sequence":27,"datetime":"2023-05-31T01:01:01","payee":"Balance Pad",
 "narration":"pad Assets:CitiBank:9999 to Equity:OpenBalancing","type_":"P","postings":[
  {"account":"Assets:CitiBank:9999","unit":{"number":"158059","commodity":"CNY"},…,"account_before":{"number":"0",…},"account_after":{"number":"158059",…},"metas":[],"written":{…}},
  {"account":"Equity:OpenBalancing","unit":null,…,"inferred_unit":{"number":"-158059","commodity":"CNY"},…}]}

Filters and paging:
tags[0]=weekly -> 1     tags[]=weekly -> 1     tags%5B0%5D=weekly -> 206 (ignored)     tags%5B%5D=weekly -> 206 (ignored)
links[0]=receipt-001 -> 1     keyword=SUPERMARKET -> 1     keyword=%E9%9A%86%E6%B1%9F -> 34
### tags=weekly -> HTTP 400 {"message":"the query string cannot be read: invalid type: string \"weekly\", expected a sequence"}
### size=0      -> HTTP 400 {"message":"size must be between 1 and 1000"}
### page=0      -> HTTP 400 {"message":"page must be at least 1"}
### size=1001   -> HTTP 400 {"message":"size must be between 1 and 1000"}
### page=abc    -> HTTP 400 {"message":"the query string cannot be read: invalid digit found in string"}
### page=999&size=50 -> HTTP 200 {"data":{"total_count":206,"total_page":5,"page_size":50,"current_page":999,"records":[]}}
```

### A.4 Transactions (writes)

```
$ BODY='{"datetime":"2026-10-02T09:30:00Z","payee":"Mobile Test Cafe","narration":"Flat white","flag":"*",
        "postings":[{"account":"Assets:WeChat","unit":{"number":"-32.50","commodity":"CNY"}},{"account":"Expenses:PersonalDiet:Lunch","unit":null}],
        "metas":[{"key":"source","value":"zhang-app"}],"tags":["mobile"],"links":["order-42"]}'      # the app's body shape
$ curl -H 'Content-Type: application/json' -d "$BODY" $B/api/transactions/preview
{"data":{"text":"2026-10-02 18:30:00 * \"Mobile Test Cafe\" \"Flat white\" #mobile ^order-42\n  source: \"zhang-app\"\n  Assets:WeChat -32.50 CNY\n  Expenses:PersonalDiet:Lunch",
 "field_errors":[],"unbalanced":[],"errors":[]}}
$ curl -H 'Content-Type: application/json' -d "$BODY" $B/api/transactions        ### -> HTTP 200 {"data":"Ok"}
visible in /api/journals after ~200ms; same id as in the old capture (7c785595-5694-c51e-dd34-115dc2cddeb1), datetime "2026-10-02T18:30:00"
data/2026/10.zhang:
2026-10-02 18:30:00 * "Mobile Test Cafe" "Flat white" #mobile ^order-42
  source: "zhang-app"
  Assets:WeChat -32.50 CNY
  Expenses:PersonalDiet:Lunch

$ curl -X PUT -d '{…"narration":"Buy BTC (edited)",…"postings":[{"account":"Assets:Crypto","unit":{"number":"0.01","commodity":"BTC"}},{"account":"Assets:Paypal","unit":{"number":"-260","commodity":"USD"}}],"metas":[],"tags":[],"links":[]}' $B/api/transactions/846d80bc-6824-8b70-4196-825346014589
### -> HTTP 200 {"data":null}       file now: Assets:Crypto 0.01 BTC { 26000 USD }   (cost kept although the body had no cost key)
### PUT unknown id 00000000-…  -> HTTP 404 {"message":"there is no transaction 00000000-0000-0000-0000-000000000000 in the ledger: the journal it was picked from is out of date, or it was removed. Reopen the journal, and try again"}
### PUT non-uuid "abc"         -> HTTP 400 {"message":"\"abc\" is not the id of a transaction"}

Validation:
### preview invalid account  -> 200 {"data":{"text":null,"field_errors":[{"posting":0,"field":"account","kind":"invalid_account","value":"Foo:Bar","message":"invalid account \"Foo:Bar\": …"}],"unbalanced":null,"errors":[]}}
### POST invalid account     -> 400 {"message":"invalid account \"Foo:Bar\": it is `Assets`, `Liabilities`, `Equity`, `Income` or `Expenses` followed by `:`-separated components, …"}
### preview unopened account -> 200 {"data":{"text":"2026-10-03 09:30:00 * \"V\" \"\"\n  Assets:Nope -1 CNY\n  Expenses:Medical","field_errors":[],"unbalanced":[],"errors":[{"error_type":"AccountDoesNotExist","metas":{"account_name":"Assets:Nope"}}]}}
### POST tag "two words"     -> 400 {"message":"invalid tag \"two words\": it cannot be empty or contain a space, tab, line break, `\"`, `:`, `(`, `)` or `,`"}
### POST naive "2026-10-03T09:30:00" -> 200 {"data":"Ok"}   (wall-clock datetime accepted, #726)
### POST lowercase commodity "usd"   -> 200 {"data":"Ok"}   (zhang dialect writes it; then CommodityDoesNotDefine + CommodityNotAllowed errors)
### POST date-only "2026-10-03"      -> 422 {"message":"Failed to deserialize the JSON body into the target type: datetime: invalid date and time \"2026-10-03\": write the ledger's wall-clock time as 2024-01-02T07:00:00 at line 1 column 24"}
### POST missing metas               -> 422 {"message":"Failed to deserialize the JSON body into the target type: missing field `metas` at line 1 column 96"}
### POST flag "Pending"              -> 422 {"message":"…flag: data did not match any variant of untagged enum FlagRequest at line 1 column 77"}
### POST no content-type             -> 415 {"message":"Expected request with `Content-Type: application/json`"}
### preview unit "-(10 + 2) / 4 CNY" -> 200 {"data":{"text":"2026-10-03 10:00:00 * \"Expr\" \"\"\n  Assets:WeChat -3 CNY\n  Expenses:Medical",…}}
### POST 0.00000001 BTC              -> 200; journals: unit "0.00000001", account_after "0.01000001"; file: "Assets:Crypto 0.00000001 BTC"

Uploads:
### POST /api/transactions/7c785595-…/documents -F file=@photo.png;type=image/png -> HTTP 200 {"data":"Ok"}
### POST /api/accounts/Assets:WeChat/documents  -F file=@photo.png               -> HTTP 201 [text/plain] (empty)
### POST /api/transactions/abc/documents                                          -> HTTP 400 {"message":"\"abc\" is not the id of a transaction"}
```

### A.5 Accounts

```
$ curl $B/api/accounts      (22 accounts, sorted by name; keys: alias, amount, amount_with_sub_accounts, balance_with_sub_accounts, has_sub_accounts, name, status)
{"name":"Assets:Crypto","status":"Open","alias":null,"amount":{"calculated":{"number":"1885.0000","commodity":"CNY"},"detail":{"BTC":"0.01","CNY":"0"}},
 "balance_with_sub_accounts":{"BTC":"0.01","CNY":"0"},"amount_with_sub_accounts":{"calculated":{"number":"1885.0000","commodity":"CNY"},"detail":{"CNY":"0","BTC":"0.01"}},"has_sub_accounts":false}
{"name":"Assets:Paypal",…,"amount":{"calculated":{"number":"132801.50","commodity":"CNY"},"detail":{"USD":"-250","CNY":"134614"}},…}
{"name":"Liabilities:CreditCard:Apple",…,"amount":{"calculated":{"number":"-476.1775","commodity":"CNY"},"detail":{"CNY":"-382","USD":"-12.99"}},…}

$ curl $B/api/accounts/Assets:Paypal       (also Assets%3APaypal → same 200)
{"data":{"date":"1970-01-01T00:00:00","type":"Assets","name":"Assets:Paypal","status":"Open","alias":null,
 "amount":{"calculated":{"number":"132801.50","commodity":"CNY"},"detail":{"CNY":"134614","USD":"-250"}},
 "amount_with_sub_accounts":{…},"balance_with_sub_accounts":{"USD":"-250","CNY":"134614"},"has_sub_accounts":false}}
### Assets:CitiBank (parent, no open) -> 404 {"message":"not found"}
### Assets:Nope                       -> 404 {"message":"not found"}
### Foo:Bar                           -> 400 {"message":"invalid account \"Foo:Bar\": …"}

$ curl $B/api/accounts/Assets:WeChat/journals        (56 rows, no paging params → everything)
[{"datetime":"2023-09-13T14:25:00","timestamp":1694582700,"account":"Assets:WeChat","trx_id":"a236abdf-1855-c7fa-2c8a-9cc8a22f2c49",
  "payee":"Github Restaurant","narration":"Fried Chicken","inferred_unit":{"number":"-25","commodity":"CNY"},"account_after":{"number":"146142","commodity":"CNY"},
  "asserted":null,"checked_balance":null,"difference":null,"tolerance":null,"passed":null},
 …,
 {"datetime":"2023-09-10T23:00:00","timestamp":1694354400,"account":"Assets:WeChat","trx_id":"cf93fca3-c552-b3e5-6e86-64b5e8f778ab","payee":"Balance Check",
  "narration":"Assets:WeChat","inferred_unit":{"number":"0","commodity":"CNY"},"account_after":{"number":"146183","commodity":"CNY"},
  "asserted":{"number":"100","commodity":"CNY"},"checked_balance":{"number":"146183","commodity":"CNY"},"difference":{"number":"-146083","commodity":"CNY"},"tolerance":null,"passed":false}, …]
trx_id a236abdf-… == /api/journals id of "Github Restaurant / Fried Chicken" 2023-09-13T14:25:00 (real transaction id now)
### ?page=1&size=2   -> HTTP 200, header x-total-count: 56, 2 rows
### ?size=0          -> 400 {"message":"size must be between 1 and 1000"}
### Assets:Nope/journals     -> 404 {"message":"not found"}         (old: [])
### Assets:CitiBank/journals -> 404 {"message":"not found"}         (parent without own open directive)
### Foo:Bar/journals         -> 400 {"message":"invalid account …"} (old: 500)

$ curl -d '{"type":"Check","amount":{"number":"146109.50","commodity":"CNY"}}' $B/api/accounts/Assets:WeChat/balances   ### -> HTTP 200 {"data":{"replaced":[]}}
$ curl -d '[{"type":"Check","account_name":"Liabilities:CreditCard:Apple","amount":{"number":"-382","commodity":"CNY"}},
            {"type":"Pad","account_name":"Assets:Paypal","amount":{"number":"134614","commodity":"CNY"},"pad":"Equity:OpenBalancing"}]' $B/api/accounts/batch-balances  ### -> HTTP 200 {"data":{"replaced":[]}}
written: "2026-10-10 03:23:01 balance Liabilities:CreditCard:Apple -382 CNY" / "2026-10-10 03:23:01 balance Assets:Paypal 134614 CNY with pad Equity:OpenBalancing"
### Foo:Bar/balances  -> 400 {"message":"invalid account …"}
### "type":"check"    -> 422 {"message":"Failed to deserialize the JSON body into the target type: type: unknown variant `check`, expected `Check` or `Pad` at line 1 column 15"}
```

### A.6 Documents and commodities

```
$ curl $B/api/documents/YXR0YWNobWVudHMvcmVjZWlwdC50eHQ=           ### -> HTTP 200 [application/octet-stream] content-disposition: inline; filename="receipt.txt"   hello receipt
$ curl $B/api/documents/<b64 of attachments/nope.txt>              ### -> HTTP 404 {"message":"the document attachments/nope.txt does not exist"}
$ curl $B/api/documents/@@@                                        ### -> HTTP 400 {"message":"the file path is not a base64 encoded path"}
$ curl $B/api/documents/YXR0YWNobWVudHMv5Li/LnR4dA==               ### -> HTTP 200 content-disposition: inline; filename="丿.txt"   (b64 contains "/")
$ curl $B/api/documents/YXR0YWNobWVudHMv5Li%2FLnR4dA==             ### -> HTTP 200 (same, %2F)
$ curl $B/api/documents/<b64 of ../../etc/hosts>                   ### -> HTTP 403 {"message":"the document ../../etc/hosts is outside the ledger's directory, so it cannot be downloaded"}

$ curl $B/api/commodities
{"data":[{"name":"CNY","precision":2,"prefix":"¥","suffix":null,"rounding":"RoundDown","group":null,"total_amount":"444553.50","latest_price_date":null,"latest_price_amount":null,"latest_price_commodity":null},
 {"name":"USD","precision":2,"prefix":"$",…,"total_amount":"-262.99","latest_price_date":"2023-09-01T00:00:00","latest_price_amount":"7.25","latest_price_commodity":"CNY"},
 {"name":"BTC","precision":8,…,"group":"Crypto","total_amount":"0.01","latest_price_date":null,"latest_price_amount":null,"latest_price_commodity":null}]}
$ curl $B/api/commodities/USD
{"data":{"info":{…},"lots":[{"account":"Assets:Paypal","amount":"-250","cost":null,"price":null,"acquisition_date":null},
 {"account":"Liabilities:CreditCard:Apple","amount":"-12.99","cost":null,"price":null,"acquisition_date":null}],
 "prices":[{"datetime":"2023-06-10T00:00:00","amount":{"number":"7.1","commodity":"CNY"}},{"datetime":"2023-09-01T00:00:00","amount":{"number":"7.25","commodity":"CNY"}}]}}
$ curl $B/api/commodities/BTC
{"data":{"info":{…},"lots":[{"account":"Assets:Crypto","amount":"0.01","cost":{"number":"26000","commodity":"USD"},"price":null,"acquisition_date":"2023-09-06"}],
 "prices":[{"datetime":"2023-09-01T00:00:00","amount":{"number":"26000","commodity":"USD"}}]}}
$ curl $B/api/commodities/NOPE                                     ### -> HTTP 404 {"message":"not found"}
```

### A.7 Statistics graph

```
$ curl "$B/api/statistic/graph?from=2023-08-31T15:00:00Z&to=2023-09-05T14:59:59Z&interval=Day"     (what the app sends)
{"data":{"from":"2023-09-01T00:00:00","to":"2023-09-05T23:59:59","balances":{
  "2023-09-05":{"calculated":{"number":"444755.3225","commodity":"CNY"},"detail":{"USD":"-12.99","CNY":"444849.50"}},
  "2023-09-01":{"calculated":{"number":"445042","commodity":"CNY"},"detail":{"CNY":"445042"}}, …},
 "changes":{"2023-09-01":{"Liabilities":{…"-11"…},"Expenses":{…"53"…},"Income":{…"-200"…},"Assets":{…"158"…}}, …}}}
balance keys ['2023-09-01' … '2023-09-05'] (ledger dates; no extra UTC day)
$ curl "$B/api/statistic/graph?from=2023-09-01&to=2023-09-30&interval=Week"
{"data":{"from":"2023-09-01T00:00:00","to":"2023-09-30T23:59:59","balances":{"2023-08-28":{…},"2023-09-04":{"calculated":{"number":"444698.8225",…},"detail":{"BTC":"0.01","CNY":"444720.50","USD":"-262.99"}},"2023-09-11":{…},"2023-09-18":{…},"2023-09-25":{…}},"changes":{…}}}
### interval=day   -> 400 {"message":"Failed to deserialize query string: unknown variant `day`, expected one of `Day`, `Week`, `Month`"}
### missing to     -> 400 {"message":"Failed to deserialize query string: missing field `to`"}
```

### A.8 Built-in queries that replace the removed endpoints

```
$ curl $B/api/query/builtins     → 39 built-ins, e.g.
  ledger.now ( ) -> date:date, time:str
  report.net_worth ( to:date, currency:str ) -> balance:inventory, units:inventory, value:inventory
  report.liabilities ( to:date, currency:str ) -> units:inventory, value:inventory
  report.flows ( from:date, to:date, currency:str ) -> type:str, units:inventory, value:inventory
  report.transaction_count ( from:date, to:date ) -> transactions:int
  report.account_totals ( type:str, from:date, to:date, currency:str ) -> account:str, units:inventory, value:inventory
  report.top_postings ( type:str, from:date, to:date, currency:str ) -> date, time, timestamp:int, account, id, payee, narration, units:amount, account_balance:amount, value:amount
  accounts.balance_history ( account:str ) -> date:date, currency:str, balance:amount
  accounts.documents ( account:str ) -> date, time, account, path, transaction_id
  journals.page ( keyword:str, tags:set, links:set, size:int, offset:int ) -> seq, type, id, date, time, flag, payee, narration, tags:set, links:set, metas:metas
  journals.payees ( ) -> payee:str
  journals.accounts ( date:date, time:str ) -> account:str
  journals.documents ( ) -> date, time, path, account, transaction_id
  journals.errors ( size:int, offset:int ) -> id, kind, file, line:int, column:int, span_start:int, span_end:int, source, metas:metas
  budgets.month ( month:date ) -> name, alias, category, currency, last_month:date, assigned:amount, activity:decimal, available:amount, closed:bool
  budgets.budget ( name:str ) -> name, alias, category, currency, accounts:set, close:date, close_time:str
  budgets.budget_month ( name:str, month:date ) -> (as budgets.month)
  budgets.events ( name:str, month:date ) -> date, time, timestamp:int, type:str, amount:amount
  budgets.postings ( name:str, month:date ) -> date, time, timestamp:int, account, id, payee, narration, units:amount, balance:amount

# /api/statistic/summary replacement (one read of the ledger)
$ curl -H 'Content-Type: application/json' $B/api/query/builtins -d '[
   {"name":"report.net_worth","params":{"to":"2023-09-30","currency":"CNY"}},
   {"name":"report.liabilities","params":{"to":"2023-09-30","currency":"CNY"}},
   {"name":"report.flows","params":{"from":"2023-09-01","to":"2023-09-30","currency":"CNY"}},
   {"name":"report.transaction_count","params":{"from":"2023-09-01","to":"2023-09-30"}}]'
{"data":[
 {"columns":[{"name":"balance","type":"inventory"},{"name":"units","type":"inventory"},{"name":"value","type":"inventory"}],"rows":[[
   {"positions":[{"units":{"number":"0.01","currency":"BTC"},"cost":{"number":"26000","currency":"USD","date":"2023-09-06","label":null}},{"units":{"number":"444553.50","currency":"CNY"},"cost":null},{"units":{"number":"-262.99","currency":"USD"},"cost":null}]},
   {"positions":[{"units":{"number":"0.01","currency":"BTC"},"cost":null},{"units":{"number":"444553.50","currency":"CNY"},"cost":null},{"units":{"number":"-262.99","currency":"USD"},"cost":null}]},
   {"positions":[{"units":{"number":"444531.8225","currency":"CNY"},"cost":null}]}]]},
 {"columns":[{"name":"units",…},{"name":"value",…}],"rows":[[{"positions":[{"units":{"number":"-651","currency":"CNY"},…},{"units":{"number":"-12.99","currency":"USD"},…}]},{"positions":[{"units":{"number":"-745.1775","currency":"CNY"},…}]}]]},
 {"columns":[{"name":"type",…},{"name":"units",…},{"name":"value",…}],"rows":[
   ["Expenses",{"positions":[{"units":{"number":"704.50","currency":"CNY"},…},{"units":{"number":"12.99","currency":"USD"},…}]},{"positions":[{"units":{"number":"798.6775","currency":"CNY"},…}]}],
   ["Income",{"positions":[{"units":{"number":"-436","currency":"CNY"},…}]},{"positions":[{"units":{"number":"-436","currency":"CNY"},…}]}]]},
 {"columns":[{"name":"transactions","type":"int"}],"rows":[[40]]}]}
→ summary: balance 444531.8225 CNY {BTC 0.01, CNY 444553.50, USD -262.99}; liability -745.1775; expense 798.6775 {CNY 704.50, USD 12.99}; income -436; transaction_number 40

# /api/statistic/Expenses replacement
$ curl … $B/api/query/builtins -d '[{"name":"report.account_totals","params":{"type":"Expenses","from":"2023-09-01","to":"2023-09-30","currency":"CNY"}},
                                   {"name":"report.top_postings","params":{"type":"Expenses","from":"2023-09-01","to":"2023-09-30","currency":"CNY"}}]'
rows[0]: ["Expenses:RemunerationTax",{units 28 CNY},{value 28 CNY}], …, ["Expenses:Clothing",{units 90 CNY + 12.99 USD},{value 184.1775 CNY}], ["Expenses:PersonalDiet:Lunch",…298…]
rows[1]: ["2023-09-05","10:00:00",1693875600,"Expenses:Clothing","257ba3ec-06a5-60a6-c012-db8495939e46","UNIQLO","Shirt in USD",{"number":"12.99","currency":"USD"},{"number":"12.99","currency":"USD"},{"number":"94.1775","currency":"CNY"}],
         ["2023-09-03","12:30:00",1693711800,"Expenses:Groceries","3bcdbf6a-…","Supermarket","Weekly groceries",{"number":"88.50","currency":"CNY"},{"number":"88.50","currency":"CNY"},{"number":"88.50","currency":"CNY"}], …

# /api/errors replacement
$ curl … -d '{"params":{"size":100,"offset":0},"count_total":true}' $B/api/query/builtins/journals.errors
{"data":{"columns":[id,kind,file,line,column,span_start,span_end,source,metas],"rows":[
 ["a6618982-5e51-d0f9-2f0f-ad3d64269bd2","UnbalancedTransaction","data/2023/12.zhang",38,1,936,1025,"2023-09-08 11:00:00 \"Oops\" \"Unbalanced\"\n  Assets:Paypal -10 CNY\n  Expenses:Clothing 9 CNY",[{"key":"txn_id","value":"a6618982-5e51-d0f9-2f0f-ad3d64269bd2"}]],
 ["cf93fca3-c552-b3e5-6e86-64b5e8f778ab","AccountBalanceCheckError","data/2023/12.zhang",42,1,1027,1076,"2023-09-10 23:00:00 balance Assets:WeChat 100 CNY",[{"key":"account_name","value":"Assets:WeChat"}]]],"total":2}}

# /api/for-new-transaction replacement
$ curl … -d '{"params":{}}' $B/api/query/builtins/ledger.now        → {"data":{"columns":[{"name":"date","type":"date"},{"name":"time","type":"str"}],"rows":[["2026-10-10","03:21:57"]]}}
$ curl … -d '{"params":{}}' $B/api/query/builtins/journals.payees   → rows [["Adidas"],["Doge Random House"],["Exchange"],…,["UNIQLO"],["Vans"],["隆江猪脚饭"]]   (sorted, no Balance Check/Pad)
$ curl … -d '{"params":{"date":"2026-10-10","time":"03:20:00"}}' $B/api/query/builtins/journals.accounts → rows [["Assets:CitiBank:9999"],["Assets:Crypto"],["Assets:Paypal"],["Assets:WeChat"],["Equity:OpenBalancing"],…]

# /api/accounts/{a}/balances, /documents and /api/documents replacements
$ curl … -d '{"params":{"account":"Assets:Paypal"}}' $B/api/query/builtins/accounts.balance_history
  → rows [["2023-05-31","CNY",{"number":"135125","currency":"CNY"}],["2023-06-02","CNY",{"number":"135066","currency":"CNY"}],…]   (date order)
$ curl … -d '{"params":{"account":"Assets:Paypal"}}' $B/api/query/builtins/accounts.documents
  → rows [["2023-09-07","00:00:00","Assets:Paypal","attachments/receipt.txt",null]]
$ curl … -d '{"params":{}}' $B/api/query/builtins/journals.documents   (after one transaction and one account upload)
  → rows [["2026-10-10","03:23:21","attachments/b1402c9d-…/photo.png","Assets:WeChat",null],
          ["2026-10-02","18:30:00","attachments/2b573343-…/photo.png",null,"7c785595-5694-c51e-dd34-115dc2cddeb1"],
          ["2023-09-07","00:00:00","attachments/receipt.txt","Assets:Paypal",null]]

# /api/budgets* replacements
$ curl … -d '{"params":{"month":"2023-09-01"}}' $B/api/query/builtins/budgets.month
  → rows [["food","Eating","Living","CNY","2023-09-01",{"number":"1000","currency":"CNY"},"88.50",{"number":"911.50","currency":"CNY"},false]]
$ curl … -d '{"params":{"month":"2026-10-01"}}' …/budgets.month   → [["food","Eating","Living","CNY","2026-10-01",{"number":"911.50",…},"0",{"number":"911.50",…},false]]   (rollover)
$ curl … -d '{"params":{"name":"food"}}' …/budgets.budget         → [["food","Eating","Living","CNY",["Expenses:Groceries"],null,null]]
$ curl … -d '{"params":{"name":"food","month":"2023-09-01"}}' …/budgets.budget_month → [["food","Eating","Living","CNY","2023-09-01",{"number":"1000",…},"88.50",{"number":"911.50",…},false]]
$ curl … -d '{"params":{"name":"food","month":"2023-09-01"}}' …/budgets.events       → [["2023-09-01","00:00:00",1693494000,"assign",{"number":"1000","currency":"CNY"}]]
$ curl … -d '{"params":{"name":"food","month":"2023-09-01"}}' …/budgets.postings     → [["2023-09-03","12:30:00",1693711800,"Expenses:Groceries","3bcdbf6a-…","Supermarket","Weekly groceries",{"number":"88.50","currency":"CNY"},{"number":"88.50","currency":"CNY"}]]

# errors of the built-in endpoints
### report.flows without :to             -> 400 {"message":"parameter :to of report.flows is missing"}
### unknown name nope.nope               -> 404 {"message":"there is no built-in query nope.nope"}
### from "2023-09-01T00:00:00Z" (instant) -> 400 {"message":"parameter :from must be a date string YYYY-MM-DD or null"}
```

## Appendix B: how to reproduce

```sh
git -C /Users/kilerd/Projects/zhang fetch origin
git -C /Users/kilerd/Projects/zhang worktree add --detach /tmp/zhang-main origin/main
cd /tmp/zhang-main && cargo build -p zhang            # ~8 min on a loaded machine
# ledger: cp examples/main.zhang + an include of data/2023/12.zhang (contents described in the header table)
cd /tmp/zhang-v2-run && /tmp/zhang-main/target/debug/zhang serve /tmp/zhang-v2-ledger --addr 127.0.0.1 --port 18070 --no-report
cd /tmp/zhang-v2-run-auth && /tmp/zhang-main/target/debug/zhang serve /tmp/zhang-v2-ledger-auth --addr 127.0.0.1 --port 18071 --auth demo:secret --no-report

export PATH=/opt/homebrew/bin:$PATH JAVA_HOME=/opt/homebrew/opt/openjdk@17
flutter test                                                        # 257 passed (no server involved)
D=C72765EE-0200-4184-98B4-677679E629EB                              # iPhone 17 Pro
flutter test integration_test/onboarding_live_test.dart      -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18071
flutter test integration_test/browse_live_test.dart          -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18070
flutter test integration_test/add_transaction_live_test.dart -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18070 --dart-define=ZHANG_LEDGER_DIR=/tmp/zhang-v2-ledger
flutter test integration_test/accounts_reports_live_test.dart -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18070

git -C /Users/kilerd/Projects/zhang worktree remove --force /tmp/zhang-main
```
