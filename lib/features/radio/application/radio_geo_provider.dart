import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'radio_providers.dart';

/// País detectado vía locale del sistema (sin permisos GPS).
final radioGeoCountryProvider = Provider<String?>((_) {
  final locale = ui.PlatformDispatcher.instance.locale;
  final cc = locale.countryCode?.toUpperCase();
  if (cc == null || cc.isEmpty) return null;
  return _countryCodeToName[cc];
});

/// Radio destacadas según geolocalización (locale).
final radioFeaturedByCountryProvider = FutureProvider((ref) async {
  final api = ref.watch(radioApiProvider);
  final country = ref.watch(radioGeoCountryProvider);
  final target = country ?? 'Spain';
  try {
    final list = await api.search(country: target, order: 'votes', limit: 8);
    if (list.isNotEmpty) return list;
  } catch (_) {}
  // Fallback global top
  return api.topStations(limit: 8);
});

const _countryCodeToName = {
  'ES': 'Spain',
  'US': 'United States',
  'GB': 'United Kingdom',
  'UK': 'United Kingdom',
  'FR': 'France',
  'DE': 'Germany',
  'IT': 'Italy',
  'PT': 'Portugal',
  'MX': 'Mexico',
  'AR': 'Argentina',
  'CO': 'Colombia',
  'CL': 'Chile',
  'PE': 'Peru',
  'BR': 'Brazil',
  'CA': 'Canada',
  'AU': 'Australia',
  'JP': 'Japan',
  'KR': 'South Korea',
  'IN': 'India',
  'PL': 'Poland',
  'NL': 'Netherlands',
  'BE': 'Belgium',
  'SE': 'Sweden',
  'NO': 'Norway',
  'DK': 'Denmark',
  'FI': 'Finland',
  'TR': 'Turkey',
  'RU': 'Russia',
  'UA': 'Ukraine',
  'GR': 'Greece',
  'RO': 'Romania',
  'CZ': 'Czech Republic',
  'HU': 'Hungary',
  'AT': 'Austria',
  'CH': 'Switzerland',
  'IE': 'Ireland',
  'NZ': 'New Zealand',
  'ZA': 'South Africa',
};
