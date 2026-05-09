import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'auth_screen.dart';
import 'tournament_list_screen.dart';
import 'standings_screen.dart';
import 'public_pairing_screen.dart'; // ✅ Added this import
import '../utils/web_utils.dart';
import '../utils/startup_utils.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 🛡️ SAFE BYPASS LOGIC
    try {
      String? href;
      if (initialLaunchHref != null && initialLaunchHref!.isNotEmpty) {
        href = initialLaunchHref;
      }

      final uri = Uri.base;
      href ??= initialHref.isNotEmpty ? initialHref : getLocationHref();

      // Updated helper to handle both 'results' and 'pairings'
      Map<String, String?> extractRouteInfo(Uri u) {
        String? id = u.queryParameters['tid'];
        String? type;

        // Check path segments
        if (u.pathSegments.isNotEmpty) {
          if (u.pathSegments.contains('results')) {
            type = 'results';
            final idx = u.pathSegments.indexOf('results');
            if (u.pathSegments.length > idx + 1) id ??= u.pathSegments[idx + 1];
          } else if (u.pathSegments.contains('pairings')) {
            type = 'pairings';
            final idx = u.pathSegments.indexOf('pairings');
            if (u.pathSegments.length > idx + 1) id ??= u.pathSegments[idx + 1];
          } else if (u.pathSegments.contains('pairing')) { // Typo protection
            type = 'pairings';
            final idx = u.pathSegments.indexOf('pairing');
            if (u.pathSegments.length > idx + 1) id ??= u.pathSegments[idx + 1];
          }
        }

        // Check fragment (for older hash-style URLs)
        if (id == null && u.fragment.isNotEmpty) {
          try {
            final frag = Uri.parse(u.fragment.startsWith('/') ? u.fragment : '/${u.fragment}');
            if (frag.pathSegments.contains('results')) {
              type = 'results';
              final idx = frag.pathSegments.indexOf('results');
              if (frag.pathSegments.length > idx + 1) id = frag.pathSegments[idx + 1];
            } else if (frag.pathSegments.contains('pairings')) {
              type = 'pairings';
              final idx = frag.pathSegments.indexOf('pairings');
              if (frag.pathSegments.length > idx + 1) id = frag.pathSegments[idx + 1];
            }
          } catch (_) {}
        }

        return {'tid': id, 'type': type};
      }

      // First check Uri.base
      var routeInfo = extractRouteInfo(uri);
      
      // Fallback to recorded href
      if (routeInfo['tid'] == null && href.isNotEmpty) {
        try {
          routeInfo = extractRouteInfo(Uri.parse(href));
        } catch (_) {}
      }

      final tid = routeInfo['tid'];
      final type = routeInfo['type'];

      if (tid != null && tid.isNotEmpty) {
        if (type == 'results') {
          debugPrint('Wrapper routing to PublicResultsScreen: $tid');
          return PublicResultsScreen(tournamentId: tid);
        } else if (type == 'pairings') {
          debugPrint('Wrapper routing to PublicPairingScreen: $tid');
          return PublicPairingScreen(tournamentId: tid);
        }
      }
    } catch (e) {
      debugPrint("Routing error in Wrapper: $e");
    }

    // --- Normal Logic (Auth Protected) ---
    final user = Provider.of<AppUser?>(context);
    
    if (user == null) {
      return const AuthScreen();
    } else {
      return const TournamentListScreen();
    }
  }
}