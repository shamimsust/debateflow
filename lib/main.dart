import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
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
import 'screens/standings_screen.dart'; 
import 'screens/public_pairing_screen.dart'; 

// Utils
import 'utils/startup_utils.dart';

void main() {
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  if (kIsWeb) {
    initialLaunchHref = Uri.base.toString();
    debugPrint('main captured initialLaunchHref = $initialLaunchHref');
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

  /// ✅ Centralized Routing Logic
  /// This prevents the Wrapper from triggering a login redirect for public links.
  Route<dynamic> _handleRouting(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '');
    debugPrint('Routing request: ${settings.name}');

    // Helper to extract Tournament ID
    String? tid;
    if (uri.pathSegments.length > 1) {
      tid = uri.pathSegments[1];
    }
    tid ??= uri.queryParameters['tid'];

    if (uri.pathSegments.isNotEmpty) {
      final String firstSegment = uri.pathSegments.first.toLowerCase();

      // 1. PUBLIC RESULTS/STANDINGS
      if (firstSegment == 'results' && tid != null && tid.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PublicResultsScreen(tournamentId: tid!),
        );
      }

      // 2. PUBLIC PAIRINGS (Bypasses Wrapper/Login)
      if ((firstSegment == 'pairings' || firstSegment == 'pairing') && tid != null && tid.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PublicPairingScreen(tournamentId: tid!),
        );
      }
    }

    // 3. DEFAULT (Auth-Protected Area)
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const Wrapper(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(home: Scaffold(body: Center(child: Text("Error: $_error"))));
    }

    if (!_isInitialized) {
      return const MaterialApp(debugShowCheckedModeBanner: false, home: _SplashScreen());
    }

    return MultiProvider(
      providers: [
        StreamProvider<AppUser?>(
          create: (_) => AuthService().user,
          initialData: null,
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
          colorSchemeSeed: const Color(0xFF2264D7),
        ),
        
        // ✅ KEY FIX: Handle the very first URL load immediately
        onGenerateInitialRoutes: (initialRoute) {
          return [_handleRouting(RouteSettings(name: initialRoute))];
        },

        // ✅ Handle internal navigation
        onGenerateRoute: (settings) => _handleRouting(settings),

        // 'home' is omitted here because onGenerateInitialRoutes takes precedence
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen(); 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2264D7), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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