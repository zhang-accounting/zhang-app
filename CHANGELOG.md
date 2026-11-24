# Changelog

All notable changes to zhang-app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version is `version:` in `pubspec.yaml`; store build
numbers are not part of it (CI sets them from the workflow run number, see `docs/ci.md`). Short store notes for each
release live in `docs/release-notes/`.

## [1.1.0] - Unreleased

To ship with zhang 0.3.0. Replace "Unreleased" with the date when `v1.1.0` is tagged.

### Server compatibility

- Needs zhang 0.3.0 or newer, or a build of zhang's `main` branch from 2026-10-10 on: the app uses the v0.2 API
  (built-in queries, `format` in `/api/info`). The zhang 0.2.0 release (2026-10-02) predates that API, so the app
  refuses it as too old, as 1.0.0 did.
- With zhang 0.3.0 (or `main` from 2026-11-20 on) browser sign-in uses PKCE and `state`, and edits are checked
  against the transaction's `version` with `If-Match`. `main` builds from 2026-10-10 to 2026-11-20 still work:
  sign-in runs without PKCE, and an edit re-reads the transaction by id before it is saved.
- Deleting a transaction (#16), **View** after a save (#14) and idempotent saves (#12) need zhang 0.3.0, or a `main`
  build from 2026-11-20 on (zhang #818, #831). Older servers get no Delete and no View, and ignore the
  `Idempotency-Key`, so there a retried save can still record a transaction twice.

### Upgrading from the 1.0.0 APK on Android

1.1.0 is a **separate app** on Android. Its application id is now `com.zhangaccounting.app` (1.0.0 was
`me.kilerd.zhang_app`) and it is signed with the release upload key instead of the debug key (#2), so it does not
update the 1.0.0 APK: it installs next to it, under the same name "Zhang", and starts with no servers. Server
profiles, passwords and tokens stay in the old app, and 1.0.0 cannot export them. To move over:

1. In the old app, note each server's address and how you sign in (Settings).
2. Uninstall the old app (its Settings › App version shows 1.0.0). Do this first: while both apps are installed,
   both answer the `zhang-app://` browser sign-in callback.
3. Install 1.1.0 and add your servers again.

iOS (TestFlight) updates in place. Later APKs from GitHub Releases update 1.1.0 in place.

### Added

- Budgets in Reports: a Budgets segment lists the month's budgets by category with assigned, spent and available
  amounts, a progress bar, over-budget warnings, and the days and amount per day left in the current month, with a
  totals card per currency and a budget detail showing linked accounts and the month's history. (#4)
- Documents: account detail lists the documents of the account and its sub-accounts, transaction detail its
  attachments, and Accounts › ⋯ › Documents the whole ledger's. Images open in a zoomable viewer; other files open or
  share through the system share sheet. Files over 50 MB are not downloaded. (#4)
- Advanced editor for transactions with any number of postings, each with a cost, price and comment, plus flag,
  tags, links and metadata. One posting may be left empty for the server to balance, postings can be reordered, and
  a bar shows what is left to balance per commodity. Open it from the Advanced segment of the record sheet. (#5)
- Edit a transaction, or copy it as a new one, from its detail. Transactions that fit the simple form open there,
  the rest in the advanced editor; fields the form does not show are kept. Edits the server cannot write back without
  losing something (comment lines, plugin-made postings, posting flags) are blocked with an explanation. (#5)
- Delete a transaction from its detail (⋮ › Delete, after a confirmation that names it). The app sends the
  transaction's version (`If-Match`), so a transaction that changed on the server since it was listed is not deleted:
  "Changed on the server" offers to refresh the list instead. There is no undo. Offered only on servers that version
  transactions (zhang 0.3). (#16)
- After a save, the snackbar offers **View**, which opens the transaction just recorded: in the Home tab when it was
  recorded from Home, in the Journal tab otherwise. Shown when the server answers the new transaction's id
  (zhang 0.3). (#14)
- Step-by-step server setup: a welcome screen with a demo server, an address step that explains what it found
  (unreachable, certificate error, not a zhang server, too old), a sign-in step that offers only what the server
  supports, and a summary of the ledger before you start. Edit server in Settings is a compact form. (#3)

### Changed

- Browser sign-in sends a PKCE (`S256`) challenge and a `state` and checks the `state` it gets back, so another app
  that catches the `zhang-app://` callback cannot use the code. Once a server has reported `app_login_pkce`, the app
  refuses a callback from it without `state`. (#6)
- On servers that version transactions, a transaction changed on the server since you opened it is reported as
  changed instead of being overwritten (`If-Match`, 412). (#5)
- Saves are idempotent: every save sends an `Idempotency-Key`, and every retry of that save (after a timeout or a
  dropped connection, "Save anyway", or a fix of what the server refused) sends the same key, so the server records
  the transaction once. "Save and add another" starts a new key. The server keeps the key as the transaction's
  `idempotency-key` metadata, so each transaction recorded from the app has that extra line in the ledger file; the
  app does not show it, and edits keep it. (#12)
- Custom headers are sent together with the sign-in method: a profile behind a gateway such as Cloudflare Access can
  send the gateway's headers and also sign in to zhang with a password, a token or the browser. The setup wizard
  continues to zhang's sign-in once the gateway lets the headers through. Existing profiles are migrated and send
  the same headers as before. A custom `Authorization` header is only allowed with "No sign-in". (#13)
- Redirects are no longer followed, because the custom headers (such as `CF-Access-Client-Secret`) would go to the
  redirect's target too: a redirect asks for the final address, and one to a sign-in gateway's login page says so.
  (#13)
- Credentials over plain `http://` need an explicit opt-in: a profile that sends a sign-in method or custom headers
  over http to anything but this device (`localhost`, loopback addresses; LAN addresses are not exempt) needs "Send my
  credentials over http anyway" in the setup or edit form, and shows a "Not encrypted" icon next to the ledger name.
  Existing http profiles keep working and are asked on their next save. (#15)
- Android: the application id is now `com.zhangaccounting.app`, as on iOS, and release builds are signed with the
  upload key, so 1.1.0 installs as a separate app (see "Upgrading from the 1.0.0 APK on Android"). (#2)

### Fixed

- Switching, editing or deleting the active server starts with empty data: no screen shows or saves the previous
  ledger's accounts or entries while the new one loads. (#7)
- A server that is too old receives only the version check; every other request is stopped with "server too old"
  instead of being sent. (#7)
- On the amount keypad, a digit after `=` starts a new number instead of extending the result (`3 − 5 =` then `20`
  gave `−20`); an operator continues the calculation with the result. (#9)
- Income can be received on a liability account, such as a refund or cashback paid onto a credit card. (#10)
- Switching the currency re-checks the decimals already typed, so `12.34` typed in CNY can no longer be saved as
  JPY: the hint under the amount says what to remove, and Save waits until it is removed. (#11)
- The "server too old" messages ask for zhang 0.3 or newer. They asked for zhang 0.2, but the 0.2.0 release lacks
  the API the app needs.

## [1.0.0] - 2026-10-13

First release, on TestFlight (builds 11 and 13); Android APKs only as CI artifacts.

### Added

- Server profiles with no auth, HTTP Basic, Bearer, custom headers or browser sign-in (passkey or password on the
  server's login page). Secrets are kept in the Keychain / Keystore; a connection test checks the server first.
- Home (month summary, recent entries, ledger errors, reload-failure banner), Journal (by month or day, filters,
  balance assertions), transaction detail, a record sheet (expense / income / transfer, keypad, categories, server
  preview before saving), Accounts (tree, net worth, account detail with balance history) and Reports (period, KPIs,
  bars, category donut with drill-down).
- Refresh when the ledger reloads on the server (server-sent events).
- Needs the zhang v0.2 API; older servers are refused as too old.

[1.1.0]: https://github.com/zhang-accounting/zhang-app/compare/19b63a382c22665574f68a80cac5bb841ead076f...v1.1.0
[1.0.0]: https://github.com/zhang-accounting/zhang-app/tree/19b63a382c22665574f68a80cac5bb841ead076f
