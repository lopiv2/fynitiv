import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Jellyfinitive'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'THE DEFINITIVE EXPERIENCE'**
  String get splashTagline;

  /// No description provided for @whoIsWatching.
  ///
  /// In en, this message translates to:
  /// **'Who\'s watching?'**
  String get whoIsWatching;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://jellyfin.example.com'**
  String get serverUrlHint;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @configureServer.
  ///
  /// In en, this message translates to:
  /// **'Configure another server'**
  String get configureServer;

  /// No description provided for @manageHome.
  ///
  /// In en, this message translates to:
  /// **'Manage home'**
  String get manageHome;

  /// No description provided for @passwordFor.
  ///
  /// In en, this message translates to:
  /// **'Password for {name}'**
  String passwordFor(Object name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @enter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @whichServer.
  ///
  /// In en, this message translates to:
  /// **'Which server are you connecting to?'**
  String get whichServer;

  /// No description provided for @whoIsFromThisHome.
  ///
  /// In en, this message translates to:
  /// **'Who\'s from this home?'**
  String get whoIsFromThisHome;

  /// No description provided for @selectHouseholdUsers.
  ///
  /// In en, this message translates to:
  /// **'Mark the profiles used by the people of this home. Others won\'t appear here.'**
  String get selectHouseholdUsers;

  /// No description provided for @noPublicUsers.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t expose public users.'**
  String get noPublicUsers;

  /// No description provided for @homeName.
  ///
  /// In en, this message translates to:
  /// **'What\'s the name of this home?'**
  String get homeName;

  /// No description provided for @homeNameHint.
  ///
  /// In en, this message translates to:
  /// **'The Garcia Home'**
  String get homeNameHint;

  /// No description provided for @homeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Home name'**
  String get homeNameLabel;

  /// No description provided for @chooseHousePin.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN for this home'**
  String get chooseHousePin;

  /// No description provided for @changeHousePin.
  ///
  /// In en, this message translates to:
  /// **'Change the home PIN'**
  String get changeHousePin;

  /// No description provided for @leavePinBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave the PIN fields blank to keep the current one.'**
  String get leavePinBlank;

  /// No description provided for @pinProtectsHouse.
  ///
  /// In en, this message translates to:
  /// **'This PIN protects this home: it\'s required to manage or remove it.'**
  String get pinProtectsHouse;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPin;

  /// No description provided for @housePinRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the home PIN'**
  String get housePinRequired;

  /// No description provided for @masterPinHint.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN? Enter your recovery master PIN instead.'**
  String get masterPinHint;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN, try again'**
  String get wrongPin;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @householdStep.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get householdStep;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @couldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to the server'**
  String get couldNotConnect;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get yourLibrary;

  /// No description provided for @libraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Movies, series and more content will appear here.'**
  String get libraryDescription;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchDescription.
  ///
  /// In en, this message translates to:
  /// **'Search movies, series and people.'**
  String get searchDescription;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Server, account and preferences settings.'**
  String get settingsDescription;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatching;

  /// No description provided for @newReleases.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get newReleases;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search movies, series, people...'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currentHome.
  ///
  /// In en, this message translates to:
  /// **'Current home'**
  String get currentHome;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Jellyfinitive is a client for Jellyfin, your personal media server.'**
  String get aboutDescription;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userName;

  /// No description provided for @currentUser.
  ///
  /// In en, this message translates to:
  /// **'Current user'**
  String get currentUser;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Styles'**
  String get presets;

  /// No description provided for @colors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get colors;

  /// No description provided for @primaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get primaryColor;

  /// No description provided for @secondaryColor.
  ///
  /// In en, this message translates to:
  /// **'Secondary color'**
  String get secondaryColor;

  /// No description provided for @backgroundTopColor.
  ///
  /// In en, this message translates to:
  /// **'Background top'**
  String get backgroundTopColor;

  /// No description provided for @backgroundBottomColor.
  ///
  /// In en, this message translates to:
  /// **'Background bottom'**
  String get backgroundBottomColor;

  /// No description provided for @sidebarColor.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get sidebarColor;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @sidebarPosition.
  ///
  /// In en, this message translates to:
  /// **'Sidebar position'**
  String get sidebarPosition;

  /// No description provided for @logoPosition.
  ///
  /// In en, this message translates to:
  /// **'Logo position'**
  String get logoPosition;

  /// No description provided for @avatarPosition.
  ///
  /// In en, this message translates to:
  /// **'Avatar position'**
  String get avatarPosition;

  /// No description provided for @sidebarLogo.
  ///
  /// In en, this message translates to:
  /// **'Sidebar logo'**
  String get sidebarLogo;

  /// No description provided for @logoImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get logoImage;

  /// No description provided for @logoText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get logoText;

  /// No description provided for @chooseLogoImage.
  ///
  /// In en, this message translates to:
  /// **'Choose logo image'**
  String get chooseLogoImage;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @top.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get top;

  /// No description provided for @center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get center;

  /// No description provided for @bottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get bottom;

  /// No description provided for @cardRadius.
  ///
  /// In en, this message translates to:
  /// **'Card radius'**
  String get cardRadius;

  /// No description provided for @showContinueRow.
  ///
  /// In en, this message translates to:
  /// **'Show \'Continue watching\' row'**
  String get showContinueRow;

  /// No description provided for @showNewReleasesRow.
  ///
  /// In en, this message translates to:
  /// **'Show \'New releases\' row'**
  String get showNewReleasesRow;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @importExport.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get importExport;

  /// No description provided for @exportSkin.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportSkin;

  /// No description provided for @importSkin.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importSkin;

  /// No description provided for @skinCopied.
  ///
  /// In en, this message translates to:
  /// **'Skin copied to clipboard'**
  String get skinCopied;

  /// No description provided for @includedWithJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Included with Jellyfin'**
  String get includedWithJellyfin;

  /// No description provided for @watchNow.
  ///
  /// In en, this message translates to:
  /// **'Watch now'**
  String get watchNow;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
