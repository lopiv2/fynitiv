// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Fynitiv';

  @override
  String get splashTagline => 'Watch. Read. Play. Anything';

  @override
  String get whoIsWatching => '¿Quién está viendo?';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get serverUrlHint => 'https://jellyfin.ejemplo.com';

  @override
  String get username => 'Usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get configureServer => 'Configurar otro servidor';

  @override
  String get manageHome => 'Gestionar casa';

  @override
  String passwordFor(Object name) {
    return 'Contraseña para $name';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get enter => 'Entrar';

  @override
  String get whichServer => '¿A qué servidor te conectas?';

  @override
  String get whoIsFromThisHome => '¿Quiénes son de esta casa?';

  @override
  String get selectHouseholdUsers =>
      'Añade los usuarios con su usuario y contraseña. Nadie verá la lista completa del servidor.';

  @override
  String get noPublicUsers => 'Este servidor no expone usuarios públicos.';

  @override
  String get noHouseholdMembers =>
      'Aún no hay usuarios en esta casa. Pulsa Agregar usuario para añadir el primero.';

  @override
  String get addUser => 'Agregar usuario';

  @override
  String get addUserTitle => 'Agregar usuario a la casa';

  @override
  String get add => 'Agregar';

  @override
  String get removeUser => 'Quitar';

  @override
  String get addAtLeastOneUser => 'Agrega al menos un usuario para continuar';

  @override
  String get userAlreadyAdded => 'Ese usuario ya está en la casa';

  @override
  String get invalidCredentials => 'Usuario o contraseña incorrectos';

  @override
  String get homeName => '¿Cómo se llama esta casa?';

  @override
  String get homeNameHint => 'Casa García';

  @override
  String get homeNameLabel => 'Nombre de la casa';

  @override
  String get chooseHousePin => 'Elige un PIN para esta casa';

  @override
  String get changeHousePin => 'Cambiar el PIN de la casa';

  @override
  String get leavePinBlank =>
      'Deja los campos de PIN vacíos para mantener el actual.';

  @override
  String get pinProtectsHouse =>
      'Este PIN protege esta casa: es necesario para gestionarla o eliminarla.';

  @override
  String get pin => 'PIN';

  @override
  String get confirmPin => 'Confirmar PIN';

  @override
  String get housePinRequired => 'Introduce el PIN de la casa';

  @override
  String get masterPinHint =>
      '¿Has olvidado tu PIN? Introduce el PIN maestro de recuperación.';

  @override
  String get wrongPin => 'PIN incorrecto, inténtalo de nuevo';

  @override
  String get next => 'Siguiente';

  @override
  String get save => 'Guardar';

  @override
  String get server => 'Servidor';

  @override
  String get users => 'Usuarios';

  @override
  String get householdStep => 'Casa';

  @override
  String get library => 'Biblioteca';

  @override
  String get search => 'Buscar';

  @override
  String get settings => 'Ajustes';

  @override
  String get couldNotConnect => 'No se pudo conectar con el servidor';

  @override
  String get yourLibrary => 'Tu biblioteca';

  @override
  String get libraryDescription =>
      'Películas, series y demás contenido aparecerán aquí.';

  @override
  String get searchTitle => 'Búsqueda';

  @override
  String get searchDescription => 'Busca películas, series y personas.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsDescription =>
      'Configuración de servidor, cuenta y preferencias.';

  @override
  String get home => 'Inicio';

  @override
  String get continueWatching => 'Continuar viendo';

  @override
  String get continuePlaying => 'Continuar jugando';

  @override
  String get upNext => 'A continuación';

  @override
  String get newReleases => 'Novedades';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get searchHint => 'Busca películas, series, personas...';

  @override
  String get noResults => 'No se encontraron resultados';

  @override
  String get preferences => 'Preferencias';

  @override
  String get account => 'Cuenta';

  @override
  String get about => 'Acerca de';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get currentHome => 'Casa actual';

  @override
  String get version => 'Versión';

  @override
  String get aboutDescription =>
      'Fynitiv es un cliente para Jellyfin, tu servidor multimedia personal.';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get userName => 'Nombre de usuario';

  @override
  String get currentUser => 'Usuario actual';

  @override
  String get appearance => 'Apariencia';

  @override
  String get presets => 'Estilos';

  @override
  String get colors => 'Colores';

  @override
  String get primaryColor => 'Color primario';

  @override
  String get secondaryColor => 'Color secundario';

  @override
  String get backgroundTopColor => 'Fondo superior';

  @override
  String get backgroundBottomColor => 'Fondo inferior';

  @override
  String get sidebarColor => 'Barra lateral';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get layout => 'Diseño';

  @override
  String get sidebarPosition => 'Posición de la barra lateral';

  @override
  String get topBarFloating => 'Isla flotante';

  @override
  String get topBarFloatingHint =>
      'Muestra la barra superior como isla pill con glass blur (radio 28), flotando sobre el banner';

  @override
  String get logoPosition => 'Posición del logotipo';

  @override
  String get avatarPosition => 'Posición del avatar';

  @override
  String get sidebarLogo => 'Logotipo de la barra lateral';

  @override
  String get logoImage => 'Imagen';

  @override
  String get logoText => 'Texto';

  @override
  String get chooseLogoImage => 'Elegir imagen del logotipo';

  @override
  String get left => 'Izquierda';

  @override
  String get right => 'Derecha';

  @override
  String get top => 'Arriba';

  @override
  String get center => 'Centro';

  @override
  String get bottom => 'Abajo';

  @override
  String get cardRadius => 'Radio de las tarjetas';

  @override
  String get showContinueRow => 'Mostrar fila \'Continuar viendo\'';

  @override
  String get showNewReleasesRow => 'Mostrar fila \'Novedades\'';

  @override
  String get cardImageType => 'Imagen de las tarjetas';

  @override
  String get poster => 'Póster';

  @override
  String get backdrop => 'Backdrop';

  @override
  String get cardLogo => 'Logotipo de las tarjetas';

  @override
  String get cardLogoSize => 'Tamaño del logotipo';

  @override
  String get playerLogo => 'Logotipo del reproductor';

  @override
  String get playerLogoPosition => 'Logotipo en el reproductor';

  @override
  String get audioWaveformEffect => 'Efecto de onda del audio';

  @override
  String get effectEqualizer => 'Ecualizador';

  @override
  String get effectWave => 'Onda';

  @override
  String get effectMirror => 'Espejo';

  @override
  String get effectBars => 'Barras';

  @override
  String get effectSurfer => 'Surfista';

  @override
  String get preview => 'Vista previa';

  @override
  String get none => 'Ninguno';

  @override
  String get uploadLogo => 'Subir imagen';

  @override
  String get topLeft => 'Arriba a la izquierda';

  @override
  String get topRight => 'Arriba a la derecha';

  @override
  String get bottomLeft => 'Abajo a la izquierda';

  @override
  String get bottomRight => 'Abajo a la derecha';

  @override
  String get reset => 'Restablecer';

  @override
  String get apply => 'Aplicar';

  @override
  String get importExport => 'Importar / Exportar';

  @override
  String get exportSkin => 'Exportar';

  @override
  String get importSkin => 'Importar';

  @override
  String get skinCopied => 'Skin copiado al portapapeles';

  @override
  String get includedWithJellyfin => 'Se incluye con Jellyfin';

  @override
  String get adFreeEasterEggButton => 'Continuar sin anuncios';

  @override
  String get adFreeEasterEggTitle => '¡Has encontrado el botón secreto!';

  @override
  String get adFreeEasterEggMessage =>
      'Jellyfin no tiene anuncios. Así que este botón acaba de concederte exactamente lo que ya tenías: cero anuncios y una sonrisa gratis.';

  @override
  String get adFreeEasterEggClose => 'Seguir disfrutando';

  @override
  String get watchNow => 'Ver ahora';

  @override
  String get addToFavorites => 'Agregar a favoritos';

  @override
  String get details => 'Detalles';

  @override
  String get watchTrailer => 'Ver trailer';

  @override
  String get playbackFailed => 'No se pudo iniciar la reproducción.';

  @override
  String get retry => 'Reintentar';

  @override
  String get back => 'Atrás';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get volume => 'Volumen';

  @override
  String get fullscreen => 'Pantalla completa';

  @override
  String get exitFullscreen => 'Salir de pantalla completa';

  @override
  String get subtitle => 'Subtítulos';

  @override
  String get subtitlesOff => 'Desactivados';

  @override
  String get replay => 'Volver a reproducir';

  @override
  String get audio => 'Audio';

  @override
  String get vod => 'VOD';

  @override
  String get liveTv => 'Live TV';

  @override
  String get liveTvChannels => 'Canales';

  @override
  String get liveTvGuide => 'Guía';

  @override
  String get liveTvAll => 'Todas';

  @override
  String get liveTvNews => 'Noticias';

  @override
  String get liveTvSports => 'Deportes';

  @override
  String get liveTvKids => 'Infantil';

  @override
  String get liveTvMovies => 'Cine';

  @override
  String get liveTvSeries => 'Series';

  @override
  String get liveTvFavorites => 'Favoritos';

  @override
  String get liveTvNow => 'EN DIRECTO';

  @override
  String get liveTvHd => 'HD';

  @override
  String get liveTvSearch => 'Buscar canales';

  @override
  String get liveTvNowOnFynitiv => 'AHORA EN FYNITIV';

  @override
  String get liveTvMinimize => 'Minimizar';

  @override
  String get liveTvExpand => 'Expandir';

  @override
  String get liveTvClose => 'Cerrar';

  @override
  String get liveTvMute => 'Silenciar';

  @override
  String get liveTvUnmute => 'Con sonido';

  @override
  String get liveTvSelectChannel => 'Selecciona un canal';

  @override
  String get liveTvNoAiring => 'Sin programa en emisión';

  @override
  String get liveTvNoGuide => 'No hay datos de guía para el servidor';

  @override
  String get liveTvNoChannels => 'No hay canales disponibles';

  @override
  String get music => 'Music Player';

  @override
  String get albums => 'Álbumes';

  @override
  String get songs => 'Canciones';

  @override
  String get resume => 'Reanudar';

  @override
  String get actionMovies => 'Películas de acción';

  @override
  String get familyMovies => 'Cine infantil y para toda la familia';

  @override
  String get seeMore => 'Ver más >';

  @override
  String get allMovies => 'Todas las películas';

  @override
  String get games => 'Juego online';

  @override
  String get gamesSubtitle => 'Tu biblioteca de juegos (ROMM)';

  @override
  String get gamesEmpty => 'No hay plataformas en la biblioteca de ROMM.';

  @override
  String get gamesNoServer =>
      'No hay un servidor ROMM configurado. Conecta tu biblioteca de juegos para jugar online.';

  @override
  String get gamesConfigure => 'Configurar servidor';

  @override
  String get gamesConfigTitle => 'Servidor ROMM';

  @override
  String get gamesConfigSave => 'Guardar y conectar';

  @override
  String get gamesConfigSaved => 'Conectado correctamente';

  @override
  String get gamesConfigFailed => 'No se pudo conectar. Revisa los datos.';

  @override
  String get gamesConfigRequired => 'Completa URL, usuario y contraseña.';

  @override
  String get gamesServerUrl => 'URL del servidor';

  @override
  String get gamesUsername => 'Usuario';

  @override
  String get gamesPassword => 'Contraseña';

  @override
  String get gamesConnected => 'Conectado';

  @override
  String get gamesDisconnect => 'Desconectar';

  @override
  String get gamesPlay => 'Jugar';

  @override
  String get gamesDownload => 'Descargar';

  @override
  String get gamesNoStreaming =>
      'El streaming no está disponible para este juego. Usa Descargar.';

  @override
  String get gamesNoFile => 'Este juego no tiene un archivo descargable.';

  @override
  String get gamesDownloaded => 'Descarga completada';

  @override
  String get gamesLaunchError => 'No se pudo abrir el reproductor web.';

  @override
  String get musicPlayerStyle => 'Estilos del Music Player';

  @override
  String get musicPlayerStyleHint =>
      'Solo afecta al Music Player (álbumes, listas y reproductor de audio). No cambia la barra lateral.';

  @override
  String get recentlyPlayed => 'Escuchado recientemente';

  @override
  String get madeForYou => 'Hecho para ti';

  @override
  String get trending => 'Tendencias';

  @override
  String get topAlbums => 'Top álbumes';

  @override
  String get newReleasesMusic => 'Novedades musicales';

  @override
  String get hotlist => 'Hotlist';

  @override
  String get hiFiPicks => 'Selección HiFi';

  @override
  String get noAlbums => 'Sin álbumes';

  @override
  String get trendingSongs => 'Canciones en tendencia';

  @override
  String get popularArtists => 'Artistas populares';

  @override
  String get showAll => 'Mostrar todos';

  @override
  String get artist => 'Artista';

  @override
  String get chartSource => 'Fuente del chart';

  @override
  String get chartSourceJellyfin => 'Jellyfin (local)';

  @override
  String get chartSourceDeezer => 'Deezer (global)';

  @override
  String get chartSourceHint =>
      'Elige si el Music Player muestra tu biblioteca local o el top global de Deezer.';

  @override
  String get myPlaylists => 'Mis playlists';

  @override
  String get recentlyAdded => 'Recién añadidos';

  @override
  String get populares => 'Populares';

  @override
  String monthlyListeners(Object count) {
    return '$count oyentes mensuales';
  }

  @override
  String get noPlayableSongs => 'Actualmente no hay canciones reproducibles';

  @override
  String get deezerSuggestions => 'Sugerencias de Deezer';

  @override
  String recentIn(String library) {
    return 'Reciente en $library';
  }

  @override
  String get titleMarquee => 'Desplazamiento del título al pasar el ratón';

  @override
  String get titleMarqueeHint =>
      'Si el título no cabe, se desplaza de derecha a izquierda en bucle al hacer hover (como en Jellyfin Android TV)';

  @override
  String get platforms => 'Plataformas';

  @override
  String get sounds => 'Sonidos';

  @override
  String get selectionSound => 'Sonido de selección de elemento';

  @override
  String get selectionSoundHint =>
      'Sonido que se reproduce al pasar el cursor o enfocar un elemento (usa el volumen del sistema)';

  @override
  String get testSound => 'Probar';

  @override
  String get soundsSectionTitle => 'Sonidos';

  @override
  String get soundsSectionDescription => 'Sonidos de selección y hover';

  @override
  String get backgroundMusic => 'Música de fondo';

  @override
  String get muteBackgroundMusic => 'Silenciar música de fondo';

  @override
  String get backgroundVideo => 'Video de fondo';

  @override
  String get disableBackgroundVideo => 'Desactivar video de fondo';

  @override
  String get accept => 'Aceptar';

  @override
  String get searchPlatformHint => 'Buscar plataforma...';

  @override
  String get searchGameHint => 'Buscar juego...';

  @override
  String platformsAndGamesCount(int platforms, int games) {
    return '$platforms plataformas · $games juegos';
  }

  @override
  String gamesCount(int count) {
    return '$count juegos';
  }

  @override
  String noResultsForQuery(String query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get related => 'Relacionado';

  @override
  String get creatorsAndCast => 'Creadores y reparto';

  @override
  String get director => 'Dirección';

  @override
  String get producers => 'Productores';

  @override
  String get castLabel => 'Reparto';

  @override
  String get studio => 'Estudio';

  @override
  String get audioLanguages => 'Idiomas de audio';

  @override
  String get noAudioTracks => 'No hay pistas de audio disponibles.';

  @override
  String get subtitlesLabel => 'Subtítulos';

  @override
  String get noSubtitles => 'No hay subtítulos disponibles.';

  @override
  String get more => 'Más';

  @override
  String get moreOptionsToEnjoy => 'Más opciones para disfrutar';

  @override
  String get termsApply => 'Se aplican términos';

  @override
  String get trailerNoTrailer =>
      'KinoCheck no devolvió un tráiler reproducible.';

  @override
  String get trailerOpenFailed => 'No se pudo abrir el video del tráiler.';

  @override
  String get inYourLibrary => 'En tu biblioteca';

  @override
  String get noSongsInLibrary =>
      'No tienes canciones de este artista en tu biblioteca';

  @override
  String libraryAndPopularCounts(int library, int popular) {
    return '$library en tu biblioteca • $popular populares';
  }

  @override
  String get noSongsForArtist => 'No tienes canciones de este artista';

  @override
  String inYourLibraryCount(int count) {
    return 'En tu biblioteca ($count)';
  }

  @override
  String get loadMore => 'Cargar más';

  @override
  String get noPopularTracks => 'Sin populares';

  @override
  String tracksCount(int count) {
    return '$count pistas';
  }

  @override
  String get genre => 'Género';

  @override
  String get noTracks => 'Sin pistas';

  @override
  String get moreLikeThis => 'Más como este';

  @override
  String moreAlbumsByArtist(String artist) {
    return 'Más álbumes de $artist';
  }

  @override
  String get moreAlbumsOfArtist => 'Más álbumes del artista';

  @override
  String get enterApiKey => 'Introduce la API Key';

  @override
  String get rommApiKeyHelp =>
      'Conéctate con tu API Key de RomM (Bearer). Genera la API Key en RomM → Perfil → API Keys.';

  @override
  String get apiKeyBearerLabel => 'API Key (Bearer)';

  @override
  String get nameCannotBeEmpty => 'El nombre no puede estar vacío';

  @override
  String get pinTooShort => 'El PIN debe tener al menos 4 dígitos';

  @override
  String get pinsDontMatch => 'Los PIN no coinciden';

  @override
  String couldNotSaveHouse(String error) {
    return 'No se pudo guardar la casa: $error';
  }

  @override
  String householdMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'usuarios',
      one: 'usuario',
    );
    return '$count $_temp0';
  }

  @override
  String get enterUsername => 'Ingresa el usuario';

  @override
  String get noServerConfigured => 'Sin servidor configurado';

  @override
  String get invalidServerResponse => 'Respuesta inválida del servidor';

  @override
  String couldNotConnectWithHint(String hint) {
    return 'No se pudo conectar al servidor$hint. Revisa la URL (ej. https://jellyfin.ejemplo.com) y tu conexión.';
  }

  @override
  String get couldNotConnectGeneric =>
      'No se pudo conectar al servidor. Revisa la URL y tu conexión.';

  @override
  String get masterPinRecovery => 'PIN maestro de recuperación';

  @override
  String get pinCopied => 'PIN copiado al portapapeles';

  @override
  String get copy => 'Copiar';

  @override
  String get masterPinSaveHint =>
      'Guárdalo aparte: sirve para recuperar el acceso a esta casa si se olvida el PIN.';

  @override
  String get invalidJsonObject => 'El JSON no es un objeto válido.';

  @override
  String get serverUrlEmpty => 'URL del servidor vacía';

  @override
  String get serverUrlInvalid => 'URL del servidor no válida';

  @override
  String get serverUrlMustStartWithHttp =>
      'La URL debe empezar por http:// o https://';

  @override
  String get rommUserPassDisabled =>
      'Conexión por usuario/contraseña deshabilitada. Usa API Key en RomM → Perfil → API Keys.';

  @override
  String get apiKeyEmpty => 'API Key vacía';

  @override
  String rommForbidden(String details) {
    return 'Acceso denegado (403). Verifica permisos del usuario ROMM en el servidor.\n\nDetalle: $details';
  }

  @override
  String get rommForbiddenDetailed =>
      'Acceso denegado (403 Forbidden). Tu usuario ROMM no tiene permiso para este recurso. Verifica permisos o inicia sesión de nuevo.';

  @override
  String get loginFailedFallback => 'Error al iniciar sesión';

  @override
  String get pinRequired => 'Debes elegir un PIN para la casa';

  @override
  String get nowPlaying => 'Reproduciendo ahora';

  @override
  String nowPlayingTrack(String track) {
    return 'Reproduciendo: $track';
  }

  @override
  String get gameTimePlayed => 'Tiempo jugado';

  @override
  String get gameLastPlayed => 'Última vez';

  @override
  String get gameReleaseDate => 'Fecha de lanzamiento';

  @override
  String get gamePlatform => 'Plataforma';

  @override
  String get gameInstall => 'Jugar';

  @override
  String get gameOptions => 'Descargar';

  @override
  String get gameKeyFeatures => 'Características principales:';

  @override
  String get gameNotPlayed => 'No jugado';

  @override
  String get gameNever => 'Nunca';

  @override
  String get gameInstallLabel => 'Instalar';

  @override
  String get gameOptionsLabel => 'Opciones';

  @override
  String get mediaLibraries => 'Bibliotecas de Medios';

  @override
  String get selectCollectionWithDPad =>
      'Selecciona la colección que deseas explorar con las flechas de tu mando D-Pad.';

  @override
  String get closeEsc => 'Cerrar (Esc)';

  @override
  String get focusedLabel => 'ENFOCADO';
}
