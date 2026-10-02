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
  String get homeExpense => 'Expenses';

  @override
  String get homeIncome => 'Income';

  @override
  String get homeNet => 'Net';

  @override
  String get homePreviousMonth => 'Previous month';

  @override
  String get homeNextMonth => 'Next month';

  @override
  String get homeRecentTitle => 'Recent transactions';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeEmptyLedger =>
      'No transactions yet. Tap + to record your first one.';

  @override
  String homeErrorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String get homeErrorsTitle => 'Ledger errors';

  @override
  String homeErrorsMore(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String homeErrorLocation(String file, int offset) {
    return '$file · byte $offset';
  }

  @override
  String get homeAuthBanner => 'The server rejected the saved credentials.';

  @override
  String get homeAuthUpdate => 'Update';

  @override
  String get homeLoadFailed => 'Failed to load';

  @override
  String get journalFilterAll => 'All';

  @override
  String get journalKindExpense => 'Expense';

  @override
  String get journalKindIncome => 'Income';

  @override
  String get journalKindTransfer => 'Transfer';

  @override
  String get journalKindCompound => 'Compound';

  @override
  String get journalKindAdjustment => 'Adjustment';

  @override
  String get journalKindRefund => 'Refund';

  @override
  String get journalBalanceCheck => 'Balance check';

  @override
  String get journalBalancePad => 'Balance pad';

  @override
  String get journalBalanceFailed => 'Balance check failed';

  @override
  String get journalSearch => 'Search';

  @override
  String get journalSearchHint => 'Payee, narration, account, tag…';

  @override
  String get journalCloseSearch => 'Close search';

  @override
  String get journalTags => 'Tags';

  @override
  String get journalTagsTitle => 'Filter by tag';

  @override
  String get journalNoTags => 'No tags in the loaded transactions.';

  @override
  String journalRemoveTag(String tag) {
    return 'Remove tag filter $tag';
  }

  @override
  String journalMonthExpense(String amount) {
    return 'Exp $amount';
  }

  @override
  String journalMonthIncome(String amount) {
    return 'Inc $amount';
  }

  @override
  String get journalToday => 'Today';

  @override
  String get journalYesterday => 'Yesterday';

  @override
  String get journalEmpty => 'No transactions yet';

  @override
  String get journalEmptyHint => 'Tap + to record your first one.';

  @override
  String get journalNoMatch => 'No matching transactions';

  @override
  String get journalClearFilters => 'Clear filters';

  @override
  String get journalLoadMoreFailed => 'Failed to load more';

  @override
  String get journalUnbalanced => 'Unbalanced';

  @override
  String get journalPending => 'Pending';

  @override
  String get journalAttachment => 'Has attachments';

  @override
  String get trxTitle => 'Transaction';

  @override
  String get trxPostings => 'Postings';

  @override
  String get trxDetails => 'Details';

  @override
  String get trxDate => 'Date';

  @override
  String get trxFlag => 'Flag';

  @override
  String get trxTags => 'Tags';

  @override
  String get trxLinks => 'Links';

  @override
  String get trxMetas => 'Metadata';

  @override
  String get trxAuto => 'auto';

  @override
  String trxWritten(String amount) {
    return 'written $amount';
  }

  @override
  String get trxCopyText => 'Copy as text';

  @override
  String get trxCopied => 'Copied to clipboard';

  @override
  String get trxNotFound =>
      'Transaction not found. Ids change when the ledger reloads – open it again from the list.';

  @override
  String get trxUnbalanced => 'This transaction does not balance.';

  @override
  String trxFilterByTag(String tag) {
    return 'Show transactions tagged #$tag';
  }
}
