import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'auth_screen.dart';
import 'tournament_list_screen.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // This listens to the StreamProvider<AppUser?> in main.dart
    final user = Provider.of<AppUser?>(context);
    
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        // The transitionBuilder adds a subtle fade for a "Premium" feel
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _getScreen(user),
      ),
    );
  }

  Widget _getScreen(AppUser? user) {
    if (user == null) {
      // ✅ Key allows AnimatedSwitcher to identify the change
      return const AuthScreen(key: ValueKey('AuthScreen'));
    } else {
      // ✅ Logged in: Proceed to the list of tournaments
      return const TournamentListScreen(key: ValueKey('TournamentListScreen'));
    }
  }
}