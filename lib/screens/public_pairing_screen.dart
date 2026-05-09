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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Tournament Draw", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E293B), // Professional Dark Theme for Public
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: totalRounds > 4,
            indicatorColor: Colors.white,
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

        // ONLY show if status is "Released"
        if (status != "Released") {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_clock_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text("Round draw hasn't been released yet.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return StreamBuilder(
          stream: FirebaseDatabase.instance.ref('matches/$tournamentId/$roundKey').onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> matchSnap) {
            if (!matchSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            final matchData = matchSnap.data!.snapshot.value as Map?;
            if (matchData == null) return const Center(child: Text("No matches found."));

            List matches = [];
            matchData.forEach((key, val) {
              if (val is Map) matches.add(val);
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

  Widget _buildPublicMatchCard(Map m) {
    bool isBP = m['rule'] == "BP";
    final List judgeList = m['judges'] is List ? m['judges'] : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text(
                  m['room']?.toString().toUpperCase() ?? "TBD",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: isBP ? _buildBPLayout(m) : _buildWSDCLayout(m),
          ),
          if (judgeList.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, size: 14, color: Color(0xFF2264D7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      judgeList.map((e) => e is Map ? e['name'] : e.toString()).join(", "),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

  Widget _buildWSDCLayout(Map m) {
    return Row(
      children: [
        _teamTile(m['sideA'] ?? "TBD", const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("vs", style: TextStyle(color: Colors.grey))),
        _teamTile(m['sideB'] ?? "TBD", const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
      ],
    );
  }

  Widget _buildBPLayout(Map m) {
    return Column(
      children: [
        Row(children: [
          _teamTile("OG: ${m['sideOG']}", const Color(0xFFECFDF5), const Color(0xFF047857)),
          const SizedBox(width: 8),
          _teamTile("OO: ${m['sideOO']}", const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _teamTile("CG: ${m['sideCG']}", const Color(0xFFF5F3FF), const Color(0xFF6D28D9)),
          const SizedBox(width: 8),
          _teamTile("CO: ${m['sideCO']}", const Color(0xFFFDF2F8), const Color(0xFFBE185D)),
        ]),
      ],
    );
  }

  Widget _teamTile(String name, Color bg, Color text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(name, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}