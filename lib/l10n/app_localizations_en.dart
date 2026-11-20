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
  String get editTransactionTitle => 'Edit transaction';

  @override
  String get advTitle => 'New transaction (advanced)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String activeLedger(String name) {
    return 'Ledger: $name';
  }

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
  String get errorServerTooOld =>
      'This zhang server is too old: zhang ≥ 0.2 with the built-in query API is required. Upgrade the server.';

  @override
  String get errorPasskeyOnly =>
      'This server only allows passkey sign-in, which the app cannot use. Enable password sign-in on the server (ZHANG_AUTH or --auth user:pass).';

  @override
  String errorApiMismatch(String message) {
    return 'The server does not offer this API ($message). The app needs zhang ≥ 0.2.';
  }

  @override
  String get serverTooOldTitle => 'Server too old';

  @override
  String serverTooOldVersion(String version) {
    return 'The server reports version $version.';
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
  String get addModeExpense => 'Expense';

  @override
  String get addModeIncome => 'Income';

  @override
  String get addModeTransfer => 'Transfer';

  @override
  String get addModeAdvanced => 'Advanced';

  @override
  String get addClose => 'Close';

  @override
  String get addSubcategory => 'Sub-category';

  @override
  String get addSubcategoryRequired => 'required';

  @override
  String addNoCategories(String root) {
    return 'No open $root accounts. Add an open directive to your ledger first.';
  }

  @override
  String get addFundingExpense => 'Paid from';

  @override
  String get addFundingIncome => 'Deposit to';

  @override
  String get addFrom => 'From';

  @override
  String get addTo => 'To';

  @override
  String get addSwap => 'Swap accounts';

  @override
  String get addChooseAccount => 'Choose account';

  @override
  String get addPayee => 'Payee';

  @override
  String get addNarration => 'Note';

  @override
  String get addTags => 'Tags';

  @override
  String get addTagHint => 'New tag';

  @override
  String get addTagAdd => 'Add';

  @override
  String get addDone => 'Done';

  @override
  String get addToday => 'Today';

  @override
  String get addDate => 'Date';

  @override
  String get addSaveAndAnother => 'Save & new';

  @override
  String get addSaveAndAnotherLabel => 'Save and add another';

  @override
  String get addEvaluate => 'Calculate';

  @override
  String get addBackspace => 'Backspace (long-press to clear)';

  @override
  String get addPlus => 'Plus';

  @override
  String get addMinus => 'Minus';

  @override
  String get addDecimalPoint => 'Decimal point';

  @override
  String get addHintAmount => 'Enter an amount';

  @override
  String get addHintAmountPositive => 'The amount must be greater than 0';

  @override
  String get addHintCategory => 'Choose a category';

  @override
  String get addHintSubcategory => 'Choose a sub-category';

  @override
  String get addHintFunding => 'Choose an account';

  @override
  String get addHintFrom => 'Choose the source account';

  @override
  String get addHintTo => 'Choose the destination account';

  @override
  String get addHintSameAccount => 'Source and destination must differ';

  @override
  String get addHintCommodity => 'Loading the ledger currency…';

  @override
  String addSavedSnack(String amount, String title) {
    return 'Recorded $amount · $title';
  }

  @override
  String addSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved',
      one: '1 saved',
    );
    return '$_temp0';
  }

  @override
  String get editSavedSnack => 'Changes saved';

  @override
  String get addSaveFailed => 'Could not save';

  @override
  String get editStale =>
      'This transaction changed on the server since it was opened (its id is out of date or it was edited elsewhere). Go back, refresh the list and open it again.';

  @override
  String get editRequoteTitle => 'Metadata will be saved as text';

  @override
  String get editRequoteMessage =>
      'The server keeps metadata values without quotes (numbers, dates) only on a posting whose account is unchanged. These will be saved in quotes, as text:';

  @override
  String get addPreviewRejected => 'Not saved – the ledger would report:';

  @override
  String addPreviewUnbalanced(String amounts) {
    return 'The postings do not balance (off by $amounts).';
  }

  @override
  String addPreviewAccountMissing(String account) {
    return 'Account $account is not open.';
  }

  @override
  String addPreviewAccountClosed(String account) {
    return 'Account $account is closed.';
  }

  @override
  String get addPreviewWarning =>
      'The ledger would report (the entry is not saved yet):';

  @override
  String get addSaveAnyway => 'Save anyway';

  @override
  String addPreviewCommodityUndeclared(String commodity) {
    return 'Commodity $commodity is not declared in the ledger.';
  }

  @override
  String addPreviewCommodityNotAllowed(String account, String commodity) {
    return 'Account $account does not list $commodity in its open directive.';
  }

  @override
  String get addDiscardTitle => 'Discard this entry?';

  @override
  String get addDiscardMessage => 'What you entered will be lost.';

  @override
  String get addDiscard => 'Discard';

  @override
  String get addKeepEditing => 'Keep editing';

  @override
  String addLastAmount(String amount) {
    return 'Last: $amount';
  }

  @override
  String get addCommodity => 'Currency';

  @override
  String get addPickerSearch => 'Search name, alias or segment';

  @override
  String get addPickerFavourites => 'Favourites';

  @override
  String get addPickerRecent => 'Recent';

  @override
  String get addPickerAll => 'All';

  @override
  String get addPickerEmpty => 'No matching accounts';

  @override
  String get addPickerStarHint => 'Long-press an account to star it';

  @override
  String get addPickerStarred => 'Starred';

  @override
  String get addTypeAssets => 'Assets';

  @override
  String get addTypeLiabilities => 'Liabilities';

  @override
  String get addTypeEquity => 'Equity';

  @override
  String get addTypeIncome => 'Income';

  @override
  String get addTypeExpenses => 'Expenses';

  @override
  String get advAccount => 'Posting account';

  @override
  String get advAuto => 'empty = auto-balance';

  @override
  String advAutoTakes(String amounts) {
    return 'Empty amount takes $amounts';
  }

  @override
  String get advToggleSign => 'Toggle sign';

  @override
  String get advCost => 'Cost';

  @override
  String get advCostHint => 'e.g. 26000 USD';

  @override
  String get advPrice => 'Price';

  @override
  String get advPriceHint => 'e.g. 7.2 CNY';

  @override
  String get advComment => 'Comment';

  @override
  String get advMoreFields => 'Cost, price, comment';

  @override
  String get advMoveUp => 'Move up';

  @override
  String get advMoveDown => 'Move down';

  @override
  String get advRemovePosting => 'Remove posting';

  @override
  String get advAddPosting => 'Add posting';

  @override
  String get advAddMeta => 'Add metadata';

  @override
  String get advMetaKey => 'Key';

  @override
  String get advMetaValue => 'Value';

  @override
  String get advLinksHint => '^trip-2026, separated by spaces';

  @override
  String get advFlagComplete => 'Complete';

  @override
  String get advRemainder => 'Remainder';

  @override
  String get advBalanced => 'Balanced';

  @override
  String advUnbalancedBy(String amounts) {
    return 'Off by $amounts';
  }

  @override
  String get advBalanceUnknown =>
      'Checked by the server when saving (cost booked against lots)';

  @override
  String get advNeedsPrice =>
      'Several commodities: add a price or a cost to convert them, or leave one amount empty.';

  @override
  String get advIssuePostings => 'Add at least two postings';

  @override
  String get advIssueAccount => 'Choose an account for every posting';

  @override
  String get advIssueAmount => 'Not a number';

  @override
  String get advIssueAuto => 'Only one amount may be left empty';

  @override
  String get advIssueAutoCommodities =>
      'An empty amount can only balance one commodity: add a price or a cost, or fill in the amounts';

  @override
  String get advIssueUnbalanced => 'The postings do not balance';

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
  String homeErrorLocation(String file, int line) {
    return '$file:$line';
  }

  @override
  String get homeAuthBanner => 'The server rejected the saved credentials.';

  @override
  String get homeAuthUpdate => 'Update';

  @override
  String get homeReloadFailed =>
      'The ledger failed to reload. The server still shows the previous version until the files are fixed.';

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
  String journalPadTarget(String amount) {
    return 'to $amount';
  }

  @override
  String trxBalanceActual(String amount) {
    return 'Actual balance $amount';
  }

  @override
  String trxBalanceDifference(String amount) {
    return 'Difference $amount';
  }

  @override
  String accountsSubAccount(String account) {
    return 'in $account';
  }

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
  String get trxEdit => 'Edit';

  @override
  String get trxDuplicate => 'Copy as new transaction';

  @override
  String get trxEditBlockedTitle => 'This transaction can\'t be edited here';

  @override
  String get trxEditBlockedNotTransaction =>
      'Balance checks and pads can\'t be edited in the app.';

  @override
  String get trxEditBlockedUnknownShape =>
      'This server does not report everything an edit has to keep (posting metadata, comments). Update zhang to edit transactions in the app.';

  @override
  String get trxEditBlockedNotWritten =>
      'This transaction was made by a plugin, or its postings can\'t be read as they are written, so it can\'t be edited through the server.';

  @override
  String get trxEditBlockedDropsText =>
      'This transaction has comments in the ledger file (between its postings, on its first line or after metadata) that saving through the server would delete. Edit it in the ledger file instead.';

  @override
  String get trxEditBlockedPostingFlag =>
      'A posting of this transaction has its own flag (such as !). The server does not report posting flags, so an edit could drop it. Edit it in the ledger file instead.';

  @override
  String get trxEditBlockedUnverified =>
      'The server reports problems with this transaction as it is written, so the app can\'t check that an edit would keep everything. Fix it in the ledger file first.';

  @override
  String get trxEditCopyHint => 'You can still copy it as a new transaction.';

  @override
  String get trxRefreshing => 'Updating…';

  @override
  String get trxEditedNotFound =>
      'Saved. The updated transaction could not be found again – it may have moved. Open it again from the list.';

  @override
  String get trxEditedPending =>
      'Saved, but the server does not list the change yet. Open the transaction again from the list.';

  @override
  String get trxNotFound =>
      'Transaction not found. Ids change when the ledger reloads – open it again from the list.';

  @override
  String get trxUnbalanced => 'This transaction does not balance.';

  @override
  String trxFilterByTag(String tag) {
    return 'Show transactions tagged #$tag';
  }

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
  String get documentsTitle => 'Documents';

  @override
  String documentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String documentsShowAll(int count) {
    return 'Show all $count';
  }

  @override
  String get documentsEmpty =>
      'No documents in this ledger. They come from document directives and from document metadata on transactions.';

  @override
  String get documentsOfTransaction => 'Transaction attachment';

  @override
  String get documentsShare => 'Share';

  @override
  String get documentsOpenOrShare => 'Open or share';

  @override
  String get documentsOpenHint =>
      'Downloads the file and opens the share sheet, where you can open it in another app or save it.';

  @override
  String documentsTooLarge(int size) {
    return 'This file is larger than $size MB, too large to download on the phone.';
  }

  @override
  String get documentsNoPreview => 'No preview for this file type';

  @override
  String get documentsType => 'Type';

  @override
  String get documentsUnknownType => 'Unknown';

  @override
  String get documentsDate => 'Date';

  @override
  String get documentsAccount => 'Account';

  @override
  String get documentsAttachedTo => 'Belongs to';

  @override
  String get documentsPath => 'Path';

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

  @override
  String get reportsSegmentFlows => 'Income & expense';

  @override
  String get reportsSegmentBudgets => 'Budgets';

  @override
  String get budgetsPreviousMonth => 'Previous month';

  @override
  String get budgetsNextMonth => 'Next month';

  @override
  String get budgetsAssigned => 'Assigned';

  @override
  String get budgetsActivity => 'Activity';

  @override
  String get budgetsAvailable => 'Available';

  @override
  String get budgetsUncategorized => 'Uncategorized';

  @override
  String get budgetsClosed => 'Closed';

  @override
  String get budgetsOver => 'Over budget';

  @override
  String budgetsOverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets over',
      one: '1 budget over',
    );
    return '$_temp0';
  }

  @override
  String budgetsDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left this month',
      one: 'Last day of the month',
    );
    return '$_temp0';
  }

  @override
  String budgetsSpentOf(String spent, String assigned) {
    return 'Spent $spent of $assigned';
  }

  @override
  String budgetsOverBy(String amount) {
    return 'Over budget by $amount';
  }

  @override
  String budgetsPerDay(String amount) {
    return '≈ $amount a day';
  }

  @override
  String get budgetsProgressLabel => 'Share of the assigned money spent';

  @override
  String budgetsEmptyTitle(String month) {
    return 'No budgets in $month';
  }

  @override
  String get budgetsEmptyBody =>
      'Budgets are written in the ledger: a budget directive creates one, budget-add assigns money to it for a month, and a budget metadata on an open links an expense account to it.';

  @override
  String get budgetsReadOnly =>
      'The app shows budgets; change them in the ledger file.';

  @override
  String get budgetsAssignedHint =>
      'Assigned includes what was left (or overspent) last month.';

  @override
  String get budgetsLinkedAccounts => 'Linked accounts';

  @override
  String get budgetsNoLinkedAccounts =>
      'No account is linked: add a budget metadata to an open directive.';

  @override
  String budgetsHistory(String month) {
    return 'Assigned and spent in $month';
  }

  @override
  String budgetsNoHistory(String month) {
    return 'Nothing assigned or spent in $month';
  }

  @override
  String get budgetsEventAssigned => 'Assigned';

  @override
  String get budgetsEventMovedOut => 'Moved to another budget';

  @override
  String get budgetsEventMovedIn => 'Moved from another budget';

  @override
  String get authSession => 'Browser';

  @override
  String get authSessionHelper =>
      'Sign in with a passkey or password in the browser';

  @override
  String get signInWithBrowser => 'Sign in with browser';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get signOut => 'Sign out';

  @override
  String signedOut(String name) {
    return 'Signed out of $name';
  }

  @override
  String signedInAs(String user, String date) {
    return 'Signed in as $user, valid until $date';
  }

  @override
  String signedInSnack(String user) {
    return 'Signed in as $user';
  }

  @override
  String sessionSubtitle(String user, String date) {
    return '$user · until $date';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get signInFirst => 'Sign in with the browser first.';

  @override
  String get signInNotNeeded =>
      'This server does not require sign-in. Choose “No sign-in” instead.';

  @override
  String get signInNotSupported =>
      'This server does not support app sign-in yet; upgrade zhang (PR #786).';

  @override
  String get signInCancelled => 'Sign-in was cancelled.';

  @override
  String get signInBrowserFailed => 'Could not open the browser for sign-in.';

  @override
  String get signInMalformedCallback =>
      'The server returned an invalid sign-in response.';

  @override
  String get signInStateMismatch =>
      'The browser returned a sign-in this app did not start, so it was not used. Sign in again.';

  @override
  String get signInCodeRejected =>
      'The sign-in expired or was already used. Sign in again.';

  @override
  String signInRateLimited(int seconds) {
    return 'Too many sign-in attempts. Try again in $seconds s.';
  }

  @override
  String get signInRateLimitedLater =>
      'Too many sign-in attempts. Try again later.';

  @override
  String get homeSessionBanner =>
      'Your sign-in has ended. Sign in again in the browser.';

  @override
  String homeSessionExpiring(String date) {
    return 'Your sign-in expires on $date. Sign in again to stay connected.';
  }

  @override
  String get errorPasskeyOnlyBrowser =>
      'This server only allows passkey sign-in. Choose “Browser sign-in” to sign in with a passkey.';

  @override
  String get welcomeTagline => 'Your plain-text books, in your pocket.';

  @override
  String get welcomeBody =>
      'Connect to the zhang server you host to check balances and record spending on the go.';

  @override
  String get welcomeWhatIsZhang => 'What is a zhang server?';

  @override
  String get welcomeAboutBody =>
      'zhang is open-source, self-hosted accounting that keeps your books as plain-text files you own. You run the server yourself, with Docker or a single binary, and this app connects to it. The app needs zhang 0.2 or newer.';

  @override
  String get welcomeReadDocs => 'Read the docs';

  @override
  String get close => 'Close';

  @override
  String get welcomeConnect => 'Connect to your server';

  @override
  String get welcomeTryDemo => 'Try the demo';

  @override
  String get welcomeDemoCaption =>
      'The demo is a fictional, read-only ledger hosted by the zhang project.';

  @override
  String get welcomeDemoWaking =>
      'Waking up the demo server. This can take up to a minute.';

  @override
  String setupStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get setupServerTitle => 'Where is your server?';

  @override
  String get setupServerBody =>
      'Enter the address you open zhang at in your browser.';

  @override
  String get setupUrlLabel => 'Server address';

  @override
  String get setupUrlHint => 'ledger.example.com or 192.168.1.10:8000';

  @override
  String get setupPaste => 'Paste';

  @override
  String setupUrlNormalized(String url) {
    return 'Connects to $url';
  }

  @override
  String get setupContinue => 'Continue';

  @override
  String get setupChecking => 'Checking…';

  @override
  String get setupTryAgain => 'Try again';

  @override
  String get setupHintReach =>
      'Check the address and the port, and that this phone can reach the server (same Wi-Fi or VPN).';

  @override
  String get setupSchemeHintHttps =>
      'No scheme was entered, so https:// was used. Servers on your own network often use http://.';

  @override
  String get setupSchemeHintHttp =>
      'No scheme was entered, so http:// was used for this local address. Use https:// if the server has a certificate.';

  @override
  String setupTryUrl(String url) {
    return 'Use $url';
  }

  @override
  String get setupNotZhang =>
      'It answered, but not like a zhang server. Use the address of the zhang web UI, without /api.';

  @override
  String get setupBehindGateway => 'It is behind a sign-in gateway';

  @override
  String get setupTooOldTitle => 'This server needs an update';

  @override
  String setupTooOldBody(String version) {
    return 'It runs zhang $version without the API this app uses. Upgrade the server to zhang 0.2 or newer, then try again.';
  }

  @override
  String get setupHowToUpgrade => 'How to upgrade';

  @override
  String setupSignInTitle(String ledger) {
    return 'Sign in to $ledger';
  }

  @override
  String get setupSignInTitleUntitled => 'Sign in';

  @override
  String setupSignInBody(String host) {
    return '$host asks you to sign in.';
  }

  @override
  String get setupBrowserStep1 =>
      'Your server\'s sign-in page opens in a secure browser window.';

  @override
  String get setupBrowserStep2 =>
      'Sign in there with a passkey or your password. The app keeps only a sign-in token, never your password.';

  @override
  String get setupWaitingBrowser => 'Waiting for the browser…';

  @override
  String get setupUsePassword => 'Use username and password';

  @override
  String get setupUseBrowser => 'Sign in with browser instead';

  @override
  String get setupSignIn => 'Sign in';

  @override
  String get setupPasskeyOnlyTitle => 'This server only accepts passkeys';

  @override
  String get setupPasskeyOnlyBody =>
      'The app signs in with a passkey through the server\'s sign-in page, and this zhang version cannot hand the sign-in back to the app. Upgrade the server, or turn on password sign-in.';

  @override
  String get setupCheckAgain => 'Check again';

  @override
  String get setupCredentialsUnknown => 'The server asks for credentials.';

  @override
  String get setupGatewayBody =>
      'Something in front of zhang, such as a reverse proxy, asks for credentials. Enter them under “Reverse proxy or gateway”.';

  @override
  String get setupAdvancedTitle => 'Reverse proxy or gateway';

  @override
  String get setupAdvancedSubtitle => 'Bearer token or custom headers';

  @override
  String get setupConnect => 'Connect';

  @override
  String setupSignedInAs(String user) {
    return 'Signed in as $user';
  }

  @override
  String get setupConnected => 'Connected';

  @override
  String get setupReadyTitle => 'You\'re connected';

  @override
  String get setupReadyBody =>
      'Name this ledger and pick a colour. You can change both later in Settings.';

  @override
  String get setupFactCurrency => 'Currency';

  @override
  String get setupFactAccounts => 'Accounts';

  @override
  String setupFactAccountsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open',
      one: '1 open',
    );
    return '$_temp0';
  }

  @override
  String get setupFactServer => 'Server';

  @override
  String get setupFactSignedIn => 'Signed in as';

  @override
  String get setupFactSignIn => 'Sign-in';

  @override
  String get setupFactNoSignIn => 'Not needed';

  @override
  String get setupFactUnavailable =>
      'Could not read the ledger details. You can still start.';

  @override
  String get setupNameLabel => 'Name on this device';

  @override
  String get setupDemoNote =>
      'This is the zhang demo, a read-only ledger: browsing works, new entries are not saved.';

  @override
  String get setupStart => 'Start';

  @override
  String get profileSectionServer => 'Server';

  @override
  String get profileSectionSignIn => 'Sign-in';

  @override
  String get profileSectionAppearance => 'Appearance';

  @override
  String get authMethodLabel => 'Sign-in method';

  @override
  String get authNoneLong => 'No sign-in';

  @override
  String get authBasicLong => 'Username and password';

  @override
  String get authSessionLong => 'Browser sign-in (passkey or password)';

  @override
  String get authBearerLong => 'Bearer token (reverse proxy)';

  @override
  String get authHeadersLong => 'Custom headers (reverse proxy)';

  @override
  String get setupProxyHeaders => 'Custom headers';

  @override
  String get setupUnreachable => 'Cannot reach the server';
}
