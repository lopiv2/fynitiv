/// Logros ocultos ("easter egg") de Mi espacio.
///
/// Cada logro se desbloquea con un umbral de actividad concreta. La UI los
/// muestra todos: los desbloqueados a color y los pendientes atenuados con su
/// condición, para que el usuario sepa qué le falta.
enum NerdAchievement {
  marathon,
  cinephile,
  binge,
  bookworm,
  audiophile,
  retro,
  collector,
  century,
  jackOfAllTrades;

  /// `true` si [stats] ya cumple la condición de este logro.
  bool isUnlocked(NerdStats stats) => switch (this) {
    NerdAchievement.marathon => stats.videoMinutes >= 10 * 60,
    NerdAchievement.cinephile => stats.moviesWatched >= 50,
    NerdAchievement.binge => stats.episodesWatched >= 100,
    NerdAchievement.bookworm => stats.booksRead >= 5,
    NerdAchievement.audiophile => stats.songsPlayed >= 100,
    NerdAchievement.retro => stats.gamesPlayed >= 10,
    NerdAchievement.collector => stats.gamesOwned >= 100,
    NerdAchievement.century => stats.totalMinutes >= 100 * 60,
    NerdAchievement.jackOfAllTrades =>
      stats.moviesWatched > 0 &&
          stats.episodesWatched > 0 &&
          stats.songsPlayed > 0 &&
          stats.booksRead > 0 &&
          stats.gamesPlayed > 0,
  };
}

/// Estadísticas personales del usuario, calculadas a partir de su biblioteca
/// (Jellyfin) y de su ludoteca (ROMM) cuando está configurada.
class NerdStats {
  const NerdStats({
    this.moviesWatched = 0,
    this.episodesWatched = 0,
    this.seriesStarted = 0,
    this.songsPlayed = 0,
    this.booksRead = 0,
    this.videoMinutes = 0,
    this.musicMinutes = 0,
    this.gamesOwned = 0,
    this.gamesPlayed = 0,
    this.platforms = 0,
  });

  /// Películas marcadas como vistas.
  final int moviesWatched;

  /// Episodios marcados como vistos.
  final int episodesWatched;

  /// Series con al menos un visionado.
  final int seriesStarted;

  /// Canciones reproducidas al menos una vez.
  final int songsPlayed;

  /// Libros marcados como leídos.
  final int booksRead;

  /// Minutos de vídeo acumulados (películas + episodios vistos).
  final int videoMinutes;

  /// Minutos de música acumulados (canciones escuchadas).
  final int musicMinutes;

  /// Juegos disponibles en la biblioteca de ROMM.
  final int gamesOwned;

  /// Juegos jugados al menos una vez.
  final int gamesPlayed;

  /// Plataformas con juegos en la biblioteca.
  final int platforms;

  /// Minutos totales de ocio registrados.
  int get totalMinutes => videoMinutes + musicMinutes;

  /// Horas totales (redondeadas hacia abajo) para mostrar en la UI.
  int get totalHours => totalMinutes ~/ 60;

  // ---------------------------------------------------------------------------
  // XP por actividad
  // ---------------------------------------------------------------------------
  //
  // Tasas fijas y visibles en la UI (bloque «Cómo se gana XP»). Los libros y
  // los juegos puntúan alto porque son actividades más raras en una biblioteca
  // doméstica; las series puntúan poco para no premiar dos veces lo mismo.

  /// XP por película vista.
  static const int xpPerMovie = 50;

  /// XP por episodio visto.
  static const int xpPerEpisode = 10;

  /// XP por serie empezada.
  static const int xpPerSeries = 25;

  /// XP por canción escuchada.
  static const int xpPerSong = 2;

  /// XP por libro leído.
  static const int xpPerBook = 150;

  /// XP por juego jugado.
  static const int xpPerGamePlayed = 75;

  /// XP por juego disponible en la biblioteca (incentiva coleccionar).
  static const int xpPerGameOwned = 2;

  /// XP por cada hora de vídeo consumida.
  static const int xpPerVideoHour = 20;

  /// XP por cada hora de música consumida.
  static const int xpPerMusicHour = 5;

  /// Experiencia total acumulada.
  int get xp =>
      moviesWatched * xpPerMovie +
      episodesWatched * xpPerEpisode +
      seriesStarted * xpPerSeries +
      songsPlayed * xpPerSong +
      booksRead * xpPerBook +
      gamesPlayed * xpPerGamePlayed +
      gamesOwned * xpPerGameOwned +
      (videoMinutes ~/ 60) * xpPerVideoHour +
      (musicMinutes ~/ 60) * xpPerMusicHour;

  /// 30 umbrales de XP (el índice 0 es el nivel 1). Curva cuadrática suave:
  /// `120·(L-1)² + 80·(L-1)`, de 0 XP a ~103.000 XP en el nivel 30.
  static const List<int> levelThresholds = [
    0, // 1
    200, // 2
    640, // 3
    1320, // 4
    2240, // 5
    3400, // 6
    4800, // 7
    6440, // 8
    8320, // 9
    10440, // 10
    12800, // 11
    15400, // 12
    18240, // 13
    21320, // 14
    24640, // 15
    28200, // 16
    32000, // 17
    36040, // 18
    40320, // 19
    44840, // 20
    49600, // 21
    54600, // 22
    59840, // 23
    65320, // 24
    71040, // 25
    77000, // 26
    83200, // 27
    89640, // 28
    96320, // 29
    103240, // 30
  ];

  /// Número máximo de niveles.
  static int get maxLevel => levelThresholds.length;

  /// Nivel actual, de 1 a [maxLevel].
  int get nerdLevel {
    var level = 1;
    for (var i = 0; i < levelThresholds.length; i++) {
      if (xp >= levelThresholds[i]) level = i + 1;
    }
    return level;
  }

  /// Tier (título) del nivel actual, de 1 a 5: agrupa los 30 niveles en cinco
  /// rangos con nombre propio para no traducir 30 cadenas.
  int get nerdTier => switch (nerdLevel) {
    <= 5 => 1,
    <= 10 => 2,
    <= 15 => 3,
    <= 22 => 4,
    _ => 5,
  };

  /// XP que faltan para el siguiente nivel, o `null` si ya está al máximo.
  int? get pointsToNextLevel {
    if (nerdLevel >= maxLevel) return null;
    return levelThresholds[nerdLevel] - xp;
  }

  /// Progreso 0..1 dentro del nivel actual (1 si ya es el máximo).
  double get levelProgress {
    if (nerdLevel >= maxLevel) return 1;
    final start = levelThresholds[nerdLevel - 1];
    final end = levelThresholds[nerdLevel];
    if (end <= start) return 1;
    return ((xp - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Logros ya desbloqueados, en el orden del enum.
  List<NerdAchievement> get unlockedAchievements =>
      NerdAchievement.values.where((a) => a.isUnlocked(this)).toList();

  /// `true` si no hay ninguna actividad registrada todavía.
  bool get isEmpty =>
      moviesWatched == 0 &&
      episodesWatched == 0 &&
      seriesStarted == 0 &&
      songsPlayed == 0 &&
      booksRead == 0 &&
      videoMinutes == 0 &&
      musicMinutes == 0 &&
      gamesOwned == 0 &&
      gamesPlayed == 0;
}
