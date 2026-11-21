# Changelog

All notable changes to zhang-app are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version is `version:` in `pubspec.yaml`; store build
numbers are not part of it (CI sets them from the workflow run number, see `docs/ci.md`). Short store notes for each
release live in `docs/release-notes/`.

## [1.1.0] - Unreleased

To ship with zhang 0.3.0. Replace "Unreleased" with the date when `v1.1.0` is tagged.

### Server compatibility

- Needs a zhang server with the v0.2 API (built-in queries, `format` in `/api/info`): zhang 0.3.0 or later, or a
  build of zhang's `main` branch from 2026-10-10 on. The zhang 0.2.0 release (2026-10-02) predates that API, so the
  app refuses it as too old, as 1.0.0 did.
- With zhang 0.3.0 (or `main` from 2026-11-20 on) browser sign-in uses PKCE and `state`, and edits are checked
  against the transaction's `version` with `If-Match`. Older v0.2 API builds still work: sign-in runs without PKCE,
  and an edit re-reads the transaction by id before it is saved.
- zhang 0.3.0 can also delete transactions and replay a create with an `Idempotency-Key`; this release uses neither.

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
- Step-by-step server setup: a welcome screen with a demo server, an address step that explains what it found
  (unreachable, certificate error, not a zhang server, too old), a sign-in step that offers only what the server
  supports, and a summary of the ledger before you start. Edit server in Settings is a compact form. (#3)

### Changed

- Browser sign-in sends a PKCE (`S256`) challenge and a `state` and checks the `state` it gets back, so another app
  that catches the `zhang-app://` callback cannot use the code. Once a server has reported `app_login_pkce`, the app
  refuses a callback from it without `state`. (#6)
- On servers that version transactions, a transaction changed on the server since you opened it is reported as
  changed instead of being overwritten (`If-Match`, 412). (#5)
- Android: the application id is now `com.zhangaccounting.app`, as on iOS, and release builds are signed with the
  upload key. The 1.0.0 APK had another id and the debug key, so 1.1.0 installs as a separate app: add your servers
  again, then remove the old app. (#2)

### Fixed

- Switching, editing or deleting the active server starts with empty data: no screen shows or saves the previous
  ledger's accounts or entries while the new one loads. (#7)
- A server that is too old receives only the version check; every other request is stopped with "server too old"
  instead of being sent. (#7)

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
