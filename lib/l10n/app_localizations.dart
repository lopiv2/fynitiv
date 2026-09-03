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
  /// **'Fynitiv'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Watch. Read. Play. Anything'**
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
  /// **'Add users with their username and password. No one will see the full server user list.'**
  String get selectHouseholdUsers;

  /// No description provided for @noPublicUsers.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t expose public users.'**
  String get noPublicUsers;

  /// No description provided for @noHouseholdMembers.
  ///
  /// In en, this message translates to:
  /// **'No users in this home yet. Tap Add user to add the first one.'**
  String get noHouseholdMembers;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @addUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Add user to home'**
  String get addUserTitle;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @removeUser.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeUser;

  /// No description provided for @addAtLeastOneUser.
  ///
  /// In en, this message translates to:
  /// **'Add at least one user to continue'**
  String get addAtLeastOneUser;

  /// No description provided for @userAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'That user is already in the home'**
  String get userAlreadyAdded;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get invalidCredentials;

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

  /// No description provided for @continuePlaying.
  ///
  /// In en, this message translates to:
  /// **'Continue playing'**
  String get continuePlaying;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

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
  /// **'Fynitiv is a client for Jellyfin, your personal media server.'**
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

  /// No description provided for @topBarFloating.
  ///
  /// In en, this message translates to:
  /// **'Floating island'**
  String get topBarFloating;

  /// No description provided for @topBarFloatingHint.
  ///
  /// In en, this message translates to:
  /// **'Shows the top bar as a floating pill with glass blur (radius 28), over the banner'**
  String get topBarFloatingHint;

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

  /// No description provided for @cardImageType.
  ///
  /// In en, this message translates to:
  /// **'Cards image type'**
  String get cardImageType;

  /// No description provided for @poster.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get poster;

  /// No description provided for @backdrop.
  ///
  /// In en, this message translates to:
  /// **'Backdrop'**
  String get backdrop;

  /// No description provided for @cardLogo.
  ///
  /// In en, this message translates to:
  /// **'Card logo'**
  String get cardLogo;

  /// No description provided for @cardLogoSize.
  ///
  /// In en, this message translates to:
  /// **'Logo size'**
  String get cardLogoSize;

  /// No description provided for @playerLogo.
  ///
  /// In en, this message translates to:
  /// **'Player logo'**
  String get playerLogo;

  /// No description provided for @playerLogoPosition.
  ///
  /// In en, this message translates to:
  /// **'Logo in player'**
  String get playerLogoPosition;

  /// No description provided for @audioWaveformEffect.
  ///
  /// In en, this message translates to:
  /// **'Audio waveform effect'**
  String get audioWaveformEffect;

  /// No description provided for @effectEqualizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get effectEqualizer;

  /// No description provided for @effectWave.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get effectWave;

  /// No description provided for @effectMirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get effectMirror;

  /// No description provided for @effectBars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get effectBars;

  /// No description provided for @effectSurfer.
  ///
  /// In en, this message translates to:
  /// **'Surfer'**
  String get effectSurfer;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @uploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get uploadLogo;

  /// No description provided for @topLeft.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get topLeft;

  /// No description provided for @topRight.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get topRight;

  /// No description provided for @bottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get bottomLeft;

  /// No description provided for @bottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get bottomRight;

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

  /// No description provided for @adFreeEasterEggButton.
  ///
  /// In en, this message translates to:
  /// **'Continue without ads'**
  String get adFreeEasterEggButton;

  /// No description provided for @adFreeEasterEggTitle.
  ///
  /// In en, this message translates to:
  /// **'You found the secret button!'**
  String get adFreeEasterEggTitle;

  /// No description provided for @adFreeEasterEggMessage.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin has no ads. So this button just gave you exactly what you already had: zero ads and a free smile.'**
  String get adFreeEasterEggMessage;

  /// No description provided for @adFreeEasterEggClose.
  ///
  /// In en, this message translates to:
  /// **'Keep enjoying'**
  String get adFreeEasterEggClose;

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

  /// No description provided for @watchTrailer.
  ///
  /// In en, this message translates to:
  /// **'Watch trailer'**
  String get watchTrailer;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start playback.'**
  String get playbackFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @subtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get subtitle;

  /// No description provided for @subtitlesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get subtitlesOff;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @vod.
  ///
  /// In en, this message translates to:
  /// **'VOD'**
  String get vod;

  /// No description provided for @liveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get liveTv;

  /// No description provided for @liveTvChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get liveTvChannels;

  /// No description provided for @liveTvGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get liveTvGuide;

  /// No description provided for @liveTvAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get liveTvAll;

  /// No description provided for @liveTvNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get liveTvNews;

  /// No description provided for @liveTvSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get liveTvSports;

  /// No description provided for @liveTvKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get liveTvKids;

  /// No description provided for @liveTvMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get liveTvMovies;

  /// No description provided for @liveTvSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get liveTvSeries;

  /// No description provided for @liveTvFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get liveTvFavorites;

  /// No description provided for @liveTvNow.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveTvNow;

  /// No description provided for @liveTvHd.
  ///
  /// In en, this message translates to:
  /// **'HD'**
  String get liveTvHd;

  /// No description provided for @liveTvSearch.
  ///
  /// In en, this message translates to:
  /// **'Search channels'**
  String get liveTvSearch;

  /// No description provided for @liveTvNowOnFynitiv.
  ///
  /// In en, this message translates to:
  /// **'NOW ON FYNITIV'**
  String get liveTvNowOnFynitiv;

  /// No description provided for @liveTvMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get liveTvMinimize;

  /// No description provided for @liveTvExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get liveTvExpand;

  /// No description provided for @liveTvClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get liveTvClose;

  /// No description provided for @liveTvMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get liveTvMute;

  /// No description provided for @liveTvUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get liveTvUnmute;

  /// No description provided for @liveTvSelectChannel.
  ///
  /// In en, this message translates to:
  /// **'Select a channel'**
  String get liveTvSelectChannel;

  /// No description provided for @liveTvNoAiring.
  ///
  /// In en, this message translates to:
  /// **'No program airing'**
  String get liveTvNoAiring;

  /// No description provided for @liveTvNoGuide.
  ///
  /// In en, this message translates to:
  /// **'No guide data available for the server'**
  String get liveTvNoGuide;

  /// No description provided for @liveTvNoChannels.
  ///
  /// In en, this message translates to:
  /// **'No channels available'**
  String get liveTvNoChannels;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music Player'**
  String get music;

  /// No description provided for @eReader.
  ///
  /// In en, this message translates to:
  /// **'E-Reader'**
  String get eReader;

  /// No description provided for @eReaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Books and comics from your Jellyfin library.'**
  String get eReaderDescription;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @actionMovies.
  ///
  /// In en, this message translates to:
  /// **'Action movies'**
  String get actionMovies;

  /// No description provided for @familyMovies.
  ///
  /// In en, this message translates to:
  /// **'Family & kids'**
  String get familyMovies;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See more >'**
  String get seeMore;

  /// No description provided for @allMovies.
  ///
  /// In en, this message translates to:
  /// **'All movies'**
  String get allMovies;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Online games'**
  String get games;

  /// No description provided for @gamesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your game library (ROMM)'**
  String get gamesSubtitle;

  /// No description provided for @gamesEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no platforms in the ROMM library.'**
  String get gamesEmpty;

  /// No description provided for @gamesNoServer.
  ///
  /// In en, this message translates to:
  /// **'No ROMM server is configured. Connect your game library to play online.'**
  String get gamesNoServer;

  /// No description provided for @gamesConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure server'**
  String get gamesConfigure;

  /// No description provided for @gamesConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'ROMM server'**
  String get gamesConfigTitle;

  /// No description provided for @gamesConfigSave.
  ///
  /// In en, this message translates to:
  /// **'Save and connect'**
  String get gamesConfigSave;

  /// No description provided for @gamesConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully'**
  String get gamesConfigSaved;

  /// No description provided for @gamesConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your details.'**
  String get gamesConfigFailed;

  /// No description provided for @gamesConfigRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in URL, username and password.'**
  String get gamesConfigRequired;

  /// No description provided for @gamesServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get gamesServerUrl;

  /// No description provided for @gamesUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get gamesUsername;

  /// No description provided for @gamesPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get gamesPassword;

  /// No description provided for @gamesConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get gamesConnected;

  /// No description provided for @gamesDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get gamesDisconnect;

  /// No description provided for @gamesPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get gamesPlay;

  /// No description provided for @gamesDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get gamesDownload;

  /// No description provided for @gamesNoStreaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming is not available for this game. Use Download.'**
  String get gamesNoStreaming;

  /// No description provided for @gamesNoFile.
  ///
  /// In en, this message translates to:
  /// **'This game has no downloadable file.'**
  String get gamesNoFile;

  /// No description provided for @gamesDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get gamesDownloaded;

  /// No description provided for @gamesLaunchError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the web player.'**
  String get gamesLaunchError;

  /// No description provided for @musicPlayerStyle.
  ///
  /// In en, this message translates to:
  /// **'Music Player styles'**
  String get musicPlayerStyle;

  /// No description provided for @musicPlayerStyleHint.
  ///
  /// In en, this message translates to:
  /// **'Only affects the Music Player (albums, lists and audio player). Does not change the sidebar.'**
  String get musicPlayerStyleHint;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

  /// No description provided for @madeForYou.
  ///
  /// In en, this message translates to:
  /// **'Made for you'**
  String get madeForYou;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @topAlbums.
  ///
  /// In en, this message translates to:
  /// **'Top albums'**
  String get topAlbums;

  /// No description provided for @newReleasesMusic.
  ///
  /// In en, this message translates to:
  /// **'New music'**
  String get newReleasesMusic;

  /// No description provided for @hotlist.
  ///
  /// In en, this message translates to:
  /// **'Hotlist'**
  String get hotlist;

  /// No description provided for @hiFiPicks.
  ///
  /// In en, this message translates to:
  /// **'HiFi picks'**
  String get hiFiPicks;

  /// No description provided for @noAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums'**
  String get noAlbums;

  /// No description provided for @trendingSongs.
  ///
  /// In en, this message translates to:
  /// **'Trending songs'**
  String get trendingSongs;

  /// No description provided for @popularArtists.
  ///
  /// In en, this message translates to:
  /// **'Popular artists'**
  String get popularArtists;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @chartSource.
  ///
  /// In en, this message translates to:
  /// **'Chart source'**
  String get chartSource;

  /// No description provided for @chartSourceJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin (local)'**
  String get chartSourceJellyfin;

  /// No description provided for @chartSourceDeezer.
  ///
  /// In en, this message translates to:
  /// **'Deezer (global)'**
  String get chartSourceDeezer;

  /// No description provided for @chartSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose whether the Music Player shows your local library or the global Deezer top chart.'**
  String get chartSourceHint;

  /// No description provided for @myPlaylists.
  ///
  /// In en, this message translates to:
  /// **'My playlists'**
  String get myPlaylists;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @populares.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get populares;

  /// No description provided for @monthlyListeners.
  ///
  /// In en, this message translates to:
  /// **'{count} monthly listeners'**
  String monthlyListeners(Object count);

  /// No description provided for @noPlayableSongs.
  ///
  /// In en, this message translates to:
  /// **'No playable songs currently'**
  String get noPlayableSongs;

  /// No description provided for @deezerSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Deezer suggestions'**
  String get deezerSuggestions;

  /// No description provided for @recentIn.
  ///
  /// In en, this message translates to:
  /// **'Recent in {library}'**
  String recentIn(String library);

  /// No description provided for @titleMarquee.
  ///
  /// In en, this message translates to:
  /// **'Title marquee on hover'**
  String get titleMarquee;

  /// No description provided for @titleMarqueeHint.
  ///
  /// In en, this message translates to:
  /// **'When the title overflows, it scrolls left in a loop while hovering (like Jellyfin Android TV)'**
  String get titleMarqueeHint;

  /// No description provided for @platforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get platforms;

  /// No description provided for @sounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds;

  /// No description provided for @selectionSound.
  ///
  /// In en, this message translates to:
  /// **'Item selection sound'**
  String get selectionSound;

  /// No description provided for @selectionSoundHint.
  ///
  /// In en, this message translates to:
  /// **'Sound played when hovering or focusing an item (uses system volume)'**
  String get selectionSoundHint;

  /// No description provided for @testSound.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testSound;

  /// No description provided for @soundsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get soundsSectionTitle;

  /// No description provided for @soundsSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Hover and selection feedback sounds'**
  String get soundsSectionDescription;

  /// No description provided for @backgroundMusic.
  ///
  /// In en, this message translates to:
  /// **'Background music'**
  String get backgroundMusic;

  /// No description provided for @muteBackgroundMusic.
  ///
  /// In en, this message translates to:
  /// **'Mute background music'**
  String get muteBackgroundMusic;

  /// No description provided for @backgroundVideo.
  ///
  /// In en, this message translates to:
  /// **'Background video'**
  String get backgroundVideo;

  /// No description provided for @disableBackgroundVideo.
  ///
  /// In en, this message translates to:
  /// **'Disable background video'**
  String get disableBackgroundVideo;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @searchPlatformHint.
  ///
  /// In en, this message translates to:
  /// **'Search platform...'**
  String get searchPlatformHint;

  /// No description provided for @searchGameHint.
  ///
  /// In en, this message translates to:
  /// **'Search game...'**
  String get searchGameHint;

  /// No description provided for @platformsAndGamesCount.
  ///
  /// In en, this message translates to:
  /// **'{platforms} platforms · {games} games'**
  String platformsAndGamesCount(int platforms, int games);

  /// No description provided for @gamesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} games'**
  String gamesCount(int count);

  /// No description provided for @noResultsForQuery.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsForQuery(String query);

  /// No description provided for @related.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get related;

  /// No description provided for @creatorsAndCast.
  ///
  /// In en, this message translates to:
  /// **'Creators and cast'**
  String get creatorsAndCast;

  /// No description provided for @director.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get director;

  /// No description provided for @producers.
  ///
  /// In en, this message translates to:
  /// **'Producers'**
  String get producers;

  /// No description provided for @castLabel.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get castLabel;

  /// No description provided for @studio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get studio;

  /// No description provided for @audioLanguages.
  ///
  /// In en, this message translates to:
  /// **'Audio languages'**
  String get audioLanguages;

  /// No description provided for @noAudioTracks.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks available.'**
  String get noAudioTracks;

  /// No description provided for @subtitlesLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitlesLabel;

  /// No description provided for @noSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No subtitles available.'**
  String get noSubtitles;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moreOptionsToEnjoy.
  ///
  /// In en, this message translates to:
  /// **'More ways to enjoy'**
  String get moreOptionsToEnjoy;

  /// No description provided for @termsApply.
  ///
  /// In en, this message translates to:
  /// **'Terms apply'**
  String get termsApply;

  /// No description provided for @trailerNoTrailer.
  ///
  /// In en, this message translates to:
  /// **'KinoCheck didn\'t return a playable trailer.'**
  String get trailerNoTrailer;

  /// No description provided for @trailerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the trailer video.'**
  String get trailerOpenFailed;

  /// No description provided for @inYourLibrary.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get inYourLibrary;

  /// No description provided for @noSongsInLibrary.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have songs by this artist in your library'**
  String get noSongsInLibrary;

  /// No description provided for @libraryAndPopularCounts.
  ///
  /// In en, this message translates to:
  /// **'{library} in your library • {popular} popular'**
  String libraryAndPopularCounts(int library, int popular);

  /// No description provided for @noSongsForArtist.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have songs by this artist'**
  String get noSongsForArtist;

  /// No description provided for @inYourLibraryCount.
  ///
  /// In en, this message translates to:
  /// **'In your library ({count})'**
  String inYourLibraryCount(int count);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @noPopularTracks.
  ///
  /// In en, this message translates to:
  /// **'No popular tracks'**
  String get noPopularTracks;

  /// No description provided for @tracksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String tracksCount(int count);

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @noTracks.
  ///
  /// In en, this message translates to:
  /// **'No tracks'**
  String get noTracks;

  /// No description provided for @moreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More like this'**
  String get moreLikeThis;

  /// No description provided for @moreAlbumsByArtist.
  ///
  /// In en, this message translates to:
  /// **'More albums by {artist}'**
  String moreAlbumsByArtist(String artist);

  /// No description provided for @moreAlbumsOfArtist.
  ///
  /// In en, this message translates to:
  /// **'More albums by the artist'**
  String get moreAlbumsOfArtist;

  /// No description provided for @enterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter the API Key'**
  String get enterApiKey;

  /// No description provided for @rommApiKeyHelp.
  ///
  /// In en, this message translates to:
  /// **'Connect with your RomM API Key (Bearer). Generate the API Key in RomM → Profile → API Keys.'**
  String get rommApiKeyHelp;

  /// No description provided for @apiKeyBearerLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key (Bearer)'**
  String get apiKeyBearerLabel;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameCannotBeEmpty;

  /// No description provided for @pinTooShort.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits'**
  String get pinTooShort;

  /// No description provided for @pinsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match'**
  String get pinsDontMatch;

  /// No description provided for @couldNotSaveHouse.
  ///
  /// In en, this message translates to:
  /// **'Could not save house: {error}'**
  String couldNotSaveHouse(String error);

  /// No description provided for @householdMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{user} other{users}}'**
  String householdMembersCount(int count);

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get enterUsername;

  /// No description provided for @noServerConfigured.
  ///
  /// In en, this message translates to:
  /// **'No server configured'**
  String get noServerConfigured;

  /// No description provided for @invalidServerResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid server response'**
  String get invalidServerResponse;

  /// No description provided for @couldNotConnectWithHint.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server{hint}. Check the URL (e.g. https://jellyfin.example.com) and your connection.'**
  String couldNotConnectWithHint(String hint);

  /// No description provided for @couldNotConnectGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server. Check the URL and your connection.'**
  String get couldNotConnectGeneric;

  /// No description provided for @masterPinRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery master PIN'**
  String get masterPinRecovery;

  /// No description provided for @pinCopied.
  ///
  /// In en, this message translates to:
  /// **'PIN copied to clipboard'**
  String get pinCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @masterPinSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Save it separately: it lets you recover access to this home if you forget the PIN.'**
  String get masterPinSaveHint;

  /// No description provided for @invalidJsonObject.
  ///
  /// In en, this message translates to:
  /// **'JSON is not a valid object.'**
  String get invalidJsonObject;

  /// No description provided for @serverUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Server URL is empty'**
  String get serverUrlEmpty;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid server URL'**
  String get serverUrlInvalid;

  /// No description provided for @serverUrlMustStartWithHttp.
  ///
  /// In en, this message translates to:
  /// **'URL must start with http:// or https://'**
  String get serverUrlMustStartWithHttp;

  /// No description provided for @rommUserPassDisabled.
  ///
  /// In en, this message translates to:
  /// **'Username/password login disabled. Use API Key in RomM → Profile → API Keys.'**
  String get rommUserPassDisabled;

  /// No description provided for @apiKeyEmpty.
  ///
  /// In en, this message translates to:
  /// **'API Key is empty'**
  String get apiKeyEmpty;

  /// No description provided for @rommForbidden.
  ///
  /// In en, this message translates to:
  /// **'Access denied (403). Check ROMM user permissions on the server.\n\nDetails: {details}'**
  String rommForbidden(String details);

  /// No description provided for @rommForbiddenDetailed.
  ///
  /// In en, this message translates to:
  /// **'Access denied (403 Forbidden). Your ROMM user has no permission for this resource. Check permissions or log in again.'**
  String get rommForbiddenDetailed;

  /// No description provided for @loginFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to log in'**
  String get loginFailedFallback;

  /// No description provided for @pinRequired.
  ///
  /// In en, this message translates to:
  /// **'You must choose a PIN for the house'**
  String get pinRequired;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @nowPlayingTrack.
  ///
  /// In en, this message translates to:
  /// **'Now playing: {track}'**
  String nowPlayingTrack(String track);

  /// No description provided for @gameTimePlayed.
  ///
  /// In en, this message translates to:
  /// **'Time Played'**
  String get gameTimePlayed;

  /// No description provided for @gameLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last Played'**
  String get gameLastPlayed;

  /// No description provided for @gameReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get gameReleaseDate;

  /// No description provided for @gamePlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get gamePlatform;

  /// No description provided for @gameInstall.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get gameInstall;

  /// No description provided for @gameOptions.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get gameOptions;

  /// No description provided for @gameKeyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Key Features:'**
  String get gameKeyFeatures;

  /// No description provided for @gameNotPlayed.
  ///
  /// In en, this message translates to:
  /// **'Not Played'**
  String get gameNotPlayed;

  /// No description provided for @gameNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get gameNever;

  /// No description provided for @gameInstallLabel.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get gameInstallLabel;

  /// No description provided for @gameOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get gameOptionsLabel;

  /// No description provided for @mediaLibraries.
  ///
  /// In en, this message translates to:
  /// **'Media Libraries'**
  String get mediaLibraries;

  /// No description provided for @selectCollectionWithDPad.
  ///
  /// In en, this message translates to:
  /// **'Select the collection you want to explore with your D-Pad arrows.'**
  String get selectCollectionWithDPad;

  /// No description provided for @closeEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get closeEsc;

  /// No description provided for @focusedLabel.
  ///
  /// In en, this message translates to:
  /// **'FOCUSED'**
  String get focusedLabel;

  /// No description provided for @cardBadgeBestAction.
  ///
  /// In en, this message translates to:
  /// **'BEST ACTION'**
  String get cardBadgeBestAction;

  /// No description provided for @cardBadgeBestDrama.
  ///
  /// In en, this message translates to:
  /// **'BEST DRAMA'**
  String get cardBadgeBestDrama;

  /// No description provided for @cardBadgeBestComedy.
  ///
  /// In en, this message translates to:
  /// **'BEST COMEDY'**
  String get cardBadgeBestComedy;

  /// No description provided for @cardBadgeBestSciFi.
  ///
  /// In en, this message translates to:
  /// **'BEST SCI-FI'**
  String get cardBadgeBestSciFi;

  /// No description provided for @cardBadgeBestHorror.
  ///
  /// In en, this message translates to:
  /// **'BEST HORROR'**
  String get cardBadgeBestHorror;

  /// No description provided for @cardBadgeTrending.
  ///
  /// In en, this message translates to:
  /// **'TRENDING'**
  String get cardBadgeTrending;

  /// No description provided for @cardBadgeFamily.
  ///
  /// In en, this message translates to:
  /// **'FAMILY FAVORITE'**
  String get cardBadgeFamily;

  /// No description provided for @showCardBadge.
  ///
  /// In en, this message translates to:
  /// **'Card top badge (Prime style)'**
  String get showCardBadge;

  /// No description provided for @showCardBadgeHint.
  ///
  /// In en, this message translates to:
  /// **'Shows a white label on top of backdrop cards based on genre and rating (≥ 7)'**
  String get showCardBadgeHint;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @filterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get filterByCategory;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilter;

  /// No description provided for @sortAZ.
  ///
  /// In en, this message translates to:
  /// **'A → Z'**
  String get sortAZ;

  /// No description provided for @sortZA.
  ///
  /// In en, this message translates to:
  /// **'Z → A'**
  String get sortZA;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String pageOf(Object current, Object total);

  /// No description provided for @libraryCountTitles.
  ///
  /// In en, this message translates to:
  /// **'{count} titles'**
  String libraryCountTitles(int count);

  /// No description provided for @libraryCountSeries.
  ///
  /// In en, this message translates to:
  /// **'{count} shows'**
  String libraryCountSeries(int count);

  /// No description provided for @libraryCountSongs.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String libraryCountSongs(int count);

  /// No description provided for @libraryCountChannels.
  ///
  /// In en, this message translates to:
  /// **'{count} channels'**
  String libraryCountChannels(int count);

  /// No description provided for @libraryCountFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String libraryCountFiles(int count);

  /// No description provided for @libraryCountLists.
  ///
  /// In en, this message translates to:
  /// **'{count} lists'**
  String libraryCountLists(int count);

  /// No description provided for @libraryCountCollections.
  ///
  /// In en, this message translates to:
  /// **'{count} collections'**
  String libraryCountCollections(int count);

  /// No description provided for @libraryCountHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hours'**
  String libraryCountHours(int count);

  /// No description provided for @libraryCountItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String libraryCountItems(int count);
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
