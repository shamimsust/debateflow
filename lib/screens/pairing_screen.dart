import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import '../services/match_service.dart';
import '../services/round_service.dart';
import 'ballot_screen.dart';

class PairingScreen extends StatefulWidget {
  final String tournamentId;
  const PairingScreen({super.key, required this.tournamentId});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final MatchService _matchService = MatchService();
  final RoundService _roundService = RoundService();
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
        if (rawValue != null && rawValue is Map) {
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

  // ✅ Added Share Functionality
  void _sharePairingLink() {
    final String baseUrl = kIsWeb ? Uri.base.origin : "https://debateflow-2026.web.app";
    final String shareUrl = "$baseUrl/pairings/${widget.tournamentId}";
    
    Clipboard.setData(ClipboardData(text: shareUrl));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Public Pairing Link Copied:\n$shareUrl"),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(totalRounds),
      length: totalRounds,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            "Tournament Pairings",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF2264D7),
          foregroundColor: Colors.white,
          // ✅ Added Share Button to Actions
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: "Share Public Pairings",
              onPressed: _sharePairingLink,
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: totalRounds > 4,
            indicatorColor: Colors.white,
            tabs: List.generate(
              totalRounds,
              (i) => Tab(text: "Round ${i + 1}"),
            ),
          ),
        ),
        body: TabBarView(
          children: List.generate(totalRounds, (i) {
            return RoundView(
              tournamentId: widget.tournamentId,
              roundNumber: i + 1,
              isLastRound: (i + 1) == totalRounds,
              matchService: _matchService,
              roundService: _roundService,
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
  final RoundService roundService;

  const RoundView({
    super.key,
    required this.tournamentId,
    required this.roundNumber,
    required this.isLastRound,
    required this.matchService,
    required this.roundService,
  });

  @override
  State<RoundView> createState() => _RoundViewState();
}

class _RoundViewState extends State<RoundView>
    with AutomaticKeepAliveClientMixin {
  bool _isProcessing = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _handleGenerate() async {
    setState(() => _isProcessing = true);
    try {
      final tourneySnap = await FirebaseDatabase.instance
          .ref('tournaments/${widget.tournamentId}')
          .get();
      final dynamic tourneyData = tourneySnap.value;
      String rule = (tourneyData is Map) ? (tourneyData['rule'] ?? "WSDC") : "WSDC";

      await widget.matchService.generateMatches(
        tournamentId: widget.tournamentId,
        roundNumber: widget.roundNumber,
        rule: rule,
      );

      await widget.roundService.updateRoundStatus(
        widget.tournamentId,
        widget.roundNumber.toString(),
        "Draft",
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String roundKey = "round_${widget.roundNumber}";

    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('tournaments/${widget.tournamentId}').onValue,
      builder: (context, tournamentSnapshot) {
        if (!tournamentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dynamic tourneyData = tournamentSnapshot.data!.snapshot.value;
        final Map? tourneyMap = tourneyData is Map ? tourneyData : null;
        final roundSettings = tourneyMap?['rounds']?[roundKey];
        final String status = roundSettings?['status'] ?? "Not Generated";

        return StreamBuilder(
          stream: FirebaseDatabase.instance.ref('matches/${widget.tournamentId}/$roundKey').onValue,
          builder: (context, matchSnapshot) {
            if (matchSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final dynamic matchData = matchSnapshot.data?.snapshot.value;
            if (matchData == null || matchData is! Map) return _buildEmptyState();

            final Map<dynamic, dynamic> matchMap = matchData;
            List matches = [];
            matchMap.forEach((key, val) {
              if (val is Map) {
                matches.add({"id": key, ...Map<String, dynamic>.from(val)});
              }
            });

            bool allFinished = matches.isNotEmpty && matches.every((m) => m['status'] == 'Completed');

            return Column(
              children: [
                _buildRoundHeader(status, matches.length, allFinished),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: matches.length,
                    itemBuilder: (context, index) => _buildMatchCard(matches[index]),
                  ),
                ),
                if (widget.isLastRound && allFinished) _buildAdvanceButton(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRoundHeader(String status, int matchCount, bool allFinished) {
    bool isReleased = status == "Released";
    return Container(
      padding: const EdgeInsets.all(16),
      color: isReleased ? Colors.green.shade50 : Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Status: ${status.toUpperCase()}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isReleased ? Colors.green.shade700 : Colors.blue.shade700,
                ),
              ),
              Text(
                "$matchCount Matches Paired",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReleased ? Colors.orange : Colors.green,
            ),
            onPressed: () => widget.roundService.updateRoundStatus(
              widget.tournamentId,
              widget.roundNumber.toString(),
              isReleased ? "Draft" : "Released",
            ),
            icon: Icon(isReleased ? Icons.lock : Icons.send, size: 16),
            label: Text(isReleased ? "UNRELEASE" : "RELEASE"),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map m) {
    bool isBP = m['rule'] == "BP";
    bool isCompleted = m['status'] == 'Completed';

    final List judgeList = m['judges'] is List ? m['judges'] : [];
    final legacyJudge = (m['judge'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(
          color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => BallotScreen(
              tournamentId: widget.tournamentId,
              matchId: m['id'],
              matchData: Map<String, dynamic>.from(m),
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(
                        m['room']?.toString().toUpperCase() ?? "TBD",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                  if (isCompleted)
                    const Icon(Icons.check_circle, color: Colors.green, size: 16)
                  else
                    const Text("PENDING", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: isBP ? _buildBPLayout(m) : _buildWSDCLayout(m),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, size: 14, color: Color(0xFF2264D7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      judgeList.isNotEmpty
                          ? judgeList.map((e) => (e is Map ? e['name'] : e.toString())).join(', ')
                          : (legacyJudge?.isNotEmpty ?? false ? legacyJudge! : 'No Adjudicator Assigned'),
                      style: TextStyle(
                        fontSize: 12,
                        color: (judgeList.isEmpty && (legacyJudge?.isEmpty ?? true)) ? Colors.red : Colors.black87,
                        fontStyle: (judgeList.isEmpty && (legacyJudge?.isEmpty ?? true)) ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.blueGrey),
                    onPressed: () => _openJudgeAssignmentDialog(m),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWSDCLayout(Map m) {
    return Row(
      children: [
        _teamBlock("GOV / PROP", m['sideA'] ?? "TBD", const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("vs", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
        ),
        _teamBlock("OPP / NEG", m['sideB'] ?? "TBD", const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
      ],
    );
  }

  Widget _buildBPLayout(Map m) {
    return Column(
      children: [
        Row(
          children: [
            _teamBlock("OG", m['sideOG'] ?? "TBD", const Color(0xFFECFDF5), const Color(0xFF047857)),
            const SizedBox(width: 8),
            _teamBlock("OO", m['sideOO'] ?? "TBD", const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _teamBlock("CG", m['sideCG'] ?? "TBD", const Color(0xFFF5F3FF), const Color(0xFF6D28D9)),
            const SizedBox(width: 8),
            _teamBlock("CO", m['sideCO'] ?? "TBD", const Color(0xFFFDF2F8), const Color(0xFFBE185D)),
          ],
        ),
      ],
    );
  }

  Widget _teamBlock(String side, String name, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(side, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textColor.withOpacity(0.6))),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openJudgeAssignmentDialog(Map matchData) async {
    if (!context.mounted) return;
    final judgesSnap = await FirebaseDatabase.instance
        .ref('adjudicators/${widget.tournamentId}')
        .get();
    
    List<Map<String, String>> allJudges = [];
    if (judgesSnap.exists) {
      for (var child in judgesSnap.children) {
        final dynamic j = child.value;
        if (j != null && j is Map) {
          allJudges.add({
            'id': child.key ?? '',
            'name': j['name']?.toString() ?? 'TBD',
          });
        }
      }
    }

    if (allJudges.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No judges found in tournament setup.')),
      );
      return;
    }

    final existing = (matchData['judges'] is List)
        ? (matchData['judges'] as List)
            .map((e) => e is Map ? e['id']?.toString() : e.toString())
            .whereType<String>()
            .toSet()
        : <String>{};

    final Set<String> selectedIds = Set.from(existing);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Assign Panel'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allJudges.map((j) {
                bool selected = selectedIds.contains(j['id']);
                return CheckboxListTile(
                  title: Text(j['name'] ?? 'TBD'),
                  value: selected,
                  onChanged: (checked) {
                    setLocalState(() {
                      if (checked == true) {
                        selectedIds.add(j['id'] ?? '');
                      } else {
                        selectedIds.remove(j['id'] ?? '');
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            TextButton(
              onPressed: () async {
                final assigned = allJudges
                    .where((j) => selectedIds.contains(j['id']))
                    .toList();
                await widget.matchService.assignAdjudicators(
                  tournamentId: widget.tournamentId,
                  roundNumber: widget.roundNumber,
                  matchId: matchData['id'],
                  adjudicators: assigned,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvanceButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => widget.roundService.advanceToNextRound(widget.tournamentId),
        child: const Text(
          "ADVANCE TO NEXT ROUND",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: _isProcessing
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text("No pairings found for this round", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handleGenerate,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7), foregroundColor: Colors.white),
                  child: const Text("GENERATE PAIRINGS"),
                ),
              ],
            ),
    );
  }
}