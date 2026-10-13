import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Zhang'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get tabJournal;

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @tabAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get tabAccounts;

  /// Label of the centre FAB that records a new transaction
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newTransaction;

  /// No description provided for @newTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get newTransactionTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @activeLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger: {name}'**
  String activeLedger(String name);

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Family ledger'**
  String get profileNameHint;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrlLabel;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://ledger.example.com'**
  String get serverUrlHint;

  /// No description provided for @serverUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Without /api. http:// is allowed for local servers.'**
  String get serverUrlHelper;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the server URL'**
  String get serverUrlRequired;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) URL'**
  String get serverUrlInvalid;

  /// No description provided for @authTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authTypeLabel;

  /// No description provided for @authNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get authNone;

  /// No description provided for @authBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get authBasic;

  /// No description provided for @authBearer.
  ///
  /// In en, this message translates to:
  /// **'Bearer'**
  String get authBearer;

  /// No description provided for @authHeaders.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get authHeaders;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @tokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get tokenLabel;

  /// No description provided for @headerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Header name'**
  String get headerNameLabel;

  /// No description provided for @headerValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get headerValueLabel;

  /// No description provided for @addHeader.
  ///
  /// In en, this message translates to:
  /// **'Add header'**
  String get addHeader;

  /// No description provided for @removeHeader.
  ///
  /// In en, this message translates to:
  /// **'Remove header'**
  String get removeHeader;

  /// No description provided for @showSecret.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showSecret;

  /// No description provided for @hideSecret.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideSecret;

  /// No description provided for @allowSelfSignedLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow self-signed certificate'**
  String get allowSelfSignedLabel;

  /// No description provided for @allowSelfSignedHelp.
  ///
  /// In en, this message translates to:
  /// **'Only enable this for servers you trust.'**
  String get allowSelfSignedHelp;

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colorLabel;

  /// No description provided for @colorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get colorDefault;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get testingConnection;

  /// No description provided for @connectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connected to “{title}”'**
  String connectionOk(String title);

  /// No description provided for @connectionOkDetail.
  ///
  /// In en, this message translates to:
  /// **'zhang {version} · built {buildDate}'**
  String connectionOkDetail(String version, String buildDate);

  /// No description provided for @untitledLedger.
  ///
  /// In en, this message translates to:
  /// **'Untitled ledger'**
  String get untitledLedger;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed (401). Check your credentials.'**
  String get errorUnauthorized;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found (404).'**
  String get errorNotFound;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error {status}: {message}'**
  String errorServer(int status, String message);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check the URL and your network.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server did not respond in time.'**
  String get errorTimeout;

  /// No description provided for @errorCertificate.
  ///
  /// In en, this message translates to:
  /// **'The server\'s TLS certificate was rejected. Enable “Allow self-signed certificate” if you trust it.'**
  String get errorCertificate;

  /// No description provided for @errorParse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response. Is this the address of a zhang server?'**
  String get errorParse;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String errorUnknown(String message);

  /// No description provided for @errorServerTooOld.
  ///
  /// In en, this message translates to:
  /// **'This zhang server is too old: zhang ≥ 0.2 with the built-in query API is required. Upgrade the server.'**
  String get errorServerTooOld;

  /// No description provided for @errorPasskeyOnly.
  ///
  /// In en, this message translates to:
  /// **'This server only allows passkey sign-in, which the app cannot use. Enable password sign-in on the server (ZHANG_AUTH or --auth user:pass).'**
  String get errorPasskeyOnly;

  /// No description provided for @errorApiMismatch.
  ///
  /// In en, this message translates to:
  /// **'The server does not offer this API ({message}). The app needs zhang ≥ 0.2.'**
  String errorApiMismatch(String message);

  /// No description provided for @serverTooOldTitle.
  ///
  /// In en, this message translates to:
  /// **'Server too old'**
  String get serverTooOldTitle;

  /// No description provided for @serverTooOldVersion.
  ///
  /// In en, this message translates to:
  /// **'The server reports version {version}.'**
  String serverTooOldVersion(String version);

  /// No description provided for @serversSection.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get serversSection;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @editServer.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServer;

  /// No description provided for @activeBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeBadge;

  /// No description provided for @switchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String switchedTo(String name);

  /// No description provided for @deleteServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete server?'**
  String get deleteServerTitle;

  /// No description provided for @deleteServerMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and its saved credentials will be removed from this device.'**
  String deleteServerMessage(String name);

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @serverVersion.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get serverVersion;

  /// No description provided for @ledgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledgerTitle;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @addModeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get addModeExpense;

  /// No description provided for @addModeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get addModeIncome;

  /// No description provided for @addModeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get addModeTransfer;

  /// No description provided for @addClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get addClose;

  /// No description provided for @addSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Sub-category'**
  String get addSubcategory;

  /// No description provided for @addSubcategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get addSubcategoryRequired;

  /// No description provided for @addNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No open {root} accounts. Add an open directive to your ledger first.'**
  String addNoCategories(String root);

  /// No description provided for @addFundingExpense.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get addFundingExpense;

  /// No description provided for @addFundingIncome.
  ///
  /// In en, this message translates to:
  /// **'Deposit to'**
  String get addFundingIncome;

  /// No description provided for @addFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get addFrom;

  /// No description provided for @addTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get addTo;

  /// No description provided for @addSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap accounts'**
  String get addSwap;

  /// No description provided for @addChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get addChooseAccount;

  /// No description provided for @addPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get addPayee;

  /// No description provided for @addNarration.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get addNarration;

  /// No description provided for @addTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get addTags;

  /// No description provided for @addTagHint.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get addTagHint;

  /// No description provided for @addTagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addTagAdd;

  /// No description provided for @addDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get addDone;

  /// No description provided for @addToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get addToday;

  /// No description provided for @addDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get addDate;

  /// Keypad key: save and keep the screen open for another entry
  ///
  /// In en, this message translates to:
  /// **'Save & new'**
  String get addSaveAndAnother;

  /// No description provided for @addSaveAndAnotherLabel.
  ///
  /// In en, this message translates to:
  /// **'Save and add another'**
  String get addSaveAndAnotherLabel;

  /// No description provided for @addEvaluate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get addEvaluate;

  /// No description provided for @addBackspace.
  ///
  /// In en, this message translates to:
  /// **'Backspace (long-press to clear)'**
  String get addBackspace;

  /// No description provided for @addPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get addPlus;

  /// No description provided for @addMinus.
  ///
  /// In en, this message translates to:
  /// **'Minus'**
  String get addMinus;

  /// No description provided for @addDecimalPoint.
  ///
  /// In en, this message translates to:
  /// **'Decimal point'**
  String get addDecimalPoint;

  /// No description provided for @addHintAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get addHintAmount;

  /// No description provided for @addHintAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'The amount must be greater than 0'**
  String get addHintAmountPositive;

  /// No description provided for @addHintCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get addHintCategory;

  /// No description provided for @addHintSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a sub-category'**
  String get addHintSubcategory;

  /// No description provided for @addHintFunding.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get addHintFunding;

  /// No description provided for @addHintFrom.
  ///
  /// In en, this message translates to:
  /// **'Choose the source account'**
  String get addHintFrom;

  /// No description provided for @addHintTo.
  ///
  /// In en, this message translates to:
  /// **'Choose the destination account'**
  String get addHintTo;

  /// No description provided for @addHintSameAccount.
  ///
  /// In en, this message translates to:
  /// **'Source and destination must differ'**
  String get addHintSameAccount;

  /// No description provided for @addHintCommodity.
  ///
  /// In en, this message translates to:
  /// **'Loading the ledger currency…'**
  String get addHintCommodity;

  /// No description provided for @addSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Recorded {amount} · {title}'**
  String addSavedSnack(String amount, String title);

  /// No description provided for @addSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved} other{{count} saved}}'**
  String addSavedCount(int count);

  /// No description provided for @addSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save'**
  String get addSaveFailed;

  /// No description provided for @addPreviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Not saved – the ledger would report:'**
  String get addPreviewRejected;

  /// No description provided for @addPreviewUnbalanced.
  ///
  /// In en, this message translates to:
  /// **'The postings do not balance (off by {amounts}).'**
  String addPreviewUnbalanced(String amounts);

  /// No description provided for @addPreviewAccountMissing.
  ///
  /// In en, this message translates to:
  /// **'Account {account} is not open.'**
  String addPreviewAccountMissing(String account);

  /// No description provided for @addPreviewAccountClosed.
  ///
  /// In en, this message translates to:
  /// **'Account {account} is closed.'**
  String addPreviewAccountClosed(String account);

  /// No description provided for @addPreviewWarning.
  ///
  /// In en, this message translates to:
  /// **'The ledger would report (the entry is not saved yet):'**
  String get addPreviewWarning;

  /// No description provided for @addSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get addSaveAnyway;

  /// No description provided for @addPreviewCommodityUndeclared.
  ///
  /// In en, this message translates to:
  /// **'Commodity {commodity} is not declared in the ledger.'**
  String addPreviewCommodityUndeclared(String commodity);

  /// No description provided for @addPreviewCommodityNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Account {account} does not list {commodity} in its open directive.'**
  String addPreviewCommodityNotAllowed(String account, String commodity);

  /// No description provided for @addDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this entry?'**
  String get addDiscardTitle;

  /// No description provided for @addDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'What you entered will be lost.'**
  String get addDiscardMessage;

  /// No description provided for @addDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get addDiscard;

  /// No description provided for @addKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get addKeepEditing;

  /// No description provided for @addLastAmount.
  ///
  /// In en, this message translates to:
  /// **'Last: {amount}'**
  String addLastAmount(String amount);

  /// No description provided for @addCommodity.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get addCommodity;

  /// No description provided for @addPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search name, alias or segment'**
  String get addPickerSearch;

  /// No description provided for @addPickerFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get addPickerFavourites;

  /// No description provided for @addPickerRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get addPickerRecent;

  /// No description provided for @addPickerAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get addPickerAll;

  /// No description provided for @addPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching accounts'**
  String get addPickerEmpty;

  /// No description provided for @addPickerStarHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press an account to star it'**
  String get addPickerStarHint;

  /// No description provided for @addPickerStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get addPickerStarred;

  /// No description provided for @addTypeAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get addTypeAssets;

  /// No description provided for @addTypeLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get addTypeLiabilities;

  /// No description provided for @addTypeEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get addTypeEquity;

  /// No description provided for @addTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get addTypeIncome;

  /// No description provided for @addTypeExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get addTypeExpenses;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get homeExpense;

  /// No description provided for @homeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get homeIncome;

  /// No description provided for @homeNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get homeNet;

  /// No description provided for @homePreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get homePreviousMonth;

  /// No description provided for @homeNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get homeNextMonth;

  /// No description provided for @homeRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get homeRecentTitle;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeEmptyLedger.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Tap + to record your first one.'**
  String get homeEmptyLedger;

  /// No description provided for @homeErrorCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String homeErrorCount(int count);

  /// No description provided for @homeErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger errors'**
  String get homeErrorsTitle;

  /// No description provided for @homeErrorsMore.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String homeErrorsMore(int shown, int total);

  /// No description provided for @homeErrorLocation.
  ///
  /// In en, this message translates to:
  /// **'{file}:{line}'**
  String homeErrorLocation(String file, int line);

  /// No description provided for @homeAuthBanner.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the saved credentials.'**
  String get homeAuthBanner;

  /// No description provided for @homeAuthUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get homeAuthUpdate;

  /// No description provided for @homeReloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The ledger failed to reload. The server still shows the previous version until the files are fixed.'**
  String get homeReloadFailed;

  /// No description provided for @homeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get homeLoadFailed;

  /// No description provided for @journalFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get journalFilterAll;

  /// No description provided for @journalKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get journalKindExpense;

  /// No description provided for @journalKindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get journalKindIncome;

  /// No description provided for @journalKindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get journalKindTransfer;

  /// No description provided for @journalKindCompound.
  ///
  /// In en, this message translates to:
  /// **'Compound'**
  String get journalKindCompound;

  /// No description provided for @journalKindAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get journalKindAdjustment;

  /// No description provided for @journalKindRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get journalKindRefund;

  /// No description provided for @journalBalanceCheck.
  ///
  /// In en, this message translates to:
  /// **'Balance check'**
  String get journalBalanceCheck;

  /// No description provided for @journalBalancePad.
  ///
  /// In en, this message translates to:
  /// **'Balance pad'**
  String get journalBalancePad;

  /// No description provided for @journalBalanceFailed.
  ///
  /// In en, this message translates to:
  /// **'Balance check failed'**
  String get journalBalanceFailed;

  /// No description provided for @journalPadTarget.
  ///
  /// In en, this message translates to:
  /// **'to {amount}'**
  String journalPadTarget(String amount);

  /// No description provided for @trxBalanceActual.
  ///
  /// In en, this message translates to:
  /// **'Actual balance {amount}'**
  String trxBalanceActual(String amount);

  /// No description provided for @trxBalanceDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference {amount}'**
  String trxBalanceDifference(String amount);

  /// No description provided for @accountsSubAccount.
  ///
  /// In en, this message translates to:
  /// **'in {account}'**
  String accountsSubAccount(String account);

  /// No description provided for @journalSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get journalSearch;

  /// No description provided for @journalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Payee, narration, account, tag…'**
  String get journalSearchHint;

  /// No description provided for @journalCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get journalCloseSearch;

  /// No description provided for @journalTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get journalTags;

  /// No description provided for @journalTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by tag'**
  String get journalTagsTitle;

  /// No description provided for @journalNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags in the loaded transactions.'**
  String get journalNoTags;

  /// No description provided for @journalRemoveTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag filter {tag}'**
  String journalRemoveTag(String tag);

  /// No description provided for @journalMonthExpense.
  ///
  /// In en, this message translates to:
  /// **'Exp {amount}'**
  String journalMonthExpense(String amount);

  /// No description provided for @journalMonthIncome.
  ///
  /// In en, this message translates to:
  /// **'Inc {amount}'**
  String journalMonthIncome(String amount);

  /// No description provided for @journalToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get journalToday;

  /// No description provided for @journalYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get journalYesterday;

  /// No description provided for @journalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get journalEmpty;

  /// No description provided for @journalEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to record your first one.'**
  String get journalEmptyHint;

  /// No description provided for @journalNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions'**
  String get journalNoMatch;

  /// No description provided for @journalClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get journalClearFilters;

  /// No description provided for @journalLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more'**
  String get journalLoadMoreFailed;

  /// No description provided for @journalUnbalanced.
  ///
  /// In en, this message translates to:
  /// **'Unbalanced'**
  String get journalUnbalanced;

  /// No description provided for @journalPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get journalPending;

  /// No description provided for @journalAttachment.
  ///
  /// In en, this message translates to:
  /// **'Has attachments'**
  String get journalAttachment;

  /// No description provided for @trxTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get trxTitle;

  /// No description provided for @trxPostings.
  ///
  /// In en, this message translates to:
  /// **'Postings'**
  String get trxPostings;

  /// No description provided for @trxDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get trxDetails;

  /// No description provided for @trxDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get trxDate;

  /// No description provided for @trxFlag.
  ///
  /// In en, this message translates to:
  /// **'Flag'**
  String get trxFlag;

  /// No description provided for @trxTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get trxTags;

  /// No description provided for @trxLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get trxLinks;

  /// No description provided for @trxMetas.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get trxMetas;

  /// No description provided for @trxAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get trxAuto;

  /// No description provided for @trxWritten.
  ///
  /// In en, this message translates to:
  /// **'written {amount}'**
  String trxWritten(String amount);

  /// No description provided for @trxCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy as text'**
  String get trxCopyText;

  /// No description provided for @trxCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get trxCopied;

  /// No description provided for @trxNotFound.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found. Ids change when the ledger reloads – open it again from the list.'**
  String get trxNotFound;

  /// No description provided for @trxUnbalanced.
  ///
  /// In en, this message translates to:
  /// **'This transaction does not balance.'**
  String get trxUnbalanced;

  /// No description provided for @trxFilterByTag.
  ///
  /// In en, this message translates to:
  /// **'Show transactions tagged #{tag}'**
  String trxFilterByTag(String tag);

  /// No description provided for @accountsNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get accountsNetWorth;

  /// No description provided for @accountsAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get accountsAssets;

  /// No description provided for @accountsLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get accountsLiabilities;

  /// No description provided for @accountsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get accountsIncome;

  /// No description provided for @accountsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get accountsExpenses;

  /// No description provided for @accountsEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get accountsEquity;

  /// No description provided for @accountsNetWorthSource.
  ///
  /// In en, this message translates to:
  /// **'Sum of account balances in {currency}'**
  String accountsNetWorthSource(String currency);

  /// No description provided for @accountsNotInTotal.
  ///
  /// In en, this message translates to:
  /// **'Not in total (no price): {commodities}'**
  String accountsNotInTotal(String commodities);

  /// No description provided for @accountsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search accounts'**
  String get accountsSearch;

  /// No description provided for @accountsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name or alias'**
  String get accountsSearchHint;

  /// No description provided for @accountsCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get accountsCloseSearch;

  /// No description provided for @accountsShowClosed.
  ///
  /// In en, this message translates to:
  /// **'Show closed accounts'**
  String get accountsShowClosed;

  /// No description provided for @accountsClosedHidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 closed account hidden} other{{count} closed accounts hidden}}'**
  String accountsClosedHidden(int count);

  /// No description provided for @accountsClosedBadge.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get accountsClosedBadge;

  /// No description provided for @accountsOpenBadge.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get accountsOpenBadge;

  /// No description provided for @accountsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Add open directives to your ledger to see them here.'**
  String get accountsEmpty;

  /// No description provided for @accountsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No accounts match “{query}”'**
  String accountsNoMatches(String query);

  /// No description provided for @accountsExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get accountsExpand;

  /// No description provided for @accountsCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get accountsCollapse;

  /// No description provided for @accountsShowCommodities.
  ///
  /// In en, this message translates to:
  /// **'Show each currency'**
  String get accountsShowCommodities;

  /// No description provided for @accountsHideCommodities.
  ///
  /// In en, this message translates to:
  /// **'Hide currencies'**
  String get accountsHideCommodities;

  /// No description provided for @accountsOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened {date}'**
  String accountsOpened(String date);

  /// No description provided for @accountsConvertedTotal.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount} in total'**
  String accountsConvertedTotal(String amount);

  /// No description provided for @accountsBalanceHistory.
  ///
  /// In en, this message translates to:
  /// **'Balance history'**
  String get accountsBalanceHistory;

  /// No description provided for @accountsNoBalanceHistory.
  ///
  /// In en, this message translates to:
  /// **'No balance history yet'**
  String get accountsNoBalanceHistory;

  /// No description provided for @accountsTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get accountsTransactions;

  /// No description provided for @accountsRunningBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountsRunningBalance;

  /// No description provided for @accountsNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this account yet'**
  String get accountsNoTransactions;

  /// No description provided for @accountsBalanceCheck.
  ///
  /// In en, this message translates to:
  /// **'Balance check'**
  String get accountsBalanceCheck;

  /// No description provided for @accountsBalancePad.
  ///
  /// In en, this message translates to:
  /// **'Balance pad'**
  String get accountsBalancePad;

  /// No description provided for @accountsCopyName.
  ///
  /// In en, this message translates to:
  /// **'Copy account name'**
  String get accountsCopyName;

  /// No description provided for @accountsNameCopied.
  ///
  /// In en, this message translates to:
  /// **'Account name copied'**
  String get accountsNameCopied;

  /// No description provided for @reportsPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get reportsPeriodWeek;

  /// No description provided for @reportsPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportsPeriodMonth;

  /// No description provided for @reportsPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get reportsPeriodYear;

  /// No description provided for @reportsPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get reportsPeriodCustom;

  /// No description provided for @reportsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get reportsPreviousPeriod;

  /// No description provided for @reportsNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get reportsNextPeriod;

  /// No description provided for @reportsPickRange.
  ///
  /// In en, this message translates to:
  /// **'Select a date range'**
  String get reportsPickRange;

  /// No description provided for @reportsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get reportsIncome;

  /// No description provided for @reportsExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get reportsExpense;

  /// No description provided for @reportsNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get reportsNet;

  /// No description provided for @reportsCashflowTitle.
  ///
  /// In en, this message translates to:
  /// **'Income & expense'**
  String get reportsCashflowTitle;

  /// No description provided for @reportsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get reportsNoData;

  /// No description provided for @reportsBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get reportsBreakdownTitle;

  /// No description provided for @reportsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportsExpenses;

  /// No description provided for @reportsIncomeSegment.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get reportsIncomeSegment;

  /// No description provided for @reportsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportsOther;

  /// No description provided for @reportsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportsTotal;

  /// No description provided for @reportsNoExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this period'**
  String get reportsNoExpenses;

  /// No description provided for @reportsNoIncome.
  ///
  /// In en, this message translates to:
  /// **'No income in this period'**
  String get reportsNoIncome;

  /// No description provided for @reportsUpOneLevel.
  ///
  /// In en, this message translates to:
  /// **'Up one level'**
  String get reportsUpOneLevel;

  /// No description provided for @reportsShowSubAccounts.
  ///
  /// In en, this message translates to:
  /// **'Show sub-accounts'**
  String get reportsShowSubAccounts;

  /// No description provided for @reportsOpenAccount.
  ///
  /// In en, this message translates to:
  /// **'Open account'**
  String get reportsOpenAccount;

  /// Auth type segment: sign in on the server's login page in the system browser
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get authSession;

  /// No description provided for @authSessionHelper.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a passkey or password in the browser'**
  String get authSessionHelper;

  /// No description provided for @signInWithBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sign in with browser'**
  String get signInWithBrowser;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out of {name}'**
  String signedOut(String name);

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {user}, valid until {date}'**
  String signedInAs(String user, String date);

  /// No description provided for @signedInSnack.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {user}'**
  String signedInSnack(String user);

  /// Settings: signed-in user and session expiry of a browser sign-in server
  ///
  /// In en, this message translates to:
  /// **'{user} · until {date}'**
  String sessionSubtitle(String user, String date);

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @signInFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the browser first.'**
  String get signInFirst;

  /// No description provided for @signInNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'This server does not require sign-in. Choose “No sign-in” instead.'**
  String get signInNotNeeded;

  /// No description provided for @signInNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support app sign-in yet; upgrade zhang (PR #786).'**
  String get signInNotSupported;

  /// No description provided for @signInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get signInCancelled;

  /// No description provided for @signInBrowserFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser for sign-in.'**
  String get signInBrowserFailed;

  /// No description provided for @signInMalformedCallback.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid sign-in response.'**
  String get signInMalformedCallback;

  /// No description provided for @signInCodeRejected.
  ///
  /// In en, this message translates to:
  /// **'The sign-in expired or was already used. Sign in again.'**
  String get signInCodeRejected;

  /// No description provided for @signInRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Try again in {seconds} s.'**
  String signInRateLimited(int seconds);

  /// No description provided for @signInRateLimitedLater.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Try again later.'**
  String get signInRateLimitedLater;

  /// No description provided for @homeSessionBanner.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has ended. Sign in again in the browser.'**
  String get homeSessionBanner;

  /// No description provided for @homeSessionExpiring.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in expires on {date}. Sign in again to stay connected.'**
  String homeSessionExpiring(String date);

  /// No description provided for @errorPasskeyOnlyBrowser.
  ///
  /// In en, this message translates to:
  /// **'This server only allows passkey sign-in. Choose “Browser sign-in” to sign in with a passkey.'**
  String get errorPasskeyOnlyBrowser;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Your plain-text books, in your pocket.'**
  String get welcomeTagline;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to the zhang server you host to check balances and record spending on the go.'**
  String get welcomeBody;

  /// No description provided for @welcomeWhatIsZhang.
  ///
  /// In en, this message translates to:
  /// **'What is a zhang server?'**
  String get welcomeWhatIsZhang;

  /// No description provided for @welcomeAboutBody.
  ///
  /// In en, this message translates to:
  /// **'zhang is open-source, self-hosted accounting that keeps your books as plain-text files you own. You run the server yourself, with Docker or a single binary, and this app connects to it. The app needs zhang 0.2 or newer.'**
  String get welcomeAboutBody;

  /// No description provided for @welcomeReadDocs.
  ///
  /// In en, this message translates to:
  /// **'Read the docs'**
  String get welcomeReadDocs;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @welcomeConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to your server'**
  String get welcomeConnect;

  /// No description provided for @welcomeTryDemo.
  ///
  /// In en, this message translates to:
  /// **'Try the demo'**
  String get welcomeTryDemo;

  /// No description provided for @welcomeDemoCaption.
  ///
  /// In en, this message translates to:
  /// **'The demo is a fictional, read-only ledger hosted by the zhang project.'**
  String get welcomeDemoCaption;

  /// No description provided for @welcomeDemoWaking.
  ///
  /// In en, this message translates to:
  /// **'Waking up the demo server. This can take up to a minute.'**
  String get welcomeDemoWaking;

  /// No description provided for @setupStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String setupStep(int step, int total);

  /// No description provided for @setupServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Where is your server?'**
  String get setupServerTitle;

  /// No description provided for @setupServerBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the address you open zhang at in your browser.'**
  String get setupServerBody;

  /// No description provided for @setupUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get setupUrlLabel;

  /// No description provided for @setupUrlHint.
  ///
  /// In en, this message translates to:
  /// **'ledger.example.com or 192.168.1.10:8000'**
  String get setupUrlHint;

  /// No description provided for @setupPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get setupPaste;

  /// No description provided for @setupUrlNormalized.
  ///
  /// In en, this message translates to:
  /// **'Connects to {url}'**
  String setupUrlNormalized(String url);

  /// No description provided for @setupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// No description provided for @setupChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get setupChecking;

  /// No description provided for @setupTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get setupTryAgain;

  /// No description provided for @setupHintReach.
  ///
  /// In en, this message translates to:
  /// **'Check the address and the port, and that this phone can reach the server (same Wi-Fi or VPN).'**
  String get setupHintReach;

  /// No description provided for @setupHttpHint.
  ///
  /// In en, this message translates to:
  /// **'No scheme was entered, so https:// was used. Servers on your own network often use http://.'**
  String get setupHttpHint;

  /// No description provided for @setupTryHttp.
  ///
  /// In en, this message translates to:
  /// **'Use {url}'**
  String setupTryHttp(String url);

  /// No description provided for @setupNotZhang.
  ///
  /// In en, this message translates to:
  /// **'It answered, but not like a zhang server. Use the address of the zhang web UI, without /api.'**
  String get setupNotZhang;

  /// No description provided for @setupBehindGateway.
  ///
  /// In en, this message translates to:
  /// **'It is behind a sign-in gateway'**
  String get setupBehindGateway;

  /// No description provided for @setupTooOldTitle.
  ///
  /// In en, this message translates to:
  /// **'This server needs an update'**
  String get setupTooOldTitle;

  /// No description provided for @setupTooOldBody.
  ///
  /// In en, this message translates to:
  /// **'It runs zhang {version} without the API this app uses. Upgrade the server to zhang 0.2 or newer, then try again.'**
  String setupTooOldBody(String version);

  /// No description provided for @setupHowToUpgrade.
  ///
  /// In en, this message translates to:
  /// **'How to upgrade'**
  String get setupHowToUpgrade;

  /// No description provided for @setupSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {ledger}'**
  String setupSignInTitle(String ledger);

  /// No description provided for @setupSignInTitleUntitled.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get setupSignInTitleUntitled;

  /// No description provided for @setupSignInBody.
  ///
  /// In en, this message translates to:
  /// **'{host} asks you to sign in.'**
  String setupSignInBody(String host);

  /// No description provided for @setupBrowserStep1.
  ///
  /// In en, this message translates to:
  /// **'Your server\'s sign-in page opens in a secure browser window.'**
  String get setupBrowserStep1;

  /// No description provided for @setupBrowserStep2.
  ///
  /// In en, this message translates to:
  /// **'Sign in there with a passkey or your password. The app keeps only a sign-in token, never your password.'**
  String get setupBrowserStep2;

  /// No description provided for @setupWaitingBrowser.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the browser…'**
  String get setupWaitingBrowser;

  /// No description provided for @setupUsePassword.
  ///
  /// In en, this message translates to:
  /// **'Use username and password'**
  String get setupUsePassword;

  /// No description provided for @setupUseBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sign in with browser instead'**
  String get setupUseBrowser;

  /// No description provided for @setupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get setupSignIn;

  /// No description provided for @setupPasskeyOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'This server only accepts passkeys'**
  String get setupPasskeyOnlyTitle;

  /// No description provided for @setupPasskeyOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'The app signs in with a passkey through the server\'s sign-in page, and this zhang version cannot hand the sign-in back to the app. Upgrade the server, or turn on password sign-in.'**
  String get setupPasskeyOnlyBody;

  /// No description provided for @setupCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get setupCheckAgain;

  /// No description provided for @setupCredentialsUnknown.
  ///
  /// In en, this message translates to:
  /// **'The server asks for credentials.'**
  String get setupCredentialsUnknown;

  /// No description provided for @setupGatewayBody.
  ///
  /// In en, this message translates to:
  /// **'Something in front of zhang, such as a reverse proxy, asks for credentials. Enter them under “Reverse proxy or gateway”.'**
  String get setupGatewayBody;

  /// No description provided for @setupAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse proxy or gateway'**
  String get setupAdvancedTitle;

  /// No description provided for @setupAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bearer token or custom headers'**
  String get setupAdvancedSubtitle;

  /// No description provided for @setupConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get setupConnect;

  /// No description provided for @setupSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {user}'**
  String setupSignedInAs(String user);

  /// No description provided for @setupConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get setupConnected;

  /// No description provided for @setupReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re connected'**
  String get setupReadyTitle;

  /// No description provided for @setupReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Name this ledger and pick a colour. You can change both later in Settings.'**
  String get setupReadyBody;

  /// No description provided for @setupFactCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get setupFactCurrency;

  /// No description provided for @setupFactAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get setupFactAccounts;

  /// No description provided for @setupFactAccountsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 open} other{{count} open}}'**
  String setupFactAccountsValue(int count);

  /// No description provided for @setupFactServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get setupFactServer;

  /// No description provided for @setupFactSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get setupFactSignedIn;

  /// No description provided for @setupFactSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign-in'**
  String get setupFactSignIn;

  /// No description provided for @setupFactNoSignIn.
  ///
  /// In en, this message translates to:
  /// **'Not needed'**
  String get setupFactNoSignIn;

  /// No description provided for @setupFactUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not read the ledger details. You can still start.'**
  String get setupFactUnavailable;

  /// No description provided for @setupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name on this device'**
  String get setupNameLabel;

  /// No description provided for @setupDemoNote.
  ///
  /// In en, this message translates to:
  /// **'This is the zhang demo, a read-only ledger: browsing works, new entries are not saved.'**
  String get setupDemoNote;

  /// No description provided for @setupStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get setupStart;

  /// No description provided for @profileSectionServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get profileSectionServer;

  /// No description provided for @profileSectionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign-in'**
  String get profileSectionSignIn;

  /// No description provided for @profileSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileSectionAppearance;

  /// No description provided for @authMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign-in method'**
  String get authMethodLabel;

  /// No description provided for @authNoneLong.
  ///
  /// In en, this message translates to:
  /// **'No sign-in'**
  String get authNoneLong;

  /// No description provided for @authBasicLong.
  ///
  /// In en, this message translates to:
  /// **'Username and password'**
  String get authBasicLong;

  /// No description provided for @authSessionLong.
  ///
  /// In en, this message translates to:
  /// **'Browser sign-in (passkey or password)'**
  String get authSessionLong;

  /// No description provided for @authBearerLong.
  ///
  /// In en, this message translates to:
  /// **'Bearer token (reverse proxy)'**
  String get authBearerLong;

  /// No description provided for @authHeadersLong.
  ///
  /// In en, this message translates to:
  /// **'Custom headers (reverse proxy)'**
  String get authHeadersLong;

  /// No description provided for @setupProxyHeaders.
  ///
  /// In en, this message translates to:
  /// **'Custom headers'**
  String get setupProxyHeaders;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
