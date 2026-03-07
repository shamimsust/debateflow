import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/color_extensions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter/services.dart';
import '../utils/web_utils.dart';

// --- MODELS ---
class TeamStanding {
  final String id;
  final String teamName;
  final double wins; 
  final double totalMarks;
  TeamStanding({required this.id, required this.teamName, required this.wins, required this.totalMarks});
}

class SpeakerStanding {
  final String speakerName;
  final String teamName;
  final double totalSubstantivePoints;
  final int totalRank; // For BP
  final int matchesPlayed;

  SpeakerStanding({
    required this.speakerName, 
    required this.teamName, 
    required this.totalSubstantivePoints, 
    required this.totalRank,
    required this.matchesPlayed
  });

  double get averageScore => matchesPlayed == 0 ? 0 : totalSubstantivePoints / matchesPlayed;
  double get averageRank => matchesPlayed == 0 ? 0 : totalRank / matchesPlayed;
}

class _MatchPerformance {
  final int round;
  final String name;
  final String team;
  final double score;
  final int rank;
  _MatchPerformance({required this.round, required this.name, required this.team, required this.score, required this.rank});
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
          title: const Text("TOURNAMENT RANKINGS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF2264D7),
          foregroundColor: Colors.white,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => PublicResultsScreen(tournamentId: widget.tournamentId))
              ),
              icon: const Icon(Icons.public, color: Colors.white, size: 18),
              label: const Text("LIVE FEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
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
                      fillColor: Colors.white.withOpacityValue(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.white,
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

// --- PUBLIC RESULTS FEED ---
class PublicResultsScreen extends StatefulWidget {
  final String tournamentId;
  const PublicResultsScreen({super.key, required this.tournamentId});

  @override
  State<PublicResultsScreen> createState() => _PublicResultsScreenState();
}

class _PublicResultsScreenState extends State<PublicResultsScreen> {
  void _sharePublicLink() {
    final String baseUrl = kIsWeb ? Uri.base.origin : "https://debateflow-2026.web.app";
    final String shareUrl = "$baseUrl/results/${widget.tournamentId}";
    debugPrint('sharePublicLink $shareUrl');
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Link copied:\n$shareUrl"),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
    ));

    if (kIsWeb) {
      openUrl(shareUrl, '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballotsRef = FirebaseDatabase.instance.ref('ballots/${widget.tournamentId}');
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("OFFICIAL BALLOTS"),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.link_rounded), onPressed: _sharePublicLink)],
      ),
      body: StreamBuilder(
        stream: ballotsRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("Waiting for ballots..."));
          Map data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
          List<MapEntry> ballotList = data.entries.toList();
          ballotList.sort((a, b) => (b.value['round'] ?? 0).compareTo(a.value['round'] ?? 0));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ballotList.length,
            itemBuilder: (context, index) => _buildBallotCard(ballotList[index].value),
          );
        },
      ),
    );
  }

  Widget _buildBallotCard(dynamic data) {
    Map results = Map<dynamic, dynamic>.from(data['results'] as Map);
    var sortedTeams = results.entries.toList();
    sortedTeams.sort((a, b) => (a.value['rank'] ?? 0).compareTo(b.value['rank'] ?? 0));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            tileColor: Colors.grey.shade50,
            title: Text("ROUND ${data['round']} • ROOM ${data['room']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ...sortedTeams.map((t) {
            var teamData = t.value;
            List speakers = (teamData['speakers'] as List? ?? []);
            return ExpansionTile(
              title: Text("${teamData['rank']}. ${teamData['teamName']}"),
              trailing: Text("${teamData['total']} pts"),
              children: speakers.map((s) => ListTile(
                dense: true,
                title: Text(s['name'] ?? "Speaker"),
                trailing: Text("Score: ${s['score']} | Rank: ${s['rank']}"),
              )).toList(),
            );
          }),
        ],
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
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref().onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final db = snapshot.data!.snapshot.value as Map?;
        final teamData = db?['teams']?[tournamentId] as Map?;
        final tourneyData = db?['tournaments']?[tournamentId] as Map?;
        final String rule = tourneyData?['rule'] ?? "WSDC";

        if (teamData == null) return const Center(child: Text("No teams found."));

        List<TeamStanding> teams = [];
        teamData.forEach((key, value) {
          if (value['name'].toString().toLowerCase().contains(query)) {
            teams.add(TeamStanding(
              id: key,
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
            index: index, 
            title: teams[index].teamName, 
            subtitle: "Total Marks: ${teams[index].totalMarks.toStringAsFixed(1)}",
            trailingValue: teams[index].wins.toStringAsFixed(0), 
            trailingLabel: rule == "BP" ? "POINTS" : "WINS", 
            isTeam: true,
            onTap: () => _showTeamDetails(context, tournamentId, teams[index]),
          ),
        );
      },
    );
  }

  void _showTeamDetails(BuildContext context, String tid, TeamStanding team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _DetailsSheet(title: team.teamName, tid: tid, filterId: team.teamName, isTeam: true),
    );
  }
}

