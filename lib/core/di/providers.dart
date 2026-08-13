import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/session_storage.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorage(secure: ref.watch(flutterSecureStorageProvider)),
);
