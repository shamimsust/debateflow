// screens/wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'auth_screen.dart';
import 'tournament_list_screen.dart';
import 'standings_screen.dart';
import '../utils/web_utils.dart';
import '../utils/startup_utils.dart';


class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 🛡️ SAFE BYPASS LOGIC
    try {
      // Try to use the URL that was present when main() started.  Mobile
      // builds and some dev scenarios don't set this, so we still fall back
      // to the other strategies below.
      String? href;
      if (initialLaunchHref != null && initialLaunchHref!.isNotEmpty) {
        href = initialLaunchHref;
        debugPrint('Wrapper using initialLaunchHref = $href');
      }

      final uri = Uri.base;
      debugPrint('Wrapper received Uri.base = $uri');
      // if we haven't got one yet, use the captured href or current href
      href ??= initialHref.isNotEmpty ? initialHref : getLocationHref();
      if (href.isNotEmpty) debugPrint('Wrapper window.location.href = $href');

      // helper that attempts to pull tid from any part of a URL.  When the
      // app is deployed we use `usePathUrlStrategy()` so links look like
      // `https://.../results/<tid>`.  In case the query string is used or the
      // browser adds a fragment (older hash–style), we support all three.
      // `Uri.base` only reflects the value at initial load, so we also parse
      // the raw href from `window.location` on web as a fallback.  This fixes
      // cases where the dev server or Flutter itself has already changed the
      // history state without updating `Uri.base`.
      String? tid;

      // small helper used repeatedly
      String? extractTid(Uri u) {
        String? id;
        id = u.queryParameters['tid'];
        if (id != null && id.isNotEmpty) return id;
        if (u.pathSegments.isNotEmpty) {
          final idx = u.pathSegments.indexOf('results');
          if (idx != -1 && u.pathSegments.length > idx + 1) return u.pathSegments[idx + 1];
        }
        if (u.fragment.isNotEmpty) {
          try {
            final frag = Uri.parse(u.fragment);
            final fromQuery = frag.queryParameters['tid'];
            if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
            if (frag.pathSegments.isNotEmpty) {
              final idx = frag.pathSegments.indexOf('results');
              if (idx != -1 && frag.pathSegments.length > idx + 1) {
                return frag.pathSegments[idx + 1];
              }
            }
          } catch (_) {}
        }
        return null;
      }

      tid = extractTid(uri);
      if (tid != null && tid.isNotEmpty) {
        debugPrint('Wrapper found tid via Uri.base: $tid');
      }

      // if we still don't have one, try whatever href value we recorded
      // earlier (initialLaunchHref, initialHref, or current href).
      if ((tid == null || tid.isEmpty) && href.isNotEmpty) {
        try {
          final hrefUri = Uri.parse(href);
          final got = extractTid(hrefUri);
          if (got != null && got.isNotEmpty) {
            tid = got;
            debugPrint('Wrapper found tid via recorded href: $tid');
          }
        } catch (_) {}
      }

      if (tid != null && tid.isNotEmpty) {
        debugPrint('Wrapper routing to PublicResultsScreen with tid=$tid');
        return PublicResultsScreen(tournamentId: tid);
      }
    } catch (e) {
      // If URL parsing fails, don't crash with a white screen!
      debugPrint("Routing error: $e");
    }

    // --- Normal Logic ---
    final user = Provider.of<AppUser?>(context);
    
    if (user == null) {
      return const AuthScreen();
    } else {
      return const TournamentListScreen();
    }
  }
}