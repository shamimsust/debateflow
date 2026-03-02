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
  final double totalSubstantivePoints;
  final int matchesPlayed;

  SpeakerStanding({
    required this.speakerName, 
    required this.teamName, 
    required this.totalSubstantivePoints, 
    required this.matchesPlayed
  });

  double get averageScore => matchesPlayed == 0 ? 0 : totalSubstantivePoints / matchesPlayed;
}

// Internal helper for data processing
class _MatchPerformance {
  final String name;
  final String team;
  final double score;
  _MatchPerformance({required this.name, required this.team, required this.score});
}

// --- MAIN STANDINGS SCREEN ---
class StandingsScreen extends StatefulWidget {
  final String tournamentId;
  const StandingsScreen({super.key, required this.tournamentId});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  String _searchQuery = "";

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
            TextButton.icon(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => PublicResultsScreen(tournamentId: widget.tournamentId))
              ),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: const Text("PUBLISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search Team or Speaker...",
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 4,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: [Tab(text: "TEAMS"), Tab(text: "SPEAKERS")],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _TeamRankingsTab(tournamentId: widget.tournamentId, query: _searchQuery),
            _SpeakerRankingsTab(tournamentId: widget.tournamentId, query: _searchQuery),
          ],
        ),
      ),
    );
  }
}

// --- THE RESULTS FEED SCREEN ---
class PublicResultsScreen extends StatefulWidget {
  final String tournamentId;
  const PublicResultsScreen({super.key, required this.tournamentId});

  @override
  State<PublicResultsScreen> createState() => _PublicResultsScreenState();
}

class _PublicResultsScreenState extends State<PublicResultsScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  void _sharePublicLink() {
    final String baseUrl = kIsWeb ? Uri.base.origin : "https://debateflow-2026.web.app";
    final String shareUrl = "$baseUrl/#/results?tid=${widget.tournamentId}";
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Results link copied!"), backgroundColor: Colors.green),
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
          final file = await File('${directory.path}/official_results.png').create();
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
        title: const Text("OFFICIAL RESULTS"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.link_rounded), onPressed: _sharePublicLink),
          IconButton(icon: const Icon(Icons.image_rounded), onPressed: _exportAndShareImage),
        ],
      ),
      body: Screenshot(
        controller: screenshotController,
        child: Container(
          color: const Color(0xFFF1F5F9),
          child: StreamBuilder(
            stream: ballotsRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text("No results published yet."));
              }
              Map data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
              List<MapEntry> ballotList = data.entries.toList();
              ballotList.sort((a, b) => (b.value['round'] ?? 0).compareTo(a.value['round'] ?? 0));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: ballotList.length,
                itemBuilder: (context, index) => _buildResultCard(ballotList[index].value),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(dynamic data) {
    Map results = Map<dynamic, dynamic>.from(data['results'] as Map);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ROUND ${data['round']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
            const Divider(),
            ...results.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.value['teamName'], style: TextStyle(fontWeight: e.value['rank'] == 1 ? FontWeight.bold : FontWeight.normal)),
                  if (e.value['rank'] == 1) const Icon(Icons.stars_rounded, color: Colors.orange, size: 18),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// --- TEAM RANKINGS TAB ---
class _TeamRankingsTab extends StatelessWidget {
  final String tournamentId;
  final String query;
  const _TeamRankingsTab({required this.tournamentId, required this.query});

  @override
  Widget build(BuildContext context) {
    final teamsRef = FirebaseDatabase.instance.ref('teams/$tournamentId');
    return StreamBuilder(
      stream: teamsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("No teams registered."));
        Map data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        List<TeamStanding> teams = [];
        data.forEach((key, value) {
          if (value['name'].toString().toLowerCase().contains(query)) {
            teams.add(TeamStanding(
              teamName: value['name'] ?? "Team",
              wins: (value['wins'] ?? 0).toDouble(),
              totalMarks: (value['totalMarks'] ?? 0).toDouble(),
            ));
          }
        });
        teams.sort((a, b) => b.wins != a.wins ? b.wins.compareTo(a.wins) : b.totalMarks.compareTo(a.totalMarks));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          itemBuilder: (context, index) => _RankingCard(
            index: index, title: teams[index].teamName, subtitle: "Marks: ${teams[index].totalMarks.toStringAsFixed(1)}",
            trailingValue: teams[index].wins.toStringAsFixed(0), trailingLabel: "WINS", isTeam: true,
          ),
        );
      },
    );
  }
}

