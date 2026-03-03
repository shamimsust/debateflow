import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/debate_validator.dart'; // ✅ Uses your abstract/factory service

class BallotScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final Map matchData;

  const BallotScreen({
    super.key, 
    required this.tournamentId, 
    required this.matchId, 
    required this.matchData
  });

  @override
  State<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends State<BallotScreen> {
  // Data Maps
  final Map<String, List<TextEditingController>> _scoreMap = {};
  final Map<String, int> _ranks = {}; 
  final Map<String, String> _teamIdMap = {}; 
  final Map<String, List<String>> _speakerNames = {};
  final Map<String, List<String?>> _selectedSpeakers = {};
  final Map<String, bool> _isIronmanMap = {}; 
  
  String debateRule = "WSDC";
  bool _isSubmitting = false;
  bool _hasTies = false; 
  bool _isLoading = true; 

  // Validation settings for the Service
  Map<String, dynamic> validatorSettings = {
    'minSub': 60.0, 'maxSub': 80.0, 'minReply': 30.0, 'maxReply': 40.0
  };

  @override
  void initState() {
    super.initState();
    _initBallot();
  }

  @override
  void dispose() {
    for (var controllers in _scoreMap.values) {
      for (var ctrl in controllers) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _initBallot() async {
    debateRule = widget.matchData['rule'] ?? "WSDC";

    try {
      // 1. Fetch Tournament Settings
      final settingsSnap = await FirebaseDatabase.instance
          .ref('tournaments/${widget.tournamentId}/settings').get();
      
      if (settingsSnap.exists) {
        final s = Map<dynamic, dynamic>.from(settingsSnap.value as Map);
        validatorSettings['minSub'] = (s['minSubstantive'] ?? 60.0).toDouble();
        validatorSettings['maxSub'] = (s['maxSubstantive'] ?? 80.0).toDouble();
        validatorSettings['minReply'] = (s['minReply'] ?? 30.0).toDouble();
        validatorSettings['maxReply'] = (s['maxReply'] ?? 40.0).toDouble();
      }

      // 2. Identify Sides
      List<String> sideKeys = (debateRule == "BP") 
          ? ["sideOG", "sideOO", "sideCG", "sideCO"] 
          : ["sideA", "sideB"];

      // 3. Setup Controllers & Fetch Speakers
      for (var key in sideKeys) {
        String? teamName = widget.matchData[key];
        String? teamId = widget.matchData['${key}Id'];
        
        if (teamName != null && teamId != null) {
          _teamIdMap[teamName] = teamId;
          _ranks[teamName] = 0;
          _isIronmanMap[teamName] = false;
          
          int speechCount = (debateRule == "BP") ? 2 : 4;
          _scoreMap[teamName] = List.generate(speechCount, (_) => TextEditingController());
          _selectedSpeakers[teamName] = List.generate(speechCount, (_) => null);

          final teamSnap = await FirebaseDatabase.instance
              .ref('teams/${widget.tournamentId}/$teamId').get();
          
          if (teamSnap.exists) {
            Map data = teamSnap.value as Map;
            _speakerNames[teamName] = [data['speaker1'], data['speaker2'], data['speaker3']]
                .whereType<String>().toList();
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- BUSINESS LOGIC ---

  void _detectIronman(String teamName) {
    if (debateRule == "BP") return;
    List<String?> selected = _selectedSpeakers[teamName]!;
    List<String?> substantives = selected.take(3).where((s) => s != null).toList();
    bool duplicate = substantives.length != substantives.toSet().length;
    if (duplicate != _isIronmanMap[teamName]) setState(() => _isIronmanMap[teamName] = duplicate);
  }

  void _calculateAutoRanks() {
    List<MapEntry<String, double>> teamTotals = _scoreMap.keys.map((name) {
      return MapEntry(name, _getTeamTotal(name));
    }).toList();

    // Sort Descending (Highest score = Rank 1)
    teamTotals.sort((a, b) => b.value.compareTo(a.value));

    bool tieFound = false;
    Map<String, int> newRanks = {};

    for (int i = 0; i < teamTotals.length; i++) {
      double score = teamTotals[i].value;
      // Mark as 0 if points equal another team (invalid state)
      bool tied = (score > 0) && (
        (i > 0 && score == teamTotals[i-1].value) || 
        (i < teamTotals.length - 1 && score == teamTotals[i+1].value)
      );
      
      if (tied) tieFound = true;
      newRanks[teamTotals[i].key] = tied ? 0 : i + 1;
    }

    setState(() {
      _ranks.addAll(newRanks);
      _hasTies = tieFound;
    });
  }

  double _getTeamTotal(String teamName) => _scoreMap[teamName]!
      .fold(0.0, (sum, ctrl) => sum + (double.tryParse(ctrl.text) ?? 0.0));

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("$debateRule Official Ballot"), 
        backgroundColor: const Color(0xFF2264D7), 
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_hasTies) _buildWarning("TIES DETECTED: Scores must result in distinct ranks."),
                ..._scoreMap.keys.map((teamName) => _buildTeamCard(teamName)),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
    );
  }

  Widget _buildWarning(String msg) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
    child: Text(msg, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
  );

  Widget _buildTeamCard(String teamName) {
    bool isTied = _ranks[teamName] == 0;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isTied ? Colors.red : Colors.grey.shade200, width: isTied ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_isIronmanMap[teamName] ?? false) 
                      const Text("IRONMAN ACTIVE", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10)),
                  ]),
                ),
                // BP shows Rank Tag, WSDC shows Total Points
                if (debateRule == "BP")
                  _buildRankBadge(isTied, _ranks[teamName] ?? 0)
                else
                  Text("${_getTeamTotal(teamName).toStringAsFixed(1)} PTS", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2264D7), fontSize: 16)),
              ],
            ),
            const Divider(height: 30),
            ..._scoreMap[teamName]!.asMap().entries.map((e) => _buildSpeechRow(teamName, e.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(bool isTied, int rank) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: isTied ? Colors.red : const Color(0xFF2264D7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isTied ? "TIE" : "RANK $rank",
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildSpeechRow(String teamName, int idx) {
    String label = (debateRule == "BP") ? (idx == 0 ? "Member" : "Whip") : (idx == 3 ? "Reply" : "Speaker ${idx + 1}");
    List<String> items = _speakerNames[teamName] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: DropdownButtonFormField<String>(
            initialValue: (items.contains(_selectedSpeakers[teamName]![idx])) ? _selectedSpeakers[teamName]![idx] : null, 
            hint: Text(label, style: const TextStyle(fontSize: 13)),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedSpeakers[teamName]![idx] = v;
                _detectIronman(teamName);
              });
            },
          )),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: TextField(
            controller: _scoreMap[teamName]![idx],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 14), hintText: "0"),
            onChanged: (v) => _calculateAutoRanks(), // ✅ BP Ranks update instantly on number change
          )),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() => ElevatedButton(
    onPressed: (_hasTies || _isSubmitting) ? null : _submit,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2264D7), foregroundColor: Colors.white, 
      minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(_hasTies ? "RESOLVE TIES TO SUBMIT" : "SUBMIT BALLOT", style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  // --- VALIDATION & SUBMISSION ---

  Future<void> _submit() async {
    // 1. Speaker Selection Validation
    for (var team in _selectedSpeakers.keys) {
      if (_selectedSpeakers[team]!.any((s) => s == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All speaker slots must be assigned!")));
        return;
      }
    }

    // 2. Map data for Validator
    Map<String, List<double>> rawScores = {};
    _scoreMap.forEach((team, controllers) {
      rawScores[team] = controllers.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    });

    // 3. Call Service Validator (WSDC vs BP)
    DebateValidator validator = (debateRule == "BP") ? BPValidator() : WSDCValidator();
    String? error = validator.validate(rawScores, _ranks, validatorSettings);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }

    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Results"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _ranks.entries.map((e) => ListTile(
            title: Text(e.key),
            trailing: Text("Rank ${e.value}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BACK")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _processSubmission(); }, child: const Text("SUBMIT")),
        ],
      ),
    );
  }

  Future<void> _processSubmission() async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = FirebaseDatabase.instance.ref();
      Map<String, dynamic> ballotResults = {};
      int round = int.tryParse(widget.matchData['round']?.toString() ?? "1") ?? 1;

      for (var teamName in _scoreMap.keys) {
        String tId = _teamIdMap[teamName]!;
        ballotResults[tId] = {
          'teamName': teamName,
          'total': _getTeamTotal(teamName),
          'rank': _ranks[teamName],
          'isIronman': _isIronmanMap[teamName] ?? false,
          'speeches': _scoreMap[teamName]!.asMap().entries.map((e) => {
            'speakerName': _selectedSpeakers[teamName]![e.key],
            'score': double.tryParse(e.value.text) ?? 0.0,
            'isSubstantive': (debateRule == "BP" || e.key < 3),
          }).toList(),
        };
      }

      // Save Ballot
      await db.child('ballots/${widget.tournamentId}/${widget.matchId}').set({
        'results': ballotResults, 'round': round, 'timestamp': ServerValue.timestamp,
      });

      // Update Match Status
      await db.child('matches/${widget.tournamentId}/round_$round/${widget.matchId}').update({
        'status': 'Completed',
        'winner': _ranks.entries.firstWhere((e) => e.value == 1).key,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Submission Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}