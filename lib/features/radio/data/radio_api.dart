library;

import 'dart:convert';

import 'package:dio/dio.dart';

import 'radio_station.dart';

/// País para filtros de Radio Browser con bandera.
class RadioCountry {
  const RadioCountry({required this.name, required this.code});

  final String name;
  final String code; // ISO 3166-1 alpha-2, ej. "ES"

  /// Emoji de bandera a partir del código ISO. Vacío si no hay código.
  String get flag {
    if (code.length != 2) return '';
    final c = code.toUpperCase();
    final a = c.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = c.codeUnitAt(1) - 0x41 + 0x1F1E6;
    if (a < 0x1F1E6 || a > 0x1F1FF || b < 0x1F1E6 || b > 0x1F1FF) return '';
    return String.fromCharCode(a) + String.fromCharCode(b);
  }
}

/// Fallback nombre -> código para países donde el mirror no trae iso_3166_1.
const _countryNameToCode = <String, String>{
  'Spain': 'ES',
  'United States': 'US',
  'United Kingdom': 'GB',
  'France': 'FR',
  'Germany': 'DE',
  'Italy': 'IT',
  'Portugal': 'PT',
  'Mexico': 'MX',
  'Argentina': 'AR',
  'Colombia': 'CO',
  'Chile': 'CL',
  'Peru': 'PE',
  'Brazil': 'BR',
  'Canada': 'CA',
  'Australia': 'AU',
  'Japan': 'JP',
  'South Korea': 'KR',
  'India': 'IN',
  'Poland': 'PL',
  'Netherlands': 'NL',
  'Belgium': 'BE',
  'Sweden': 'SE',
  'Norway': 'NO',
  'Denmark': 'DK',
  'Finland': 'FI',
  'Turkey': 'TR',
  'Russia': 'RU',
  'Ukraine': 'UA',
  'Greece': 'GR',
  'Romania': 'RO',
  'Czech Republic': 'CZ',
  'Hungary': 'HU',
  'Austria': 'AT',
  'Switzerland': 'CH',
  'Ireland': 'IE',
  'New Zealand': 'NZ',
  'South Africa': 'ZA',
  'The United Kingdom Of Great Britain And Northern Ireland': 'GB',
  'The United States Of America': 'US',
};

/// Cliente para Radio Browser API.
///
/// Usa https://all.api.radio-browser.info (round-robin de mirrors) con
/// fallback a de1.api.radio-browser.info. Todas las llamadas requieren
/// User-Agent según docs.
class RadioApi {
  RadioApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _primaryBase = 'https://all.api.radio-browser.info';
  static const _fallbackBase = 'https://de1.api.radio-browser.info';
  static const _userAgent = 'Fynitiv/1.0 (Radio)';

  Options get _opts => Options(
        headers: {'User-Agent': _userAgent},
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      );

  Future<List<RadioStation>> _getStations(String path, Map<String, dynamic> query) async {
    DioException? lastErr;
    for (final base in [_primaryBase, _fallbackBase]) {
      try {
        final res = await _dio.get<Object?>(
          '$base/json/$path',
          queryParameters: query,
          options: _opts,
        );
        final data = res.data;
        final list = _parseList(data);
        return list.map((e) => RadioStation.fromJson(e as Map<String, dynamic>)).toList();
      } on DioException catch (e) {
        lastErr = e;
        continue;
      }
    }
    throw lastErr ?? Exception('Radio Browser unavailable');
  }

