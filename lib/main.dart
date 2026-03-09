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

// The actual variable lives in a separate utils file so that other
// modules (like Wrapper) can import it without creating a circular import.
import 'utils/startup_utils.dart';


void main() {
  // ✅ Clean URLs (Removes the # hash)
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  // capture the URL right now
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

 // main.dart - Build Method
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
      initialRoute: '/',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2264D7)),
      // ---------------------------------------------
      // deep link support for public results
      // ---------------------------------------------
      // Flutter's router will consult this before building
      // the home widget.  The Wrapper still runs as a
      // fallback, but adding this ensures that the correct
      // screen is pushed even on hot reload or in dev
      // environments where Uri.base parsing may differ.
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        debugPrint('onGenerateRoute: ${settings.name} -> $uri');
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'results') {
          String? tid;
          if (uri.pathSegments.length > 1) {
            tid = uri.pathSegments[1];
          }
          tid ??= uri.queryParameters['tid'];
          if (tid != null && tid.isNotEmpty) {
            final nonNullTid = tid; // local copy, flow ensures not null
            return MaterialPageRoute(
              builder: (_) => PublicResultsScreen(tournamentId: nonNullTid),
            );
          }
        }
        return MaterialPageRoute(builder: (_) => const Wrapper());
      },
      home: const Wrapper(),
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