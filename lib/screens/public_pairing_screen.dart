import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PublicPairingScreen extends StatefulWidget {
  final String tournamentId;
  const PublicPairingScreen({super.key, required this.tournamentId});

  @override
  State<PublicPairingScreen> createState() => _PublicPairingScreenState();
}

class _PublicPairingScreenState extends State<PublicPairingScreen> {
  int totalRounds = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    FirebaseDatabase.instance
        .ref('tournaments/${widget.tournamentId}')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final dynamic rawValue = event.snapshot.value;
        if (rawValue is Map) {
          final String prelimsStr = rawValue['prelims']?.toString() ?? '1';
          if (mounted) {
            setState(() {
              totalRounds = double.tryParse(prelimsStr)?.toInt() ?? 1;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: totalRounds,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text("Tournament Draw", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            isScrollable: totalRounds > 4,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: List.generate(totalRounds, (i) => Tab(text: "Round ${i + 1}")),
          ),
        ),
        body: TabBarView(
          children: List.generate(totalRounds, (i) {
            return PublicRoundView(
              tournamentId: widget.tournamentId,
              roundNumber: i + 1,
            );
          }),
        ),
      ),
    );
  }
}

class PublicRoundView extends StatelessWidget {
  final String tournamentId;
  final int roundNumber;

  const PublicRoundView({super.key, required this.tournamentId, required this.roundNumber});

  @override
  Widget build(BuildContext context) {
    final String roundKey = "round_$roundNumber";

    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('tournaments/$tournamentId/rounds/$roundKey').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final data = snapshot.data!.snapshot.value as Map?;
        final String status = data?['status'] ?? "Not Generated";

        if (status != "Released") {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_person_rounded, size: 64, color: Colors.blueGrey.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                const Text("Round draw hasn't been released yet.", 
                  style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return StreamBuilder(
          stream: FirebaseDatabase.instance.ref('matches/$tournamentId/$roundKey').onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> matchSnap) {
            if (!matchSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            final dynamic rawMatchData = matchSnap.data!.snapshot.value;
            if (rawMatchData == null || rawMatchData is! Map) {
              return const Center(child: Text("No matches found."));
            }

            // Web-safe map conversion
            final Map<dynamic, dynamic> matchMap = rawMatchData;
            List<Map<String, dynamic>> matches = [];
            matchMap.forEach((key, val) {
              if (val is Map) {
                matches.add(Map<String, dynamic>.from(val));
              }
            });

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: matches.length,
              itemBuilder: (context, index) => _buildPublicMatchCard(matches[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildPublicMatchCard(Map<String, dynamic> m) {
    bool isBP = m['rule'] == "BP";
    final List judgeList = m['judges'] is List ? m['judges'] : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.meeting_room_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  "ROOM: ${m['room']?.toString().toUpperCase() ?? "TBD"}",
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155), fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: isBP ? _buildBPLayout(m) : _buildWSDCLayout(m),
          ),
          // Judges Footer
          if (judgeList.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, size: 14, color: Color(0xFF2264D7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      judgeList.map((e) => e is Map ? e['name'] : e.toString()).join(", "),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildWSDCLayout(Map<String, dynamic> m) {
    return Row(
      children: [
        _teamTile("GOV", m['sideA'] ?? "TBD", const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("vs", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        _teamTile("OPP", m['sideB'] ?? "TBD", const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
      ],
    );
  }

  Widget _buildBPLayout(Map<String, dynamic> m) {
    return Column(
      children: [
        Row(children: [
          _teamTile("OG", m['sideOG'] ?? "TBD", const Color(0xFFECFDF5), const Color(0xFF047857)),
          const SizedBox(width: 12),
          _teamTile("OO", m['sideOO'] ?? "TBD", const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _teamTile("CG", m['sideCG'] ?? "TBD", const Color(0xFFF5F3FF), const Color(0xFF6D28D9)),
          const SizedBox(width: 12),
          _teamTile("CO", m['sideCO'] ?? "TBD", const Color(0xFFFDF2F8), const Color(0xFFBE185D)),
        ]),
      ],
    );
  }

  Widget _teamTile(String position, String teamName, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: textColor.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              teamName,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}