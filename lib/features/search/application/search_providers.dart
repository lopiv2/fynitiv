import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../auth/application/auth_controller.dart';

/// Resultados de búsqueda para un término.
final searchHintsProvider = FutureProvider.family<List<SearchHint>, String>(
  (ref, term) async {
    if (term.trim().isEmpty) return const [];
    final client = ref.watch(authControllerProvider.notifier).client;
    final userId = ref.watch(authControllerProvider).userId;
    if (client == null || userId == null) return const [];
    final res = await client.getSearchApi().getSearchHints(
          searchTerm: term.trim(),
          userId: userId,
          limit: 50,
        );
    return res.data?.searchHints ?? [];
  },
);
