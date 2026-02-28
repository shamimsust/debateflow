import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/match_service.dart';
import 'ballot_screen.dart';

class PairingScreen extends StatefulWidget {
  final String tournamentId;
  const PairingScreen({super.key, required this.tournamentId});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final MatchService _matchService = MatchService();
  int totalRounds = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 🛠️ DEBUG FIX 1: Safely load settings without 'as Map'
  void _loadSettings() {
    FirebaseDatabase.instance.ref('tournaments/${widget.tournamentId}').onValue.listen((event) {
      if (event.snapshot.exists) {
        final dynamic rawValue = event.snapshot.value;
        if (rawValue != null) {
          // Use dynamic access to avoid cast errors if settings is a JSArray
          final String prelimsStr = rawValue['prelims']?.toString() ?? '1';
          if (mounted) {
            setState(() {
              totalRounds = int.tryParse(prelimsStr) ?? 1;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(totalRounds), 
      length: totalRounds,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Tournament Pairings", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF2264D7),
          foregroundColor: Colors.white,
          elevation: 2,
          bottom: TabBar(
            isScrollable: totalRounds > 4,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelColor: Colors.white.withAlpha(150),
            tabs: List.generate(totalRounds, (i) => Tab(text: "Round ${i + 1}")),
          ),
        ),
        body: TabBarView(
          children: totalRounds == 0 
            ? [const Center(child: Text("No rounds configured"))]
            : List.generate(totalRounds, (i) {
                return RoundView(
                  tournamentId: widget.tournamentId,
                  roundNumber: i + 1,
                  isLastRound: (i + 1) == totalRounds,
                  matchService: _matchService,
                );
              }),
        ),
      ),
    );
  }
}

class RoundView extends StatefulWidget {
  final String tournamentId;
  final int roundNumber;
  final bool isLastRound;
  final MatchService matchService;

  const RoundView({
    super.key,
    required this.tournamentId,
    required this.roundNumber,
    required this.isLastRound,
    required this.matchService,
  });

  @override
  State<RoundView> createState() => _RoundViewState();
}

class _RoundViewState extends State<RoundView> with AutomaticKeepAliveClientMixin {
  bool _isGenerating = false;

  @override
  bool get wantKeepAlive => true;

  // 🛠️ DEBUG FIX 2: Refined handleGenerate to remove all 'as Map'
  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    final db = FirebaseDatabase.instance.ref();
    
    try {
      final tourneySnap = await db.child('tournaments/${widget.tournamentId}').get();
      if (!tourneySnap.exists) return;

      final dynamic tourneyData = tourneySnap.value;
      String tournamentRule = tourneyData['rule'] ?? "WSDC";
      String pairingType = "Random"; 
      
      try {
        if (tourneyData['settings'] != null && tourneyData['settings']['pairingRules'] != null) {
          pairingType = tourneyData['settings']['pairingRules'][widget.roundNumber.toString()]?.toString() ?? "Random";
        }
      } catch (_) {}

      final teamsSnap = await db.child('teams/${widget.tournamentId}').get();
      List teams = [];
      
      if (teamsSnap.exists) {
        // USE .children TO AVOID JSArray ERROR COMPLETELY
        for (var child in teamsSnap.children) {
          final dynamic t = child.value;
          if (t != null) {
            teams.add({
              "id": child.key,
              "name": t['name'] ?? "Unknown",
              "wins": (t['wins'] ?? 0).toDouble(),
              "totalMarks": (t['totalMarks'] ?? 0.0).toDouble(),
            });
          }
        }

        // Sorting is fine now because 'teams' is a standard Dart List
        if (pairingType == "Power Paired") {
          teams.sort((a, b) => b['wins'] != a['wins'] 
              ? (b['wins']).compareTo(a['wins']) 
              : (b['totalMarks']).compareTo(a['totalMarks']));
        } else {
          teams.shuffle();
        }

        await widget.matchService.generateMatches(
          tournamentId: widget.tournamentId,
          roundNumber: widget.roundNumber,
          teams: teams,
          rule: tournamentRule, 
        );
      }
    } catch (e) {
      debugPrint("PAIRING DEBUG: Error caught: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final matchRef = FirebaseDatabase.instance.ref('matches/${widget.tournamentId}/round_${widget.roundNumber}');

    return StreamBuilder(
      stream: matchRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        // 🛠️ DEBUG FIX 3: Robust Check for Empty matches
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _buildEmptyState();
        }

        List matches = [];
        // USE .children TO PREVENT THE JSArray CRASH ON UI RENDER
        for (var child in snapshot.data!.snapshot.children) {
          final dynamic val = child.value;
          if (val != null) {
            matches.add({"id": child.key, ...Map<String, dynamic>.from(val as Map)});
          }
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Round ${widget.roundNumber}: ${matches.length} Matches", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2264D7), fontSize: 12)),
                  TextButton.icon(
                    onPressed: _isGenerating ? null : _handleReset,
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.redAccent),
                    label: const Text("CLEAR ROUND", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: matches.length,
                itemBuilder: (context, index) => _buildMatchCard(matches[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper to safely handle resets
  Future<void> _handleReset() async {
    setState(() => _isGenerating = true);
    await FirebaseDatabase.instance.ref('matches/${widget.tournamentId}/round_${widget.roundNumber}').remove();
    if (mounted) setState(() => _isGenerating = false);
  }

  Widget _buildMatchCard(Map m) {
    bool isCompleted = m['status'] == 'Completed';
    bool isBye = m['is_bye'] ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(isBye ? "${m['sideA']} (BYE)" : "${m['sideA'] ?? 'TBD'} vs ${m['sideB'] ?? 'TBD'}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isBye ? "Automatic Win" : "${m['room'] ?? 'TBD'} • ${m['judge'] ?? 'TBD'}"),
        trailing: Icon(isCompleted ? Icons.check_circle : Icons.pending_actions, color: isCompleted ? Colors.green : Colors.orange),
        onTap: isBye ? null : () {
          Navigator.push(context, MaterialPageRoute(builder: (c) => BallotScreen(
            tournamentId: widget.tournamentId,
            matchId: m['id'],
            matchData: Map<String, dynamic>.from(m),
          )));
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.grid_view_rounded, size: 60, color: Colors.black12),
          const SizedBox(height: 16),
          Text("Round ${widget.roundNumber} is ready to pair."),
          const SizedBox(height: 20),
          _isGenerating ? const CircularProgressIndicator() : ElevatedButton(onPressed: _handleGenerate, child: const Text("GENERATE MATCHES")),
        ],
      ),
    );
  }
}