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
  String get continuePlaying => 'Continue playing';

  @override
  String get upNext => 'Up Next';

  @override
  String get newReleases => 'New releases';

  @override
  String get newMovie => 'New movie';

  @override
  String get newSeries => 'New series';

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
  String get topBarFloating => 'Floating island';

  @override
  String get topBarFloatingHint =>
      'Shows the top bar as a floating pill with glass blur (radius 28), over the banner';

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
  String get retry => 'Retry';

  @override
  String get back => 'Back';

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
  String get eReader => 'E-Reader';

  @override
  String get eReaderDescription =>
      'Books and comics from your Jellyfin library.';

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
  String get romanticMovies => 'Romantic movies';

  @override
  String get animationMovies => 'Animation movies';

  @override
  String get realities => 'Realities';

  @override
  String get animeSeries => 'Anime series';

  @override
  String get nostalgia => 'Nostalgia';

  @override
  String get dramas => 'Dramas';

  @override
  String get comedies => 'Comedies';

  @override
  String get actionAdventure => 'Action & adventure';

  @override
  String get musicals => 'Musicals';

  @override
  String get foodCooking => 'Food & cooking';

  @override
  String get travel => 'Travel';

  @override
  String get sciFi => 'Sci-Fi';

  @override
  String get western => 'Toughest of the West';

  @override
  String get crime => 'Crime & Suspense';

  @override
  String get horror => 'Diabolical horror';

  @override
  String get superHero => 'Mightiest heroes';

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
  String get episodes => 'Episodes';

  @override
  String get extras => 'Extras';

  @override
  String get suggestions => 'Suggestions';

  @override
  String get season => 'Season';

  @override
  String seriesSeasons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seasons',
      one: '1 season',
    );
    return '$_temp0';
  }

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

  @override
  String recentIn(String library) {
    return 'Recent in $library';
  }

  @override
  String get titleMarquee => 'Title marquee on hover';

  @override
  String get titleMarqueeHint =>
      'When the title overflows, it scrolls left in a loop while hovering (like Jellyfin Android TV)';

  @override
  String get platforms => 'Platforms';

  @override
  String get sounds => 'Sounds';

  @override
  String get selectionSound => 'Item selection sound';

  @override
  String get selectionSoundHint =>
      'Sound played when hovering or focusing an item (uses system volume)';

  @override
  String get testSound => 'Test';

  @override
  String get soundsSectionTitle => 'Sounds';

  @override
  String get soundsSectionDescription => 'Hover and selection feedback sounds';

  @override
  String get backgroundMusic => 'Background music';

  @override
  String get muteBackgroundMusic => 'Mute background music';

  @override
  String get backgroundVideo => 'Background video';

  @override
  String get disableBackgroundVideo => 'Disable background video';

  @override
  String get accept => 'Accept';

  @override
  String get searchPlatformHint => 'Search platform...';

  @override
  String get searchGameHint => 'Search game...';

  @override
  String platformsAndGamesCount(int platforms, int games) {
    return '$platforms platforms · $games games';
  }

  @override
  String gamesCount(int count) {
    return '$count games';
  }

  @override
  String noResultsForQuery(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get related => 'Related';

  @override
  String get creatorsAndCast => 'Creators and cast';

  @override
  String get director => 'Director';

  @override
  String get producers => 'Producers';

  @override
  String get castLabel => 'Cast';

  @override
  String get studio => 'Studio';

  @override
  String get audioLanguages => 'Audio languages';

  @override
  String get noAudioTracks => 'No audio tracks available.';

  @override
  String get subtitlesLabel => 'Subtitles';

  @override
  String get noSubtitles => 'No subtitles available.';

  @override
  String get more => 'More';

  @override
  String get moreOptionsToEnjoy => 'More ways to enjoy';

  @override
  String get termsApply => 'Terms apply';

  @override
  String get trailerNoTrailer => 'KinoCheck didn\'t return a playable trailer.';

  @override
  String get trailerOpenFailed => 'Could not open the trailer video.';

  @override
  String get inYourLibrary => 'In your library';

  @override
  String get noSongsInLibrary =>
      'You don\'t have songs by this artist in your library';

  @override
  String libraryAndPopularCounts(int library, int popular) {
    return '$library in your library • $popular popular';
  }

  @override
  String get noSongsForArtist => 'You don\'t have songs by this artist';

  @override
  String inYourLibraryCount(int count) {
    return 'In your library ($count)';
  }

  @override
  String get loadMore => 'Load more';

  @override
  String get noPopularTracks => 'No popular tracks';

  @override
  String tracksCount(int count) {
    return '$count tracks';
  }

  @override
  String get genre => 'Genre';

  @override
  String get noTracks => 'No tracks';

  @override
  String get moreLikeThis => 'More like this';

  @override
  String moreAlbumsByArtist(String artist) {
    return 'More albums by $artist';
  }

  @override
  String get moreAlbumsOfArtist => 'More albums by the artist';

  @override
  String get enterApiKey => 'Enter the API Key';

  @override
  String get rommApiKeyHelp =>
      'Connect with your RomM API Key (Bearer). Generate the API Key in RomM → Profile → API Keys.';

  @override
  String get apiKeyBearerLabel => 'API Key (Bearer)';

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty';

  @override
  String get pinTooShort => 'PIN must be at least 4 digits';

  @override
  String get pinsDontMatch => 'PINs don\'t match';

  @override
  String couldNotSaveHouse(String error) {
    return 'Could not save house: $error';
  }

  @override
  String householdMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'users',
      one: 'user',
    );
    return '$count $_temp0';
  }

  @override
  String get enterUsername => 'Enter username';

  @override
  String get noServerConfigured => 'No server configured';

  @override
  String get invalidServerResponse => 'Invalid server response';

  @override
  String couldNotConnectWithHint(String hint) {
    return 'Could not connect to server$hint. Check the URL (e.g. https://jellyfin.example.com) and your connection.';
  }

  @override
  String get couldNotConnectGeneric =>
      'Could not connect to server. Check the URL and your connection.';

  @override
  String get masterPinRecovery => 'Recovery master PIN';

  @override
  String get pinCopied => 'PIN copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get masterPinSaveHint =>
      'Save it separately: it lets you recover access to this home if you forget the PIN.';

  @override
  String get invalidJsonObject => 'JSON is not a valid object.';

  @override
  String get serverUrlEmpty => 'Server URL is empty';

  @override
  String get serverUrlInvalid => 'Invalid server URL';

  @override
  String get serverUrlMustStartWithHttp =>
      'URL must start with http:// or https://';

  @override
  String get rommUserPassDisabled =>
      'Username/password login disabled. Use API Key in RomM → Profile → API Keys.';

  @override
  String get apiKeyEmpty => 'API Key is empty';

  @override
  String rommForbidden(String details) {
    return 'Access denied (403). Check ROMM user permissions on the server.\n\nDetails: $details';
  }

  @override
  String get rommForbiddenDetailed =>
      'Access denied (403 Forbidden). Your ROMM user has no permission for this resource. Check permissions or log in again.';

  @override
  String get loginFailedFallback => 'Failed to log in';

  @override
  String get pinRequired => 'You must choose a PIN for the house';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String nowPlayingTrack(String track) {
    return 'Now playing: $track';
  }

  @override
  String get gameTimePlayed => 'Time Played';

  @override
  String get gameLastPlayed => 'Last Played';

  @override
  String get gameReleaseDate => 'Release Date';

  @override
  String get gamePlatform => 'Platform';

  @override
  String get gameInstall => 'Play';

  @override
  String get gameOptions => 'Download';

  @override
  String get gameKeyFeatures => 'Key Features:';

  @override
  String get gameNotPlayed => 'Not Played';

  @override
  String get gameNever => 'Never';

  @override
  String get gameInstallLabel => 'Install';

  @override
  String get gameOptionsLabel => 'Options';

  @override
  String get mediaLibraries => 'Media Libraries';

  @override
  String get selectCollectionWithDPad =>
      'Select the collection you want to explore with your D-Pad arrows.';

  @override
  String get closeEsc => 'Close (Esc)';

  @override
  String get focusedLabel => 'FOCUSED';

  @override
  String get cardBadgeBestAction => 'BEST ACTION';

  @override
  String get cardBadgeBestDrama => 'BEST DRAMA';

  @override
  String get cardBadgeBestComedy => 'BEST COMEDY';

  @override
  String get cardBadgeBestSciFi => 'BEST SCI-FI';

  @override
  String get cardBadgeBestHorror => 'BEST HORROR';

  @override
  String get cardBadgeTrending => 'TRENDING';

  @override
  String get cardBadgeFamily => 'FAMILY FAVORITE';

  @override
  String get showCardBadge => 'Card top badge (Prime style)';

  @override
  String get showCardBadgeHint =>
      'Shows a white label on top of backdrop cards based on genre and rating (≥ 7)';

  @override
  String get categories => 'Categories';

  @override
  String get filterByCategory => 'Filter by category';

  @override
  String get clearFilter => 'Clear';

  @override
  String get sortAZ => 'A → Z';

  @override
  String get sortZA => 'Z → A';

  @override
  String pageOf(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String libraryCountTitles(int count) {
    return '$count titles';
  }

  @override
  String libraryCountSeries(int count) {
    return '$count shows';
  }

  @override
  String libraryCountSongs(int count) {
    return '$count songs';
  }

  @override
  String libraryCountChannels(int count) {
    return '$count channels';
  }

  @override
  String libraryCountFiles(int count) {
    return '$count files';
  }

  @override
  String libraryCountLists(int count) {
    return '$count lists';
  }

  @override
  String libraryCountCollections(int count) {
    return '$count collections';
  }

  @override
  String libraryCountHours(int count) {
    return '$count hours';
  }

  @override
  String libraryCountItems(int count) {
    return '$count items';
  }
}
