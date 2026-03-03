import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Fixes 'kIsWeb'
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; 
import 'firebase_options.dart'; 

// Services
import 'services/auth_service.dart';
import 'services/motion_service.dart';
import 'services/match_service.dart';
import 'services/standings_service.dart';

// Models
import 'models/user_model.dart';

// Screens
import 'screens/wrapper.dart';
import 'screens/standings_screen.dart'; // Ensure PublicResultsScreen is here

void main() {
  // ✅ Clean URLs (No '#' on web)
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DebateFlowApp());
}

class DebateFlowApp extends StatefulWidget {
  const DebateFlowApp({super.key});

  @override
  State<DebateFlowApp> createState() => _DebateFlowAppState();
}

class _DebateFlowAppState extends State<DebateFlowApp> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // 🚀 Initialize Firebase & Services
  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show Error Screen if something breaks
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Fatal Error: $_error", style: const TextStyle(color: Colors.red))),
        ),
      );
    }

    // 2. Show Splash Screen while loading
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _SplashScreen(),
      );
    }

    // 3. Main App with Providers
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
        onGenerateRoute: (settings) {
          final Uri uri = Uri.parse(settings.name ?? "/");
          
          if (uri.path == '/results') {
            final String? tid = uri.queryParameters['tid'];
            if (tid != null) {
              return MaterialPageRoute(
                builder: (context) => PublicResultsScreen(tournamentId: tid),
              );
            }
          }
          return MaterialPageRoute(builder: (context) => const Wrapper());
        },
      ),
    );
  }
}

// --- BEAUTIFUL SPLASH UI ---
class _SplashScreen extends StatelessWidget {
  const _SplashScreen(); // Added key for best practice

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2264D7), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Fixed: record_voice_over (lowercase)
            const Icon(Icons.record_voice_over_rounded, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              "DEBATEFLOW",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 48),
            // ✅ Always keep the indicator white for dark backgrounds
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}