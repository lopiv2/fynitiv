import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReaderPageFlipKey = 'jellyfin.reader_page_flip_enabled';

/// Preferencia persistente para pasar página con animación de hoja (curl) en
/// el lector E-Reader. Activada por defecto.
class ReaderPageFlipNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_kReaderPageFlipKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_kReaderPageFlipKey, enabled);
  }
}

final readerPageFlipEnabledProvider =
    AsyncNotifierProvider<ReaderPageFlipNotifier, bool>(
      ReaderPageFlipNotifier.new,
    );
