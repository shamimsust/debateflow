import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

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

// --- STANDINGS SCREEN ---
class StandingsScreen extends StatefulWidget {
  final String tournamentId;
  const StandingsScreen({super.key, required this.tournamentId});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
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
            // 🛠️ Navigation to the Publish Screen
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublishResultsScreen(tournamentId: widget.tournamentId),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: const Text("PUBLISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: "TEAMS"),
              Tab(text: "SPEAKERS"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TeamRankingsTab(tournamentId: widget.tournamentId),
            _SpeakerRankingsTab(tournamentId: widget.tournamentId),
          ],
        ),
      ),
    );
  }
}

// --- PUBLISH RESULTS SCREEN (The Sharer) ---
class PublishResultsScreen extends StatefulWidget {
  final String tournamentId;
  const PublishResultsScreen({super.key, required this.tournamentId});

  @override
  State<PublishResultsScreen> createState() => _PublishResultsScreenState();
}

class _PublishResultsScreenState extends State<PublishResultsScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  void _sharePublicLink() {
    final String baseUrl = kIsWeb ? Uri.base.origin : "https://debateflow-2026.web.app";
    // This generates a link specifically for the public to view
    final String shareUrl = "$baseUrl/#/public-view?tid=${widget.tournamentId}";
    
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Public link copied to clipboard!"), backgroundColor: Colors.green),
    );
  }

  Future<void> _exportAndShareImage() async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture();
      if (imageBytes != null) {
        if (kIsWeb) {
          _sharePublicLink();
        } else {
          final directory = await getTemporaryDirectory();
          final file = await File('${directory.path}/published_results.png').create();
          await file.writeAsBytes(imageBytes);
          await Share.shareXFiles([XFile(file.path)], text: 'Tournament Official Results');
        }
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballotsRef = FirebaseDatabase.instance.ref('ballots/${widget.tournamentId}');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("PUBLISH RESULTS", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Copy Public Link",
            icon: const Icon(Icons.link_rounded), 
            onPressed: _sharePublicLink
          ),
          IconButton(
            tooltip: "Share as Image",
            icon: const Icon(Icons.image_rounded), 
            onPressed: _exportAndShareImage
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Screenshot(
        controller: screenshotController,
        child: Container(
          color: const Color(0xFFF1F5F9),
          child: StreamBuilder(
            stream: ballotsRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text("No results to publish yet."));
              }

              Map data = snapshot.data!.snapshot.value as Map;
              List<MapEntry> ballots = data.entries.toList();
              ballots.sort((a, b) => (b.value['round'] ?? 0).compareTo(a.value['round'] ?? 0));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: ballots.length,
                itemBuilder: (context, index) => _buildPublishCard(ballots[index].value),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPublishCard(dynamic data) {
    Map results = data['results'] as Map;
    int round = data['round'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ROUND $round RESULT", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2264D7), fontSize: 10)),
            const Divider(height: 20),
            ...results.entries.map((e) {
              bool isWinner = e.value['rank'] == 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.value['teamName'], 
                      style: TextStyle(fontWeight: isWinner ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                    if (isWinner) 
                      const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// --- TEAM RANKINGS TAB ---
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

// --- SPEAKER RANKINGS TAB ---
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

// --- RANKING CARD COMPONENT ---
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
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
      decoration: BoxDecoration(color: const Color(0xFF2264D7).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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