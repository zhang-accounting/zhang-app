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
  /// **'{file} · byte {offset}'**
  String homeErrorLocation(String file, int offset);

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
