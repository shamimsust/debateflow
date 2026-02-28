import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// --- MODELS ---
class TeamStanding {
  final String teamName;
  final double wins;
  final double totalMarks;
  TeamStanding({required this.teamName, required this.wins, required this.totalMarks});
}

class SpeakerStanding {
  final String speakerName;
  final String teamName;
  final double totalScore;
  final int appearances;
  SpeakerStanding({required this.speakerName, required this.teamName, required this.totalScore, required this.appearances});
  double get averageScore => appearances == 0 ? 0 : totalScore / appearances;
}

class StandingsScreen extends StatefulWidget {
  final String tournamentId;
  const StandingsScreen({super.key, required this.tournamentId});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  Future<void> _exportAndShare() async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture();
      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final file = await File('${directory.path}/rankings.png').create();
        await file.writeAsBytes(imageBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Tournament Rankings');
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text("RANKINGS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF2264D7),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _exportAndShare,
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: const [
              Tab(text: "TEAMS"),
              Tab(text: "SPEAKERS"),
            ],
          ),
        ),
        // 🛠️ IMPORTANT: The classes below must be called correctly here
        body: Screenshot(
          controller: screenshotController,
          child: Container(
            color: const Color(0xFFF1F5F9),
            child: TabBarView(
              children: [
                _TeamRankingsTab(tournamentId: widget.tournamentId),
                _SpeakerRankingsTab(tournamentId: widget.tournamentId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 🛠️ FIX: Ensure these are CLASSES, not methods inside the state above ---

class _TeamRankingsTab extends StatelessWidget {
  final String tournamentId;
  const _TeamRankingsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final teamsRef = FirebaseDatabase.instance.ref('teams/$tournamentId');
    return StreamBuilder(
      stream: teamsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text("No teams registered yet."));
        }
        Map data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        List<TeamStanding> teams = [];
        data.forEach((key, value) {
          teams.add(TeamStanding(
            teamName: value['name'] ?? "Unnamed Team",
            wins: (value['wins'] ?? 0).toDouble(),
            totalMarks: (value['totalMarks'] ?? 0).toDouble(),
          ));
        });
        teams.sort((a, b) => b.wins != a.wins ? b.wins.compareTo(a.wins) : b.totalMarks.compareTo(a.totalMarks));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          itemBuilder: (context, index) => _RankingCard(
            index: index, title: teams[index].teamName, subtitle: "Total Marks: ${teams[index].totalMarks.toStringAsFixed(1)}",
            trailingValue: teams[index].wins.toStringAsFixed(0), trailingLabel: "WINS", isTeam: true,
          ),
        );
      },
    );
  }
}

class _SpeakerRankingsTab extends StatelessWidget {
  final String tournamentId;
  const _SpeakerRankingsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final ballotsRef = FirebaseDatabase.instance.ref('ballots/$tournamentId');
    return StreamBuilder(
      stream: ballotsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text("Rankings will appear after the first ballot."));
        }
        Map ballots = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        Map<String, SpeakerStanding> speakerMap = {};
        ballots.forEach((matchId, ballotData) {
          if (ballotData['results'] != null) {
            Map results = Map<dynamic, dynamic>.from(ballotData['results'] as Map);
            results.forEach((teamId, teamData) {
              String teamName = teamData['teamName'] ?? "Unknown";
              List speeches = teamData['speeches'] ?? [];
              for (var speech in speeches) {
                String name = speech['speakerName'] ?? "Unknown";
                double score = (speech['score'] ?? 0).toDouble();
                if (name != "Unknown" && score > 0) {
                  String key = "$name-$teamName";
                  if (speakerMap.containsKey(key)) {
                    var cur = speakerMap[key]!;
                    speakerMap[key] = SpeakerStanding(speakerName: name, teamName: teamName, totalScore: cur.totalScore + score, appearances: cur.appearances + 1);
                  } else {
                    speakerMap[key] = SpeakerStanding(speakerName: name, teamName: teamName, totalScore: score, appearances: 1);
                  }
                }
              }
            });
          }
        });
        List<SpeakerStanding> speakers = speakerMap.values.toList();
        speakers.sort((a, b) => b.averageScore.compareTo(a.averageScore));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: speakers.length,
          itemBuilder: (context, index) => _RankingCard(
            index: index, title: speakers[index].speakerName, subtitle: speakers[index].teamName,
            trailingValue: speakers[index].averageScore.toStringAsFixed(2), trailingLabel: "AVG", isTeam: false,
          ),
        );
      },
    );
  }
}

// --- KEEP _RankingCard AS IT WAS ---
class _RankingCard extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final String trailingValue;
  final String trailingLabel;
  final bool isTeam;

  const _RankingCard({required this.index, required this.title, required this.subtitle, required this.trailingValue, required this.trailingLabel, required this.isTeam});

  @override
  Widget build(BuildContext context) {
    bool isTop3 = index < 3;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _buildRankCircle(index),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isTop3 ? const Color(0xFF1E293B) : Colors.black87)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            trailing: _buildBadge(),
          ),
        ),
        if (isTeam && index == 3) _buildBreakLine(),
      ],
    );
  }

  Widget _buildRankCircle(int index) {
    Color color = Colors.grey.shade100;
    if (index == 0) color = const Color(0xFFFFD700);
    else if (index == 1) color = const Color(0xFFC0C0C0);
    else if (index == 2) color = const Color(0xFFCD7F32);
    return CircleAvatar(backgroundColor: color, radius: 16, child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)));
  }

  Widget _buildBadge() {
    return Container(
      width: 58, padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF2264D7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(trailingValue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
        Text(trailingLabel, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Color(0xFF2264D7))),
      ]),
    );
  }

  Widget _buildBreakLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: Colors.redAccent, thickness: 1.5)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(20)), child: const Text("SEMIS BREAK LINE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 9))),
        const Expanded(child: Divider(color: Colors.redAccent, thickness: 1.5)),
      ]),
    );
  }
}