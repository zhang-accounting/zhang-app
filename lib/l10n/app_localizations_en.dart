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
  String get addModeExpense => 'Expense';

  @override
  String get addModeIncome => 'Income';

  @override
  String get addModeTransfer => 'Transfer';

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
  String get addSaveFailed => 'Could not save';

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
}
