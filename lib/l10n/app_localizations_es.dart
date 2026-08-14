// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Jellyfinitive';

  @override
  String get splashTagline => 'THE DEFINITIVE EXPERIENCE';

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
  String get retry => 'Reintentar';

  @override
  String get whichServer => '¿A qué servidor te conectas?';

  @override
  String get whoIsFromThisHome => '¿Quiénes son de esta casa?';

  @override
  String get selectHouseholdUsers =>
      'Marca los perfiles que usará la gente de este hogar. Los demás no aparecerán aquí.';

  @override
  String get noPublicUsers => 'Este servidor no expone usuarios públicos.';

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
  String get back => 'Atrás';

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
      'Jellyfinitive es un cliente para Jellyfin, tu servidor multimedia personal.';

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
  String get watchNow => 'Ver ahora';

  @override
  String get addToFavorites => 'Agregar a favoritos';

  @override
  String get details => 'Detalles';
}
