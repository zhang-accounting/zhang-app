# zhang-app developer guide

Flutter (Android + iOS) client for the zhang accounting server. Binding stack decisions are in
[`architecture.md`](architecture.md); the server contract is [`zhang-api.md`](zhang-api.md).

## Toolchain

```sh
export PATH=/opt/homebrew/bin:$PATH
export JAVA_HOME=/opt/homebrew/opt/openjdk@17      # for Android/Gradle
flutter --version                                  # 3.47.x stable, Dart 3.13
flutter pub get                                    # also runs gen-l10n (pubspec: generate: true)
```

No `build_runner`. The only generated code is `lib/l10n/app_localizations*.dart`, produced by
`flutter gen-l10n` (automatic on `pub get` / `run` / `build`) from `lib/l10n/*.arb`.

## Run against a local zhang server

The app needs **zhang ≥ 0.2** (the built-in query API); older servers get "server too old". Build the server from
zhang `origin/main` in a throw-away worktree (the cargo package is `zhang`, not `zhang-cli`; ~8 min cold, about a
minute with a warm cache):

```sh
git -C /Users/kilerd/Projects/zhang fetch origin
git -C /Users/kilerd/Projects/zhang worktree add --detach /tmp/zhang-main origin/main
(cd /tmp/zhang-main && cargo build -p zhang)          # → /tmp/zhang-main/target/debug/zhang
```

Test ledger (the one the fixtures and the live tests use). `examples/main.zhang` stops in 2023, so it gets the
2023-09 extras of the compatibility audit (BTC at a USD cost, USD prices 7.1 / 7.25, a `food` budget, tags / links /
metadata, a document, one unbalanced transaction, one failing balance check) and a few **2026** entries, so Home and
Reports have data in the current and the previous month (by the ledger's clock; move the dates when the calendar
moves on):

```sh
for L in /tmp/zhang-v3-ledger /tmp/zhang-v3-ledger-auth; do
  rm -rf $L && mkdir -p $L/data/2023 $L/data/2026 $L/attachments
  cp /tmp/zhang-main/examples/main.zhang $L/
  printf '\n\ninclude "data/2023/12.zhang"\ninclude "data/2026/10.zhang"\n' >> $L/main.zhang
  echo 'hello receipt' > $L/attachments/receipt.txt
  # + data/2023/12.zhang and data/2026/10.zhang with the contents below
done
mkdir -p /tmp/zhang-v3-run /tmp/zhang-v3-run-auth
# start each from a scratch cwd (document downloads create ./.cache there); never serve the repo's examples/
(cd /tmp/zhang-v3-run && /tmp/zhang-main/target/debug/zhang serve /tmp/zhang-v3-ledger \
   --addr 127.0.0.1 --port 18080 --no-report)
(cd /tmp/zhang-v3-run-auth && /tmp/zhang-main/target/debug/zhang serve /tmp/zhang-v3-ledger-auth \
   --addr 127.0.0.1 --port 18081 --auth demo:secret --no-report)
#    Physical device / Android emulator: use --addr 0.0.0.0

curl -s http://127.0.0.1:18080/api/info   # {"data":{…,"format":"zhang","reload_failure":null}}  ← `format` = v0.2

# run the app
xcrun simctl list devices available            # pick an iPhone
flutter run -d <simulator-id>                  # or: flutter run -d emulator-5554
```

`data/2023/12.zhang`:

```text
1970-01-01 commodity BTC
  precision: 8
  group: "Crypto"

1970-01-01 open Assets:Crypto BTC
1970-01-01 open Expenses:Groceries CNY
  budget: food

2023-06-10 price USD 7.1 CNY
2023-09-01 price USD 7.25 CNY
2023-09-01 price BTC 26000 USD

2023-09-01 budget food CNY
  alias: "Eating"
  category: "Living"
2023-09-01 budget-add food 1000 CNY

2023-09-03 12:30:00 * "Supermarket" "Weekly groceries" #weekly ^receipt-001
  receipt_no: "A-1"
  Assets:CitiBank:9999 -88.50 CNY
  Expenses:Groceries 88.50 CNY ; paid by card
    category: "food"

2023-09-05 10:00:00 * "UNIQLO" "Shirt in USD"
  Liabilities:CreditCard:Apple -12.99 USD
  Expenses:Clothing 12.99 USD

2023-09-06 00:00:00 * "Exchange" "Buy BTC (edited)"
  Assets:Crypto 0.01 BTC { 26000 USD }
  Assets:Paypal -260 USD

2023-09-06 12:00:00 * "Exchange" "Buy USD with price"
  Assets:Paypal 10 USD @ 7.2 CNY
  Assets:CitiBank:9999 -72 CNY

2023-09-07 document Assets:Paypal "attachments/receipt.txt"

2023-09-08 11:00:00 "Oops" "Unbalanced"
  Assets:Paypal -10 CNY
  Expenses:Clothing 9 CNY

2023-09-10 23:00:00 balance Assets:WeChat 100 CNY
```

