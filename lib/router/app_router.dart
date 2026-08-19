import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/household/application/household_provider.dart';
import '../features/household/domain/household.dart';
import '../features/household/presentation/household_wizard_screen.dart';
import '../features/library/presentation/home_screen.dart';
import '../features/library/presentation/library_view_screen.dart';
import '../features/live_tv/presentation/live_fullscreen_player.dart';
import '../features/live_tv/presentation/live_tv_screen.dart';
import '../features/movies/presentation/all_movies_screen.dart';
import '../features/music/presentation/music_screen.dart';
import '../features/games/presentation/game_detail_screen.dart';
import '../features/games/presentation/game_list_screen.dart';
import '../features/games/presentation/games_screen.dart';
import '../features/player/presentation/player_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/vod/presentation/vod_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/users/presentation/user_selection_screen.dart';
import 'home_shell.dart';
import 'splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final household = ref.read(householdProvider);
      final location = state.matchedLocation;
      switch (authState.status) {
        case AuthStatus.unknown:
          return location == '/splash' ? null : '/splash';
        case AuthStatus.authenticated:
          return (location == '/splash' ||
                  location == '/users' ||
                  location == '/setup')
              ? '/home'
              : null;
        case AuthStatus.unauthenticated:
          // Sin servidor → el wizard lo pide en su primer paso.
          if (authState.serverUrl == null) {
            return location == '/setup' ? null : '/setup';
          }
          // La casa es válida solo si coincide con el servidor actual.
          final houseMatchesServer = household != null &&
              household.serverId != null &&
              household.matchesServer(authState.serverId);
          // Sin casa (o casa de otro servidor) → asistente.
          if (household == null || !houseMatchesServer) {
            return location == '/setup' ? null : '/setup';
          }
          // Con casa válida: se permite la selección de usuarios y gestionarla.
          return (location == '/users' || location == '/setup')
              ? null
              : '/users';
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/setup',
        builder: (context, state) => HouseholdWizardScreen(
          initialHousehold: state.extra is Household
              ? state.extra as Household
              : null,
        ),
      ),
      GoRoute(
        path: '/users',
        builder: (_, _) => const UserSelectionScreen(),
      ),
      // Reproductor a pantalla completa (fuera del shell para cubrir todo).
      GoRoute(
        path: '/player/:itemId',
        builder: (context, state) => PlayerScreen(
          itemId: state.pathParameters['itemId']!,
          item: state.extra is BaseItemDto ? state.extra as BaseItemDto : null,
        ),
      ),
      // Live TV a pantalla completa (usa el motor compartido de Live TV).
      GoRoute(
        path: '/live/fullscreen',
        builder: (_, _) => const LiveTvFullscreenPlayer(),
      ),
      // Todas las películas del servidor (grid con desplazamiento infinito).
      GoRoute(
        path: '/movies',
        builder: (_, _) => const AllMoviesScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/library/:viewId',
                builder: (context, state) => LibraryViewScreen(
                  viewId: state.pathParameters['viewId']!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, _) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vod',
                builder: (_, _) => const VodScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                builder: (_, _) => const LiveTvScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/music',
                builder: (_, _) => const MusicScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:albumId',
                    builder: (context, state) => MusicAlbumScreen(
                      albumId: state.pathParameters['albumId']!,
                      album: state.extra is BaseItemDto
                          ? state.extra as BaseItemDto
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/games',
                builder: (_, _) => const GamesScreen(),
                routes: [
                  GoRoute(
                    path: 'platform/:platformId',
                    builder: (context, state) => GameListScreen(
                      platformId:
                          int.tryParse(state.pathParameters['platformId']!) ?? 0,
                    ),
                  ),
                  GoRoute(
                    path: 'rom/:romId',
                    builder: (context, state) => GameDetailScreen(
                      gameId: int.tryParse(state.pathParameters['romId']!) ?? 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Refresca el redirect sin recrear el router, preservando la navegación.
  ref.listen(authControllerProvider, (_, _) => router.refresh());
  ref.listen(householdProvider, (_, _) => router.refresh());

  return router;
});