  List<dynamic> _parseList(Object? data) {
    if (data is List) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is List) return decoded;
    }
    return const [];
  }

  /// Top emisoras por votos.
  Future<List<RadioStation>> topStations({int limit = 100, int offset = 0}) {
    return _getStations('stations/topvote', {
      'limit': limit,
      'offset': offset,
      'hidebroken': true,
    });
  }

  /// Top con más clicks.
  Future<List<RadioStation>> topClickStations({int limit = 100, int offset = 0}) {
    return _getStations('stations/topclick', {
      'limit': limit,
      'offset': offset,
      'hidebroken': true,
    });
  }

  /// Búsqueda por nombre / tag / país / idioma.
  Future<List<RadioStation>> search({
    String name = '',
    String tag = '',
    String country = '',
    String language = '',
    String codec = '',
    int limit = 100,
    int offset = 0,
    String order = 'votes',
    bool reverse = true,
  }) {
    return _getStations('stations/search', {
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (tag.trim().isNotEmpty) 'tag': tag.trim(),
      if (country.trim().isNotEmpty) 'country': country.trim(),
      if (language.trim().isNotEmpty) 'language': language.trim(),
      if (codec.trim().isNotEmpty) 'codec': codec.trim(),
      'limit': limit,
      'offset': offset,
      'hidebroken': true,
      'order': order,
      'reverse': reverse,
    });
  }

  /// Por UUID exacto (para favoritos persistidos).
  /// Radio Browser usa path param: /json/stations/byuuid/{uuid1,uuid2}
  Future<List<RadioStation>> byUuids(List<String> uuids) async {
    if (uuids.isEmpty) return const [];
    final joined = uuids.map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
    if (joined.isEmpty) return const [];
    try {
      return await _getStations('stations/byuuid/$joined', {});
    } catch (_) {
      // Fallback: intentar de uno en uno si el batch falla (algunos mirrors no soportan batch)
      final result = <RadioStation>[];
      for (final id in uuids) {
        try {
          final single = await _getStations('stations/byuuid/$id', {});
          result.addAll(single);
        } catch (_) {}
      }
      return result;
    }
  }

  Future<RadioStation?> byUuid(String uuid) async {
    if (uuid.trim().isEmpty) return null;
    try {
      final list = await _getStations('stations/byuuid/${uuid.trim()}', {});
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  /// Click counter + devuelve URL fresca (Radio Browser GET /json/url/{uuid} → {"url":"http://..."}).
  Future<void> click(String stationUuid) async {
    await resolveStreamUrl(stationUuid);
  }

  Future<String?> resolveStreamUrl(String stationUuid) async {
    if (stationUuid.isEmpty) return null;
    for (final base in [_primaryBase, _fallbackBase]) {
      try {
        final res = await _dio.get<Object?>(
          '$base/json/url/$stationUuid',
          options: Options(
            headers: {'User-Agent': _userAgent},
            responseType: ResponseType.json,
            validateStatus: (_) => true,
          ),
        );
        final data = res.data;
        if (data is Map && data['url'] is String && (data['url'] as String).trim().isNotEmpty) {
          return (data['url'] as String).trim();
        }
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map && decoded['url'] is String) return (decoded['url'] as String).trim();
          } catch (_) {}
        }
        return null;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // Listas para filtros (no requieren hidebroken).

  Future<List<RadioCountry>> countries() async {
    for (final base in [_primaryBase, _fallbackBase]) {
      try {
        final res = await _dio.get<Object?>(
          '$base/json/countries',
          options: _opts,
        );
        final list = _parseList(res.data);
        final out = <RadioCountry>[];
        for (final e in list) {
          if (e is Map) {
            final n = (e['name'] as String?)?.trim() ?? '';
            if (n.isEmpty) continue;
            final rawCode = (e['iso_3166_1'] as String?)?.trim().toUpperCase() ?? '';
            // Algunos mirrors devuelven código vacío para "The United..." etc. Intentar fallback.
            final code = rawCode.isNotEmpty ? rawCode : _countryNameToCode[n] ?? '';
            out.add(RadioCountry(name: n, code: code));
          }
        }
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return out;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  Future<List<String>> languages({int limit = 200}) async {
    for (final base in [_primaryBase, _fallbackBase]) {
      try {
        final res = await _dio.get<Object?>(
          '$base/json/languages',
          queryParameters: {'limit': limit},
          options: _opts,
        );
        final list = _parseList(res.data);
        final names = <String>[];
        for (final e in list) {
          if (e is Map && e['name'] is String) {
            final n = (e['name'] as String).trim();
            if (n.isNotEmpty) names.add(n);
          }
        }
        names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return names;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  Future<List<String>> tags({int limit = 200}) async {
    for (final base in [_primaryBase, _fallbackBase]) {
      try {
        final res = await _dio.get<Object?>(
          '$base/json/tags',
          queryParameters: {'limit': limit, 'order': 'stationcount', 'reverse': true},
          options: _opts,
        );
        final list = _parseList(res.data);
        final names = <String>[];
        for (final e in list) {
          if (e is Map && e['name'] is String) {
            final n = (e['name'] as String).trim();
            if (n.isNotEmpty) names.add(n);
          }
        }
        return names;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }
}
