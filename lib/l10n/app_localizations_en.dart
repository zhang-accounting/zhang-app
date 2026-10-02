// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zhang';

  @override
  String get tabHome => 'Home';

  @override
  String get tabJournal => 'Journal';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabAccounts => 'Accounts';

  @override
  String get newTransaction => 'New';

  @override
  String get newTransactionTitle => 'New transaction';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String activeLedger(String name) {
    return 'Ledger: $name';
  }

  @override
  String get onboardingTitle => 'Connect to your zhang server';

  @override
  String get onboardingSubtitle =>
      'Enter the address of your self-hosted zhang server. Credentials are stored securely on this device.';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileNameHint => 'e.g. Family ledger';

  @override
  String get serverUrlLabel => 'Server URL';

  @override
  String get serverUrlHint => 'https://ledger.example.com';

  @override
  String get serverUrlHelper =>
      'Without /api. http:// is allowed for local servers.';

  @override
  String get serverUrlRequired => 'Enter the server URL';

  @override
  String get serverUrlInvalid => 'Enter a valid http(s) URL';

  @override
  String get authTypeLabel => 'Authentication';

  @override
  String get authNone => 'None';

  @override
  String get authBasic => 'Basic';

  @override
  String get authBearer => 'Bearer';

  @override
  String get authHeaders => 'Headers';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get tokenLabel => 'Bearer token';

  @override
  String get headerNameLabel => 'Header name';

  @override
  String get headerValueLabel => 'Value';

  @override
  String get addHeader => 'Add header';

  @override
  String get removeHeader => 'Remove header';

  @override
  String get showSecret => 'Show';

  @override
  String get hideSecret => 'Hide';

  @override
  String get allowSelfSignedLabel => 'Allow self-signed certificate';

  @override
  String get allowSelfSignedHelp => 'Only enable this for servers you trust.';

  @override
  String get colorLabel => 'Colour';

  @override
  String get colorDefault => 'Default';

  @override
  String get testConnection => 'Test connection';

  @override
  String get testingConnection => 'Testing…';

  @override
  String connectionOk(String title) {
    return 'Connected to “$title”';
  }

  @override
  String connectionOkDetail(String version, String buildDate) {
    return 'zhang $version · built $buildDate';
  }

  @override
  String get untitledLedger => 'Untitled ledger';

  @override
  String get save => 'Save';

  @override
  String get saveAndContinue => 'Save and continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Retry';

  @override
  String get errorUnauthorized =>
      'Authentication failed (401). Check your credentials.';

  @override
  String get errorNotFound => 'Not found (404).';

  @override
  String errorServer(int status, String message) {
    return 'Server error $status: $message';
  }

  @override
  String get errorNetwork =>
      'Cannot reach the server. Check the URL and your network.';

  @override
  String get errorTimeout => 'The server did not respond in time.';

  @override
  String get errorCertificate =>
      'The server\'s TLS certificate was rejected. Enable “Allow self-signed certificate” if you trust it.';

  @override
  String get errorParse =>
      'Unexpected response. Is this the address of a zhang server?';

  @override
  String errorUnknown(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String get serversSection => 'Servers';

  @override
  String get addServer => 'Add server';

  @override
  String get editServer => 'Edit server';

  @override
  String get activeBadge => 'Active';

  @override
  String switchedTo(String name) {
    return 'Switched to $name';
  }

  @override
  String get deleteServerTitle => 'Delete server?';

  @override
  String deleteServerMessage(String name) {
    return '“$name” and its saved credentials will be removed from this device.';
  }

  @override
  String get aboutSection => 'About';

  @override
  String get appVersion => 'App version';

  @override
  String get serverVersion => 'Server version';

  @override
  String get ledgerTitle => 'Ledger';

  @override
  String get saved => 'Saved';

  @override
  String get accountsNetWorth => 'Net worth';

  @override
  String get accountsAssets => 'Assets';

  @override
  String get accountsLiabilities => 'Liabilities';

  @override
  String get accountsIncome => 'Income';

  @override
  String get accountsExpenses => 'Expenses';

  @override
  String get accountsEquity => 'Equity';

  @override
  String accountsNetWorthSource(String currency) {
    return 'Sum of account balances in $currency';
  }

  @override
  String accountsNotInTotal(String commodities) {
    return 'Not in total (no price): $commodities';
  }

  @override
  String get accountsSearch => 'Search accounts';

  @override
  String get accountsSearchHint => 'Name or alias';

  @override
  String get accountsCloseSearch => 'Close search';

  @override
  String get accountsShowClosed => 'Show closed accounts';

  @override
  String accountsClosedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count closed accounts hidden',
      one: '1 closed account hidden',
    );
    return '$_temp0';
  }

  @override
  String get accountsClosedBadge => 'Closed';

  @override
  String get accountsOpenBadge => 'Open';

  @override
  String get accountsEmpty =>
      'No accounts yet. Add open directives to your ledger to see them here.';

  @override
  String accountsNoMatches(String query) {
    return 'No accounts match “$query”';
  }

  @override
  String get accountsExpand => 'Expand';

  @override
  String get accountsCollapse => 'Collapse';

  @override
  String get accountsShowCommodities => 'Show each currency';

  @override
  String get accountsHideCommodities => 'Hide currencies';

  @override
  String accountsOpened(String date) {
    return 'Opened $date';
  }

  @override
  String accountsConvertedTotal(String amount) {
    return '≈ $amount in total';
  }

  @override
  String get accountsBalanceHistory => 'Balance history';

  @override
  String get accountsNoBalanceHistory => 'No balance history yet';

  @override
  String get accountsTransactions => 'Transactions';

  @override
  String get accountsRunningBalance => 'Balance';

  @override
  String get accountsNoTransactions => 'No transactions for this account yet';

  @override
  String get accountsBalanceCheck => 'Balance check';

  @override
  String get accountsBalancePad => 'Balance pad';

  @override
  String get accountsCopyName => 'Copy account name';

  @override
  String get accountsNameCopied => 'Account name copied';

  @override
  String get reportsPeriodWeek => 'Week';

  @override
  String get reportsPeriodMonth => 'Month';

  @override
  String get reportsPeriodYear => 'Year';

  @override
  String get reportsPeriodCustom => 'Custom';

  @override
  String get reportsPreviousPeriod => 'Previous period';

  @override
  String get reportsNextPeriod => 'Next period';

  @override
  String get reportsPickRange => 'Select a date range';

  @override
  String get reportsIncome => 'Income';

  @override
  String get reportsExpense => 'Expense';

  @override
  String get reportsNet => 'Net';

  @override
  String get reportsCashflowTitle => 'Income & expense';

  @override
  String get reportsNoData => 'No data for this period';

  @override
  String get reportsBreakdownTitle => 'Breakdown';

  @override
  String get reportsExpenses => 'Expenses';

  @override
  String get reportsIncomeSegment => 'Income';

  @override
  String get reportsOther => 'Other';

  @override
  String get reportsTotal => 'Total';

  @override
  String get reportsNoExpenses => 'No expenses in this period';

  @override
  String get reportsNoIncome => 'No income in this period';

  @override
  String get reportsUpOneLevel => 'Up one level';

  @override
  String get reportsShowSubAccounts => 'Show sub-accounts';

  @override
  String get reportsOpenAccount => 'Open account';
}