`data/2026/10.zhang`:

```text
2026-09-20 12:00:00 * "Bakery" "Bread"
  Assets:WeChat -18.00 CNY
  Expenses:PersonalDiet:Lunch 18.00 CNY

2026-10-01 09:00:00 * "GrandLord" "October salary"
  Assets:CitiBank:9999 5000.00 CNY
  Income:GrandLordCompany:Salary -5000.00 CNY

2026-10-03 12:15:00 * "Noodle Bar" "Lunch" #work
  Assets:WeChat -42.00 CNY
  Expenses:PersonalDiet:Lunch 42.00 CNY

2026-10-05 19:30:00 * "Metro" "Commute card top-up"
  Liabilities:CreditCard:Apple -100.00 CNY
  Expenses:Transportation 100.00 CNY

2026-10-08 20:00:00 * "UNIQLO" "Jacket"
  Liabilities:CreditCard:Apple -399.00 CNY
  Expenses:Clothing 399.00 CNY

2026-10-04 10:00:00 * "Tiny" "sat"
  Assets:Crypto 0.00000001 BTC
  Assets:Crypto -0.00000001 BTC

2026-10-06 08:00:00 ! "Pending Shop" "Awaiting refund"
  Assets:WeChat -9.90 CNY
  Expenses:Sport
```

The fixture capture also posted one transaction through the API (`Mobile Test Cafe`, with a `photo.png` attached via
`POST /api/transactions/{id}/documents`) and one account document (`POST /api/accounts/Assets:WeChat/documents`).

Ports used by the agents' runs: `18080` (no auth), `18081` (`--auth demo:secret`), `18082` (a zhang 0.1 build, only
for the "server too old" check), `18100` (a zhang with the app login handoff, PR #786, for the "Browser" sign-in;
`ZHANG_SESSION_SECRET=pk-test` keeps session tokens valid across restarts) and `18101` (dev proxy, below).

Browser sign-in by hand: a `cargo build -p zhang` without `--features frontend` answers `/login` with a plain-text
"frontend is not enabled" page. Either build with the frontend, or serve the built web UI (`frontend/dist` of the
zhang checkout) on another port and forward `/api/*` to the server (any small reverse proxy; the agents used a
Python one on `:18101`), then use that port as the server URL in the app. The fixtures in `test/fixtures` were captured from `:18080` with
plain curls (one file per response; the requests are the ones in `docs/compat-v0.2.md` Appendix A).

Server URL to type in onboarding: iOS simulator `http://127.0.0.1:18080`, Android emulator
`http://10.0.2.2:18080`, device `http://<Mac LAN IP>:18080`. Plain http is allowed on both
platforms (`usesCleartextTraffic`, `NSAllowsArbitraryLoads`). URLs are normalised (`/api` and trailing
`/` stripped, `https://` added when no scheme).

Builds:

