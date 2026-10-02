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

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your zhang server'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your self-hosted zhang server. Credentials are stored securely on this device.'**
  String get onboardingSubtitle;

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

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

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
