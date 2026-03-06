// screens/wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'auth_screen.dart';
import 'tournament_list_screen.dart';
import 'standings_screen.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 🛡️ SAFE BYPASS LOGIC
    try {
      final uri = Uri.base; 
      // Check if path contains 'results' OR if the query param 'tid' exists
      if (uri.path.contains('results') || uri.queryParameters.containsKey('tid')) {
        final String? tid = uri.queryParameters['tid'];
        if (tid != null && tid.isNotEmpty) {
          return PublicResultsScreen(tournamentId: tid);
        }
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