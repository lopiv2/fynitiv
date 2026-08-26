// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Fynitiv';

  @override
  String get splashTagline => 'Watch. Read. Play. Anything';

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
      'Add users with their username and password. No one will see the full server user list.';

  @override
  String get noPublicUsers => 'This server doesn\'t expose public users.';

  @override
  String get noHouseholdMembers =>
      'No users in this home yet. Tap Add user to add the first one.';

  @override
  String get addUser => 'Add user';

  @override
  String get addUserTitle => 'Add user to home';

  @override
  String get add => 'Add';

  @override
  String get removeUser => 'Remove';

  @override
  String get addAtLeastOneUser => 'Add at least one user to continue';

  @override
  String get userAlreadyAdded => 'That user is already in the home';

  @override
  String get invalidCredentials => 'Invalid username or password';

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
      'Fynitiv is a client for Jellyfin, your personal media server.';

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
  String get cardImageType => 'Cards image type';

  @override
  String get poster => 'Poster';

  @override
  String get backdrop => 'Backdrop';

  @override
  String get cardLogo => 'Card logo';

  @override
  String get cardLogoSize => 'Logo size';

  @override
  String get playerLogo => 'Player logo';

  @override
  String get playerLogoPosition => 'Logo in player';

  @override
  String get audioWaveformEffect => 'Audio waveform effect';

  @override
  String get effectEqualizer => 'Equalizer';

  @override
  String get effectWave => 'Wave';

  @override
  String get effectMirror => 'Mirror';

  @override
  String get effectBars => 'Bars';

  @override
  String get effectSurfer => 'Surfer';

  @override
  String get preview => 'Preview';

  @override
  String get none => 'None';

  @override
  String get uploadLogo => 'Upload image';

  @override
  String get topLeft => 'Top left';

  @override
  String get topRight => 'Top right';

  @override
  String get bottomLeft => 'Bottom left';

  @override
  String get bottomRight => 'Bottom right';

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

  @override
  String get includedWithJellyfin => 'Included with Jellyfin';

  @override
  String get adFreeEasterEggButton => 'Continue without ads';

  @override
  String get adFreeEasterEggTitle => 'You found the secret button!';

  @override
  String get adFreeEasterEggMessage =>
      'Jellyfin has no ads. So this button just gave you exactly what you already had: zero ads and a free smile.';

  @override
  String get adFreeEasterEggClose => 'Keep enjoying';

  @override
  String get watchNow => 'Watch now';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get details => 'Details';

  @override
  String get watchTrailer => 'Watch trailer';

  @override
  String get playbackFailed => 'Couldn\'t start playback.';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get volume => 'Volume';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get subtitle => 'Subtitle';

  @override
  String get subtitlesOff => 'Off';

  @override
  String get replay => 'Replay';

  @override
  String get audio => 'Audio';

  @override
  String get vod => 'VOD';

  @override
  String get liveTv => 'Live TV';

  @override
  String get liveTvChannels => 'Channels';

  @override
  String get liveTvGuide => 'Guide';

  @override
  String get liveTvAll => 'All';

  @override
  String get liveTvNews => 'News';

  @override
  String get liveTvSports => 'Sports';

  @override
  String get liveTvKids => 'Kids';

  @override
  String get liveTvMovies => 'Movies';

  @override
  String get liveTvSeries => 'Series';

  @override
  String get liveTvFavorites => 'Favorites';

  @override
  String get liveTvNow => 'LIVE';

  @override
  String get liveTvHd => 'HD';

  @override
  String get liveTvSearch => 'Search channels';

  @override
  String get liveTvNowOnFynitiv => 'NOW ON FYNITIV';

  @override
  String get liveTvMinimize => 'Minimize';

  @override
  String get liveTvExpand => 'Expand';

  @override
  String get liveTvClose => 'Close';

  @override
  String get liveTvMute => 'Mute';

  @override
  String get liveTvUnmute => 'Unmute';

  @override
  String get liveTvSelectChannel => 'Select a channel';

  @override
  String get liveTvNoAiring => 'No program airing';

  @override
  String get liveTvNoGuide => 'No guide data available for the server';

  @override
  String get liveTvNoChannels => 'No channels available';

  @override
  String get music => 'Music Player';

  @override
  String get albums => 'Albums';

  @override
  String get songs => 'Songs';

  @override
  String get resume => 'Resume';

  @override
  String get actionMovies => 'Action movies';

  @override
  String get familyMovies => 'Family & kids';

  @override
  String get seeMore => 'See more >';

  @override
  String get allMovies => 'All movies';

  @override
  String get games => 'Online games';

  @override
  String get gamesSubtitle => 'Your game library (ROMM)';

  @override
  String get gamesEmpty => 'There are no platforms in the ROMM library.';

  @override
  String get gamesNoServer =>
      'No ROMM server is configured. Connect your game library to play online.';

  @override
  String get gamesConfigure => 'Configure server';

  @override
  String get gamesConfigTitle => 'ROMM server';

  @override
  String get gamesConfigSave => 'Save and connect';

  @override
  String get gamesConfigSaved => 'Connected successfully';

  @override
  String get gamesConfigFailed => 'Could not connect. Check your details.';

  @override
  String get gamesConfigRequired => 'Fill in URL, username and password.';

  @override
  String get gamesServerUrl => 'Server URL';

  @override
  String get gamesUsername => 'Username';

  @override
  String get gamesPassword => 'Password';

  @override
  String get gamesConnected => 'Connected';

  @override
  String get gamesDisconnect => 'Disconnect';

  @override
  String get gamesPlay => 'Play';

  @override
  String get gamesDownload => 'Download';

  @override
  String get gamesNoStreaming =>
      'Streaming is not available for this game. Use Download.';

  @override
  String get gamesNoFile => 'This game has no downloadable file.';

  @override
  String get gamesDownloaded => 'Download complete';

  @override
  String get gamesLaunchError => 'Could not open the web player.';

  @override
  String get musicPlayerStyle => 'Music Player styles';

  @override
  String get musicPlayerStyleHint =>
      'Only affects the Music Player (albums, lists and audio player). Does not change the sidebar.';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get madeForYou => 'Made for you';

  @override
  String get trending => 'Trending';

  @override
  String get topAlbums => 'Top albums';

  @override
  String get newReleasesMusic => 'New music';

  @override
  String get hotlist => 'Hotlist';

  @override
  String get hiFiPicks => 'HiFi picks';

  @override
  String get noAlbums => 'No albums';

  @override
  String get trendingSongs => 'Trending songs';

  @override
  String get popularArtists => 'Popular artists';

  @override
  String get showAll => 'Show all';

  @override
  String get artist => 'Artist';

  @override
  String get chartSource => 'Chart source';

  @override
  String get chartSourceJellyfin => 'Jellyfin (local)';

  @override
  String get chartSourceDeezer => 'Deezer (global)';

  @override
  String get chartSourceHint =>
      'Choose whether the Music Player shows your local library or the global Deezer top chart.';

  @override
  String get myPlaylists => 'My playlists';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get populares => 'Popular';

  @override
  String monthlyListeners(Object count) {
    return '$count monthly listeners';
  }

  @override
  String get noPlayableSongs => 'No playable songs currently';

  @override
  String get deezerSuggestions => 'Deezer suggestions';
}