// --- SPEAKER RANKINGS TAB (FIXED FOR IRONMAN) ---
class _SpeakerRankingsTab extends StatelessWidget {
  final String tournamentId;
  final String query;
  const _SpeakerRankingsTab({required this.tournamentId, required this.query});

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
        
        // Key: "SpeakerName-TeamName" -> List of averaged scores per match
        Map<String, List<_MatchPerformance>> speakerPerformances = {};

        ballots.forEach((mId, bData) {
          if (bData['results'] != null) {
            Map res = Map<dynamic, dynamic>.from(bData['results'] as Map);
            res.forEach((tId, tData) {
              String teamName = tData['teamName'] ?? "Unknown";
              List speeches = tData['speeches'] ?? [];
              
              // Handle Ironman: Group scores by speaker name for THIS MATCH only
              Map<String, List<double>> matchScoresBySpeaker = {};

              for (int i = 0; i < speeches.length; i++) {
                var s = speeches[i];
                String name = s['speakerName'] ?? "Unknown";
                double score = (s['score'] ?? 0).toDouble();
                bool isSubstantive = i < 3; // Indices 0, 1, 2 are substantive in WSDC

                if (name != "Unknown" && score > 0 && isSubstantive) {
                  matchScoresBySpeaker.putIfAbsent(name, () => []).add(score);
                }
              }

              // Save the effective (averaged) match score for each speaker
              matchScoresBySpeaker.forEach((name, scores) {
                // If Ironman (2 scores), this calculates the average for the match
                double effectiveMatchScore = scores.reduce((a, b) => a + b) / scores.length;
                
                String key = "$name-$teamName";
                speakerPerformances.putIfAbsent(key, () => []).add(
                  _MatchPerformance(name: name, team: teamName, score: effectiveMatchScore)
                );
              });
            });
          }
        });

        // Convert grouped performances into ranked SpeakerStanding list
        List<SpeakerStanding> speakers = speakerPerformances.entries.map((e) {
          double totalAveragedPoints = e.value.fold(0.0, (sum, match) => sum + match.score);
          return SpeakerStanding(
            speakerName: e.value.first.name,
            teamName: e.value.first.team,
            totalSubstantivePoints: totalAveragedPoints,
            matchesPlayed: e.value.length,
          );
        }).where((s) => s.speakerName.toLowerCase().contains(query)).toList();

        // Sort by average score (Standard Debating Practice)
        speakers.sort((a, b) => b.averageScore.compareTo(a.averageScore));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: speakers.length,
          itemBuilder: (context, index) => _RankingCard(
            index: index, 
            title: speakers[index].speakerName, 
            subtitle: speakers[index].teamName,
            trailingValue: speakers[index].averageScore.toStringAsFixed(2), 
            trailingLabel: "AVG", 
            isTeam: false,
          ),
        );
      },
    );
  }
}

// --- REUSABLE RANKING CARD ---
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
            leading: CircleAvatar(
              backgroundColor: isTop3 ? const Color(0xFF2264D7) : Colors.grey.shade100,
              child: Text("${index + 1}", style: TextStyle(color: isTop3 ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold)),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF2264D7).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(trailingValue, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
                Text(trailingLabel, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
              ]),
            ),
          ),
        ),
        // Visual break for Break rounds (Top 4 teams usually break to Semis)
        if (isTeam && index == 3) const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Divider(color: Colors.redAccent, thickness: 1.5, indent: 20, endIndent: 20),
        ),
      ],
    );
  }
}