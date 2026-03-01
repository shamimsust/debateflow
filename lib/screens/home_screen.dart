import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import 'add_team_screen.dart'; 
import 'standings_screen.dart'; 
import 'pairing_screen.dart';
import 'admin_motion_control.dart'; 
import 'setup_screen.dart'; 

class HomeScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const HomeScreen({
    super.key, 
    required this.tournamentId, 
    required this.tournamentName
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentRound = "1";

  @override
  void initState() {
    super.initState();
    _listenToRoundStatus();
  }

  void _listenToRoundStatus() {
    FirebaseDatabase.instance
        .ref('tournaments/${widget.tournamentId}/currentRound')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        // 🛡️ Safe Parsing: Handles both int and String from Firebase
        setState(() => _currentRound = event.snapshot.value.toString());
      }
    }, onError: (err) => debugPrint("DB Error: $err"));
  }

  @override
  Widget build(BuildContext context) {
    final dbRef = FirebaseDatabase.instance.ref();
    final teamsRef = dbRef.child('teams').child(widget.tournamentId);
    final judgesRef = dbRef.child('adjudicators').child(widget.tournamentId);
    final matchesRef = dbRef.child('matches').child(widget.tournamentId);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.tournamentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      // 🚀 FIXED: Added a simple ScrollView with correct constraints
      body: ListView( 
        padding: const EdgeInsets.all(20.0),
        children: [
          Row(
            children: [
              _buildStatCard("Teams", teamsRef, Icons.groups_rounded),
              const SizedBox(width: 12),
              _buildStatCard("Judges", judgesRef, Icons.gavel_rounded),
            ],
          ),
          const SizedBox(height: 15),
          _buildStatusCard(matchesRef),
          
          const SizedBox(height: 30),
          const Text("TOURNAMENT MANAGEMENT", 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.5)),
          const SizedBox(height: 15),

          // 🛠️ The GridView fix: shrinkWrap + NeverScrollableScrollPhysics
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), 
            children: [
              _buildAdminCard(
                title: "Teams",
                subtitle: "Registration",
                icon: Icons.person_add_alt_1,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (c) => AddTeamScreen(tournamentId: widget.tournamentId))),
              ),
              _buildAdminCard(
                title: "Pairings",
                subtitle: "Round $_currentRound",
                icon: Icons.account_tree_rounded,
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (c) => PairingScreen(tournamentId: widget.tournamentId))),
              ),
              _buildAdminCard(
                title: "Standings",
                subtitle: "Rankings",
                icon: Icons.leaderboard_rounded,
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (c) => StandingsScreen(tournamentId: widget.tournamentId))),
              ),
              _buildAdminCard(
                title: "Setup",
                subtitle: "Rules & Rooms",
                icon: Icons.settings_suggest_rounded,
                color: Colors.blueGrey,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (c) => SetupScreen(tournamentId: widget.tournamentId))),
              ),
              _buildAdminCard(
                title: "Motion Control",
                subtitle: "Set & Reveal",
                icon: Icons.bolt_rounded,
                color: Colors.amber.shade800,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (c) => AdminMotionControl(tournamentId: widget.tournamentId))),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI COMPONENTS (KEEPING YOUR EXISTING LOGIC) ---

  Widget _buildStatCard(String title, DatabaseReference ref, IconData icon) {
    return Expanded(
      child: StreamBuilder(
        stream: ref.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          int count = 0;
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value;
            if (data is Map) count = data.length;
          }
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2264D7), size: 28),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$count", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(DatabaseReference matchRootRef) {
    return StreamBuilder(
      stream: matchRootRef.child('round_$_currentRound').onValue,
      builder: (context, snapshot) {
        bool inProgress = snapshot.hasData && snapshot.data!.snapshot.value != null;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: inProgress 
                ? [const Color(0xFF2264D7), const Color(0xFF46C3D7)]
                : [const Color(0xFF475569), const Color(0xFF64748B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ROUND $_currentRound STATUS", 
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text(inProgress ? "Matches Live" : "Waiting for Pairings", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminCard({
    required String title, 
    required String subtitle,
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}