```sh
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

## Tests and quality gates

```sh
flutter analyze        # must report "No issues found!"
flutter test           # unit + widget tests (no server needed)
```

* `test/fixtures/*.json` – responses captured from a zhang v0.2 server on the test ledger above (built-in query
  results are the `data` of `POST /api/query/builtins[/{name}]`: batches are lists, single queries objects;
  `journals.json` is the envelope of a page with records picked verbatim from the same capture). Load with
  `fixture()` / `fixtureData()` from `test/helpers/fixtures.dart`.
* `test/helpers/fake_adapter.dart` – `FakeAdapter` for dio: set
  `client.dio.httpClientAdapter = FakeAdapter((req) => jsonResponse({...}))` to test a repository and
  inspect `adapter.last` (path, headers, body).
* `test/helpers/builtin_fake.dart` – `FakeBuiltins` answers `POST /api/query/builtins[/{name}]` from the captured
  fixtures (override one query with `FakeBuiltins({'ledger.now': (params) => …})`), logs every call
  (`callsTo('report.flows').last.params`) and can fail a call (`intercept`). `FakeZhangServer` and `pumpLedgerApp`
  use it.
* Widget tests override `sharedPreferencesProvider`, `secretStoreProvider` (`InMemorySecretStore`),
  `initialProfilesStateProvider` and `connectionTesterProvider`; see `test/widget_test.dart`. The SSE stream is off
  unless `ledgerEventsEnabledProvider` is overridden (only `bootstrap()` turns it on).
* `integration_test/*_live_test.dart` – end-to-end on a simulator against a live server (not run by
  `flutter test`; they clear the saved profiles). Each prints `ZHANG_RESULT …` lines:

  ```sh
  D=C72765EE-0200-4184-98B4-677679E629EB     # "iPhone 17 Pro"
  flutter test integration_test/onboarding_live_test.dart       -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18081 \
    [--dart-define=ZHANG_OLD_URL=http://127.0.0.1:18082]      # demo:secret by default (ZHANG_USER / ZHANG_PASS)
  flutter test integration_test/browse_live_test.dart           -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18080
  flutter test integration_test/add_transaction_live_test.dart  -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18080 \
    --dart-define=ZHANG_LEDGER_DIR=/tmp/zhang-v3-ledger
  flutter test integration_test/accounts_reports_live_test.dart -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18080
  flutter test integration_test/session_login_live_test.dart    -d $D --dart-define=ZHANG_URL=http://127.0.0.1:18100
  ```

  `session_login_live_test.dart` replaces the browser (`webAuthLauncherProvider`, passed to
  `bootstrap(overrides:)`) with `POST /api/auth/login` + `POST /api/auth/app/code` over HTTP and feeds the returned
  `zhang-app://auth/callback?code=…` into the app's real callback → exchange → Bearer path, then signs out and in
  again.

## Where things live

```
lib/
  main.dart                 bootstrap(): loads profiles, ProviderScope overrides, retry policy
  app.dart                  MaterialApp.router, light/dark theme, zh/en locale resolution
  router.dart               AppRoutes (all paths) + routerProvider (go_router, redirects)
  core/theme/               app_theme.dart (M3 seed), app_colors.dart (ZhangColors: income/expense…)
  core/utils/               money.dart (formatMoney, formatDecimal, toneOf/amountColor), dates.dart (ZhangDates)
  core/widgets/             app_shell.dart (4 tabs + centre FAB), error_view.dart (ErrorView,
                            describeApiError), ledger_widgets.dart (ActiveLedgerTitle, SettingsButton,
                            LedgerDot, PlaceholderScreen)
  data/profiles/            ServerProfile, ProfileRepository, SecretStore, profilesProvider/activeProfileProvider
  data/auth/                BrowserSignIn (browser sign-in handoff: status check, login page, callback code,
                            app/exchange → SessionGrant), webAuthLauncherProvider / browserSignInProvider
  data/api/                 ZhangApiClient + zhangApiClientProvider, ZhangApiException hierarchy,
                            AuthInterceptor, ZhangEndpoints, ConnectionTester (version gate),
                            BuiltinQueryClient (`client.builtins`)
  data/models/              hand-written DTOs (barrel: models.dart)
  data/repositories/        one repository + provider per API group (barrel: repositories.dart),
                            ledgerRevisionProvider, ledgerEventsProvider (SSE), shared data providers
                            (server gate, info, options, ledger clock, commodities)
  features/<feature>/       screens; onboarding/ and settings/ are done, the rest are placeholders
  l10n/                     app_en.arb (template), app_zh.arb, generated AppLocalizations, l10n.dart (context.l10n)
```

## Data layer cheat sheet

| Need | Use |
|---|---|
| Active profile (name, colour, URL) | `ref.watch(activeProfileProvider)` |
| HTTP client | `ref.watch(zhangApiClientProvider)` (rarely needed directly) |
| A built-in query | `client.builtins.query(BuiltinQuery('ledger.now'), (r) => r.rows.first.dateTime('date', 'time'))`, `batch([...], convert)` |
| Journals / create / preview / update transaction | `journalRepositoryProvider` → `list(JournalQuery)`, `forNewTransaction()`, `preview(req)`, `create(req)`, `update(id, req)` |
| Accounts | `accountRepositoryProvider` → `list()`, `get(name)`, `journals(name)`, `balances(name)`, `documents(name)`, `addBalance(name, req)`, `addBalances(reqs)` |
| Reports | `statisticRepositoryProvider` → `summary(from, to, currency:)`, `graph(from, to)`, `rank(AccountType, from, to, currency:)` (currency = `LedgerOptions.operatingCurrency`) |
| Budgets | `budgetRepositoryProvider` → `list(year:, month:)`, `get(name, …)`, `interval(name, year, month)` |
| Commodities | `commodityRepositoryProvider` → `list()`, `get(name)`; cached map: `commoditiesProvider` |
| Info / options / errors / ledger clock / reload | `ledgerRepositoryProvider` (`info`, `options`, `errors`, `now`, `reload`); cached: `serverGateProvider`, `serverInfoProvider`, `ledgerOptionsProvider`; "now" by the ledger: `ref.watch(ledgerClockProvider)()` |
| Documents | `documentRepositoryProvider` → `list()`, `download(doc)` |
| Refetch everything | `ref.read(ledgerRevisionProvider.notifier).bump()` |

Rules the layer already encodes (do not re-implement): `{"data": …}` envelope unwrapping; errors are
always a sealed `ZhangApiException` (`ApiUnauthorized`, `ApiNotFound`, `ApiServerError`, `ApiNetworkError`,
`ApiParseError`, `ApiServerTooOld`, `ApiPasskeyOnly`; `isMissingRoute` for 404/405 `no route`); amounts are
`Decimal` (parsed from strings, sent as strings); query cells are read by column name; response datetimes are naive
ledger-local wall-clock `DateTime`s and request datetimes / ranges are sent the same way (`toNaiveIso`,
`toIsoDate`); `narration`/`tags`/`links`/`metas` are always sent; the SSE `Reload` event (or, without the stream,
a 600 ms timer after each write) bumps `ledgerRevisionProvider`.

Gotchas worth knowing: transaction ids/sequences change on every reload (never persist them); account journals
include sub-accounts and their `trxId` is the transaction id; tag/link journal filters are applied client-side only
(dart:io re-encodes the `[]` the server needs, see `JournalRepository.list`); a `balance … with pad` is a pad and a
check at the same datetime (`foldBalancePads`).

## How to add a feature screen

1. Create `lib/features/<feature>/<feature>_screen.dart`. Replace the placeholder class in place for the
   existing tabs (`HomeScreen`, `JournalsScreen`, `ReportsScreen`, `AccountsScreen`,
   `NewTransactionScreen`) – the router already points at them.
2. Data: declare providers next to the screen, watching the revision counter and a repository:

   ```dart
   final accountsProvider = FutureProvider<List<Account>>((ref) {
     ref.watch(ledgerRevisionProvider);                // refetch after writes / pull-to-refresh
     return ref.watch(accountRepositoryProvider).list(); // refetch on profile switch
   });

   // in build():
   ref.watch(accountsProvider).when(
     data: (accounts) => ...,
     loading: () => const Center(child: CircularProgressIndicator()),
     error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(accountsProvider)),
   );
   ```

   For parameterised data use `FutureProvider.family`. Format money with
   `commodities[code]?.format(amount)` (from `commoditiesProvider`) or `formatMoney(amount, code)`;
   colour it with `amountColor(context, amount)` / `context.zhangColors`.
3. Strings: add keys to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`, then
   `flutter gen-l10n` (or any `flutter run/test`); use `context.l10n.<key>`.
4. Routes: add the path to `AppRoutes` in `lib/router.dart`.
   * Detail page inside a tab (keeps the bottom bar): add a child `GoRoute` under that tab's
     `StatefulShellBranch` route, e.g. `GoRoute(path: 'detail/:name', builder: …)` under `/accounts`,
     and navigate with `context.push('/accounts/detail/${Uri.encodeComponent(name)}')`.
   * Full-screen page (covers the bottom bar): add a top-level `GoRoute` (like `/transactions/new`).
   * New bottom tab: add a `StatefulShellBranch` **and** a matching `ShellDestination` in
     `lib/core/widgets/app_shell.dart` (same order). The bar is designed for four tabs around the FAB.
   * Settings sub-pages (budgets, commodities, errors…): child routes of `/settings`, plus a tile in
     `SettingsScreen` (section above "About").
5. Keep `ActiveLedgerTitle` + `SettingsButton` in the Home app bar – settings are only reachable there.
6. Tests: parser/repository tests with fixtures + `FakeAdapter`; widget tests with provider
   overrides. Run `flutter analyze && flutter test` before handing back.
