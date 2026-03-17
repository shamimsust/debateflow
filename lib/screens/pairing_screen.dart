import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/match_service.dart';
import '../services/round_service.dart'; // ✅ Imported your new service
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
            if (rawValue != null) {
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
              roundService: _roundService, // ✅ Pass service down
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

  // ✅ Step 1: Generate Matches + Set Round Status to 'Draft'
  Future<void> _handleGenerate() async {
    setState(() => _isProcessing = true);
    try {
      final tourneySnap = await FirebaseDatabase.instance
          .ref('tournaments/${widget.tournamentId}')
          .get();
      final dynamic tourneyData = tourneySnap.value;
      String rule = tourneyData['rule'] ?? "WSDC";

      await widget.matchService.generateMatches(
        tournamentId: widget.tournamentId,
        roundNumber: widget.roundNumber,
        rule: rule,
      );

      // Initialize status in your RoundService
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
      // Listen to Round Status and Matches simultaneously
      stream: FirebaseDatabase.instance.ref().onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final dbData = snapshot.data!.snapshot.value as Map?;
        final roundSettings =
            dbData?['tournaments']?[widget.tournamentId]?['rounds']?[roundKey];
        final String status = roundSettings?['status'] ?? "Not Generated";

        final matchData =
            dbData?['matches']?[widget.tournamentId]?[roundKey] as Map?;
        if (matchData == null) return _buildEmptyState();

        List matches = [];
        matchData.forEach(
          (key, val) =>
              matches.add({"id": key, ...Map<String, dynamic>.from(val)}),
        );

        bool allFinished = matches.every((m) => m['status'] == 'Completed');

        return Column(
          children: [
            _buildRoundHeader(status, matches.length, allFinished),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: matches.length,
                itemBuilder: (context, index) =>
                    _buildMatchCard(matches[index]),
              ),
            ),
            if (widget.isLastRound && allFinished) _buildAdvanceButton(),
          ],
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
                  color: isReleased
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
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

    final judgeList = (m['judges'] is List)
        ? List<Map<String, dynamic>>.from(m['judges'])
        : [];
    final legacyJudge = (m['judge'] as String?)?.trim();
    final judgesDisplay = judgeList.isNotEmpty
        ? judgeList
              .map((e) => e['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ')
        : (legacyJudge?.isNotEmpty ?? false ? legacyJudge! : 'TBD');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isCompleted ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
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
        title: isBP
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sideText("OG", m['sideOG']),
                  _sideText("OO", m['sideOO']),
                  _sideText("CG", m['sideCG']),
                  _sideText("CO", m['sideCO']),
                ],
              )
            : Text(
                "${m['sideA']} vs ${m['sideB']}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
        subtitle: Text("${m['room'] ?? 'TBD'} | $judgesDisplay"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Assign adjudicators',
              onPressed: () => _openJudgeAssignmentDialog(m),
            ),
            Icon(
              isCompleted ? Icons.check_circle : Icons.pending,
              color: isCompleted ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openJudgeAssignmentDialog(Map matchData) async {
    final judgesSnap = await FirebaseDatabase.instance
        .ref('adjudicators/${widget.tournamentId}')
        .get();
    List<Map<String, String>> allJudges = [];
    for (var child in judgesSnap.children) {
      final dynamic j = child.value;
      if (j != null) {
        allJudges.add({
          'id': child.key ?? '',
          'name': j['name']?.toString() ?? 'TBD',
        });
      }
    }

    if (allJudges.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No judges found in tournament setup.')),
        );
      }
      return;
    }

    final existing = (matchData['judges'] is List)
        ? List<Map<String, dynamic>>.from(
            matchData['judges'],
          ).map((e) => e['id']?.toString()).whereType<String>().toSet()
        : <String>{};

    if ((matchData['judge'] as String?)?.isNotEmpty ?? false)
      existing.add(matchData['judgeId']?.toString() ?? '');

    final Set<String> selectedIds = Set.from(existing);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Adjudicators'),
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
                    setState(() {
                      if (checked == true)
                        selectedIds.add(j['id'] ?? '');
                      else
                        selectedIds.remove(j['id'] ?? '');
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
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
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideText(String side, String? name) => Text(
    "$side: ${name ?? 'TBD'}",
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );

  Widget _buildAdvanceButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
        onPressed: () =>
            widget.roundService.advanceToNextRound(widget.tournamentId),
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
                const Icon(
                  Icons.analytics_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handleGenerate,
                  child: const Text("GENERATE PAIRINGS"),
                ),
              ],
            ),
    );
  }
}
