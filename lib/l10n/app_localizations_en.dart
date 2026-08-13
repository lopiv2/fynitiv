// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Jellyfinitive';

  @override
  String get splashTagline => 'THE DEFINITIVE EXPERIENCE';

  @override
  String get whoIsWatching => 'Who\'s watching?';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'https://jellyfin.example.com';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get login => 'Log in';

  @override
  String get configureServer => 'Configure another server';

  @override
  String get manageHome => 'Manage home';

  @override
  String passwordFor(Object name) {
    return 'Password for $name';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get enter => 'Enter';

  @override
  String get retry => 'Retry';

  @override
  String get whichServer => 'Which server are you connecting to?';

  @override
  String get whoIsFromThisHome => 'Who\'s from this home?';

  @override
  String get selectHouseholdUsers =>
      'Mark the profiles used by the people of this home. Others won\'t appear here.';

  @override
  String get noPublicUsers => 'This server doesn\'t expose public users.';

  @override
  String get homeName => 'What\'s the name of this home?';

  @override
  String get homeNameHint => 'The Garcia Home';

  @override
  String get homeNameLabel => 'Home name';

  @override
  String get chooseHousePin => 'Choose a PIN for this home';

  @override
  String get changeHousePin => 'Change the home PIN';

  @override
  String get leavePinBlank =>
      'Leave the PIN fields blank to keep the current one.';

  @override
  String get pinProtectsHouse =>
      'This PIN protects this home: it\'s required to manage or remove it.';

  @override
  String get pin => 'PIN';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get housePinRequired => 'Enter the home PIN';

  @override
  String get masterPinHint =>
      'Forgot your PIN? Enter your recovery master PIN instead.';

  @override
  String get wrongPin => 'Incorrect PIN, try again';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get save => 'Save';

  @override
  String get server => 'Server';

  @override
  String get users => 'Users';

  @override
  String get householdStep => 'Home';

  @override
  String get library => 'Library';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get couldNotConnect => 'Couldn\'t connect to the server';

  @override
  String get yourLibrary => 'Your library';

  @override
  String get libraryDescription =>
      'Movies, series and more content will appear here.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchDescription => 'Search movies, series and people.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDescription => 'Server, account and preferences settings.';

  @override
  String get home => 'Home';

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get newReleases => 'New releases';

  @override
  String get logout => 'Log out';

  @override
  String get searchHint => 'Search movies, series, people...';

  @override
  String get noResults => 'No results found';

  @override
  String get preferences => 'Preferences';

  @override
  String get account => 'Account';

  @override
  String get about => 'About';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get currentHome => 'Current home';

  @override
  String get version => 'Version';

  @override
  String get aboutDescription =>
      'Jellyfinitive is a client for Jellyfin, your personal media server.';

  @override
  String get signOut => 'Sign out';

  @override
  String get userName => 'User name';

  @override
  String get currentUser => 'Current user';

  @override
  String get appearance => 'Appearance';

  @override
  String get presets => 'Styles';

  @override
  String get colors => 'Colors';

  @override
  String get primaryColor => 'Primary color';

  @override
  String get secondaryColor => 'Secondary color';

  @override
  String get backgroundTopColor => 'Background top';

  @override
  String get backgroundBottomColor => 'Background bottom';

  @override
  String get sidebarColor => 'Sidebar';

  @override
  String get accentColor => 'Accent color';

  @override
  String get layout => 'Layout';

  @override
  String get sidebarPosition => 'Sidebar position';

  @override
  String get logoPosition => 'Logo position';

  @override
  String get avatarPosition => 'Avatar position';

  @override
  String get sidebarLogo => 'Sidebar logo';

  @override
  String get logoImage => 'Image';

  @override
  String get logoText => 'Text';

  @override
  String get chooseLogoImage => 'Choose logo image';

  @override
  String get left => 'Left';

  @override
  String get right => 'Right';

  @override
  String get top => 'Top';

  @override
  String get center => 'Center';

  @override
  String get bottom => 'Bottom';

  @override
  String get cardRadius => 'Card radius';

  @override
  String get showContinueRow => 'Show \'Continue watching\' row';

  @override
  String get showNewReleasesRow => 'Show \'New releases\' row';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get importExport => 'Import / Export';

  @override
  String get exportSkin => 'Export';

  @override
  String get importSkin => 'Import';

  @override
  String get skinCopied => 'Skin copied to clipboard';
}
