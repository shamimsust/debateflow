import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // ⬅️ THIS IS THE CRITICAL IMPORT

// Services
import 'services/auth_service.dart';
import 'services/motion_service.dart';
import 'services/match_service.dart';
import 'services/standings_service.dart';

// Models
import 'models/user_model.dart';

// The Gatekeeper
import 'screens/wrapper.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // 🛠️ FIX: Use DefaultFirebaseOptions.currentPlatform
    // This automatically pulls the right keys for Web, Android, and iOS
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(const DebateFlowApp());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text("Startup Error: $e", style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    ));
  }
}

class DebateFlowApp extends StatelessWidget {
  const DebateFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<AppUser?>(
          create: (_) => AuthService().user,
          initialData: null,
          catchError: (_, _) => null,
        ),
        Provider<MotionService>(create: (_) => MotionService()),
        Provider<MatchService>(create: (_) => MatchService()),
        Provider<StandingsService>(create: (_) => StandingsService()),
      ],
      child: MaterialApp(
        title: 'DebateFlow 2026',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2264D7)),
          fontFamily: 'Inter',
        ),
        home: const Wrapper(),
      ),
    );
  }
}