// --- SPEAKER RANKINGS TAB ---
class _SpeakerRankingsTab extends StatelessWidget {
  final String tournamentId;
  final String query;
  const _SpeakerRankingsTab({required this.tournamentId, required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref().onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final db = snapshot.data!.snapshot.value as Map?;
        final tourneyData = db?['tournaments']?[tournamentId] as Map?;
        final String rule = tourneyData?['rule'] ?? "WSDC";
        final Map ballots = Map<dynamic, dynamic>.from(db?['ballots']?[tournamentId] ?? {});

        Map<String, List<_MatchPerformance>> speakerPerformances = {};

        ballots.forEach((mId, bData) {
          if (bData['results'] != null) {
            Map res = Map<dynamic, dynamic>.from(bData['results'] as Map);
            res.forEach((tId, tData) {
              String teamName = tData['teamName'] ?? "Unknown";
              List speakers = tData['speakers'] ?? tData['speeches'] ?? [];
              for (var s in speakers) {
                String name = s['name'] ?? s['speakerName'] ?? "Unknown";
                double score = (s['score'] ?? 0).toDouble();
                int rank = (s['rank'] ?? 0).toInt();
                if (name != "Unknown" && score > 0) {
                  String key = "$name-$teamName";
                  speakerPerformances.putIfAbsent(key, () => []).add(
                    _MatchPerformance(round: bData['round'] ?? 0, name: name, team: teamName, score: score, rank: rank)
                  );
                }
              }
            });
          }
        });

        List<SpeakerStanding> speakers = speakerPerformances.entries.map((e) {
          return SpeakerStanding(
            speakerName: e.value.first.name,
            teamName: e.value.first.team,
            totalSubstantivePoints: e.value.fold(0.0, (sum, m) => sum + m.score),
            totalRank: e.value.fold(0, (sum, m) => sum + m.rank),
            matchesPlayed: e.value.length,
          );
        }).where((s) => s.speakerName.toLowerCase().contains(query)).toList();

        speakers.sort((a, b) => rule == "BP" ? a.averageRank.compareTo(b.averageRank) : b.averageScore.compareTo(a.averageScore));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: speakers.length,
          itemBuilder: (context, index) => _RankingCard(
            index: index, 
            title: speakers[index].speakerName, 
            subtitle: speakers[index].teamName,
            trailingValue: speakers[index].averageScore.toStringAsFixed(2), 
            trailingLabel: rule == "BP" ? "AVG RNK" : "AVG", 
            isTeam: false,
            onTap: () => _showSpeakerDetails(context, tournamentId, speakers[index]),
          ),
        );
      },
    );
  }

  void _showSpeakerDetails(BuildContext context, String tid, SpeakerStanding speaker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _DetailsSheet(title: speaker.speakerName, tid: tid, filterId: speaker.speakerName, isTeam: false),
    );
  }
}

// --- DRILL DOWN DETAILS SHEET ---
class _DetailsSheet extends StatelessWidget {
  final String title;
  final String tid;
  final String filterId;
  final bool isTeam;
  const _DetailsSheet({required this.title, required this.tid, required this.filterId, required this.isTeam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
          const Divider(),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseDatabase.instance.ref('ballots/$tid').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("No match history."));
                Map ballots = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                List<_MatchPerformance> history = [];

                ballots.forEach((k, b) {
                  Map res = Map<dynamic, dynamic>.from(b['results'] ?? {});
                  res.forEach((tId, tData) {
                    if (isTeam && tData['teamName'] == filterId) {
                      history.add(_MatchPerformance(round: b['round'], name: tData['teamName'], team: "", score: (tData['total'] ?? 0).toDouble(), rank: tData['rank'] ?? 0));
                    } else if (!isTeam) {
                      List speakers = tData['speakers'] ?? tData['speeches'] ?? [];
                      for (var s in speakers) {
                        if ((s['name'] ?? s['speakerName']) == filterId) {
                          history.add(_MatchPerformance(round: b['round'], name: filterId, team: tData['teamName'], score: (s['score'] ?? 0).toDouble(), rank: s['rank'] ?? 0));
                        }
                      }
                    }
                  });
                });
                history.sort((a, b) => a.round.compareTo(b.round));

                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: CircleAvatar(child: Text("R${history[i].round}")),
                    title: Text(isTeam ? "Team Result" : "Speaker Score"),
                    subtitle: Text("Rank: ${history[i].rank}"),
                    trailing: Text("${history[i].score}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
  final VoidCallback onTap;
  const _RankingCard({required this.index, required this.title, required this.subtitle, required this.trailingValue, required this.trailingLabel, required this.isTeam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool isTop = index < 3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacityValue(0.03), blurRadius: 10)]),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isTop ? const Color(0xFF2264D7) : Colors.grey.shade100,
            child: Text("${index + 1}", style: TextStyle(color: isTop ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF2264D7).withOpacityValue(0.1), borderRadius: BorderRadius.circular(8)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(trailingValue, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
              Text(trailingLabel, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
            ]),
          ),
        ),
      ),
    );
  }
}