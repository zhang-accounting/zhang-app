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

```sh
# 1. throw-away ledger copy (every write goes into the ledger dir – never serve the repo's examples/)
rm -rf /tmp/zhang-app-dev-ledger && mkdir -p /tmp/zhang-app-dev-ledger /tmp/zhang-app-run
cp /Users/kilerd/Projects/zhang/examples/main.zhang /tmp/zhang-app-dev-ledger/

# 2. start it from a scratch cwd (document downloads create ./.cache there)
cd /tmp/zhang-app-run
/Users/kilerd/Projects/zhang/target/debug/zhang serve /tmp/zhang-app-dev-ledger \
  --addr 127.0.0.1 --port 18010 --no-report
#    Basic-auth instance (use another ledger copy + port):
#    ... serve /tmp/zhang-app-dev-ledger-auth --addr 127.0.0.1 --port 18011 --auth demo:secret --no-report
#    Physical device / Android emulator: use --addr 0.0.0.0

curl -s http://127.0.0.1:18010/api/info      # {"data":{"title":"My Accounting",...}}

# 3. run the app
xcrun simctl list devices available            # pick an iPhone
flutter run -d <simulator-id>                  # or: flutter run -d emulator-5554
```

Server URL to type in onboarding: iOS simulator `http://127.0.0.1:18010`, Android emulator
`http://10.0.2.2:18010`, device `http://<Mac LAN IP>:18010`. Plain http is allowed on both
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
flutter test           # unit + widget tests
```

* `test/fixtures/*.json` – response samples copied from `docs/zhang-api.md` (plus a synthetic
  transaction with exponent-notation amounts). Load with `fixture()` / `fixtureData()` from
  `test/helpers/fixtures.dart`.
* `test/helpers/fake_adapter.dart` – `FakeAdapter` for dio: set
  `client.dio.httpClientAdapter = FakeAdapter((req) => jsonResponse({...}))` to test a repository and
  inspect `adapter.last` (path, headers, body).
* Widget tests override `sharedPreferencesProvider`, `secretStoreProvider` (`InMemorySecretStore`),
  `initialProfilesStateProvider` and `connectionTesterProvider`; see `test/widget_test.dart`.
* `integration_test/onboarding_live_test.dart` – end-to-end onboarding on a simulator against a live
  Basic-auth server (not run by `flutter test`; clears saved profiles):

  ```sh
  flutter test integration_test/onboarding_live_test.dart -d <simulator-id> \
    --dart-define=ZHANG_URL=http://127.0.0.1:18011   # demo:secret by default (ZHANG_USER / ZHANG_PASS)
  ```

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
  data/api/                 ZhangApiClient + zhangApiClientProvider, ZhangApiException hierarchy,
                            AuthInterceptor, ZhangEndpoints, ConnectionTester
  data/models/              hand-written DTOs (barrel: models.dart)
  data/repositories/        one repository + provider per API group (barrel: repositories.dart),
                            ledgerRevisionProvider, shared data providers
  features/<feature>/       screens; onboarding/ and settings/ are done, the rest are placeholders
  l10n/                     app_en.arb (template), app_zh.arb, generated AppLocalizations, l10n.dart (context.l10n)
```

## Data layer cheat sheet

| Need | Use |
|---|---|
| Active profile (name, colour, URL) | `ref.watch(activeProfileProvider)` |
| HTTP client | `ref.watch(zhangApiClientProvider)` (rarely needed directly) |
| Journals / create / update transaction | `journalRepositoryProvider` → `list(JournalQuery)`, `forNewTransaction()`, `create(req)`, `update(id, req)` |
| Accounts | `accountRepositoryProvider` → `list()`, `get(name)`, `journals(name)`, `balances(name)`, `documents(name)`, `addBalance(name, req)`, `addBalances(reqs)` |
| Reports | `statisticRepositoryProvider` → `summary(from, to)`, `graph(from, to)`, `rank(AccountType, from, to)` |
| Budgets | `budgetRepositoryProvider` → `list(year:, month:)`, `get(name, …)`, `interval(name, year, month)` |
| Commodities | `commodityRepositoryProvider` → `list()`, `get(name)`; cached map: `commoditiesProvider` |
| Info / options / errors / reload | `ledgerRepositoryProvider`; cached: `serverInfoProvider`, `ledgerOptionsProvider` |
| Documents | `documentRepositoryProvider` → `list()`, `download(doc)` |
| Refetch everything | `ref.read(ledgerRevisionProvider.notifier).bump()` |

Rules the layer already encodes (do not re-implement): `{"data": …}` envelope unwrapping; errors are
always a sealed `ZhangApiException` (`ApiUnauthorized`, `ApiNotFound`, `ApiServerError`,
`ApiNetworkError`, `ApiParseError`); amounts are `Decimal` (parsed from strings incl. `1E-8`, sent as
strings); response datetimes are naive ledger-local wall-clock `DateTime`s; request datetimes /
ranges are sent as RFC 3339 UTC; `narration`/`tags`/`links`/`metas` are always sent; repositories bump
`ledgerRevisionProvider` ~600 ms after each successful write (the server reloads asynchronously).

Gotchas worth knowing: transaction ids/sequences change on every reload (never persist them);
`AccountJournalEntry.trxId` from `/accounts/{name}/journals` is a posting id; tag/link journal filters
are applied client-side only (dart:io re-encodes the `[]` the server needs, see
`JournalRepository.list`); `calculated` amounts may be 0 for commodities without a direct price.

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
