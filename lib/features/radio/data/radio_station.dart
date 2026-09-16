library;

/// Modelo de emisora de Radio Browser (https://api.radio-browser.info).
class RadioStation {
  const RadioStation({
    required this.stationUuid,
    required this.name,
    required this.url,
    required this.urlResolved,
    this.favicon = '',
    this.country = '',
    this.countryCode = '',
    this.state = '',
    this.language = '',
    this.tags = const [],
    this.codec = '',
    this.bitrate = 0,
    this.votes = 0,
    this.clickCount = 0,
    this.homepage = '',
    this.hls = false,
  });

  final String stationUuid;
  final String name;
  final String url;
  final String urlResolved;
  final String favicon;
  final String country;
  final String countryCode;
  final String state;
  final String language;
  final List<String> tags;
  final String codec;
  final int bitrate;
  final int votes;
  final int clickCount;
  final String homepage;
  final bool hls;

  /// URL efectiva para reproducir (prefer resolved).
  String get streamUrl => urlResolved.isNotEmpty ? urlResolved : url;

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final rawTags = (json['tags'] as String? ?? '').trim();
    final tags = rawTags.isEmpty
        ? <String>[]
        : rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return RadioStation(
      stationUuid: (json['stationuuid'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      urlResolved: (json['url_resolved'] as String? ?? '').trim(),
      favicon: (json['favicon'] as String? ?? '').trim(),
      country: (json['country'] as String? ?? '').trim(),
      countryCode: (json['countrycode'] as String? ?? '').trim(),
      state: (json['state'] as String? ?? '').trim(),
      language: (json['language'] as String? ?? '').trim(),
      tags: tags,
      codec: (json['codec'] as String? ?? '').trim(),
      bitrate: (json['bitrate'] as num?)?.toInt() ?? 0,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      clickCount: (json['clickcount'] as num?)?.toInt() ?? 0,
      homepage: (json['homepage'] as String? ?? '').trim(),
      hls: (json['hls'] as num?)?.toInt() == 1 || json['hls'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'stationuuid': stationUuid,
        'name': name,
        'url': url,
        'url_resolved': urlResolved,
        'favicon': favicon,
        'country': country,
        'countrycode': countryCode,
        'state': state,
        'language': language,
        'tags': tags.join(','),
        'codec': codec,
        'bitrate': bitrate,
        'votes': votes,
        'clickcount': clickCount,
        'homepage': homepage,
        'hls': hls ? 1 : 0,
      };

  RadioStation copyWith({
    String? stationUuid,
    String? name,
    String? url,
    String? urlResolved,
    String? favicon,
    String? country,
    String? countryCode,
    String? state,
    String? language,
    List<String>? tags,
    String? codec,
    int? bitrate,
    int? votes,
    int? clickCount,
    String? homepage,
    bool? hls,
  }) {
    return RadioStation(
      stationUuid: stationUuid ?? this.stationUuid,
      name: name ?? this.name,
      url: url ?? this.url,
      urlResolved: urlResolved ?? this.urlResolved,
      favicon: favicon ?? this.favicon,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      state: state ?? this.state,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      votes: votes ?? this.votes,
      clickCount: clickCount ?? this.clickCount,
      homepage: homepage ?? this.homepage,
      hls: hls ?? this.hls,
    );
  }
}
