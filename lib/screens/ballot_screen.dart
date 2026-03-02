import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/debate_validator.dart';

class BallotScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final Map matchData;

  const BallotScreen({super.key, required this.tournamentId, required this.matchId, required this.matchData});

  @override
  State<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends State<BallotScreen> {
  final Map<String, List<TextEditingController>> _scoreMap = {};
  final Map<String, bool> _teamIronmanStatus = {}; 
  final Map<String, int> _ranks = {}; 
  final Map<String, String> _teamIdMap = {}; 
  final Map<String, List<String>> _speakerNames = {};
  final Map<String, List<String?>> _selectedSpeakers = {};
  
  String debateRule = "WSDC";
  bool _isSubmitting = false;
  double minSub = 60, maxSub = 80, minReply = 30, maxReply = 40;

  @override
  void initState() {
    super.initState();
    _initBallot();
  }

  void _initBallot() async {
    debateRule = widget.matchData['rule'] ?? "WSDC";
    final settingsSnap = await FirebaseDatabase.instance.ref('tournaments/${widget.tournamentId}/settings').get();
    if (settingsSnap.exists) {
      final s = Map<dynamic, dynamic>.from(settingsSnap.value as Map);
      setState(() {
        minSub = (s['minSubstantive'] ?? 60).toDouble();
        maxSub = (s['maxSubstantive'] ?? 80).toDouble();
        minReply = (s['minReply'] ?? 30).toDouble();
        maxReply = (s['maxReply'] ?? 40).toDouble();
      });
    }

    List<String> sideKeys = (debateRule == "BP") ? ["sideOG", "sideOO", "sideCG", "sideCO"] : ["sideA", "sideB"];

    for (var key in sideKeys) {
      String? teamName = widget.matchData[key];
      String? teamId = widget.matchData['${key}Id'];
      if (teamName != null && teamId != null) {
        _teamIdMap[teamName] = teamId;
        _ranks[teamName] = 1;
        _teamIronmanStatus[teamName] = false; 
        int speechCount = (debateRule == "BP") ? 2 : 4;
        _scoreMap[teamName] = List.generate(speechCount, (_) => TextEditingController());
        _selectedSpeakers[teamName] = List.generate(speechCount, (_) => null);
        
        final teamSnap = await FirebaseDatabase.instance.ref('teams/${widget.tournamentId}/$teamId').get();
        if (teamSnap.exists) {
          Map data = teamSnap.value as Map;
          setState(() => _speakerNames[teamName] = [data['speaker1'], data['speaker2'], data['speaker3']].whereType<String>().toList());
        }
      }
    }
  }

  double _getTeamTotal(String teamName) => _scoreMap[teamName]!.fold(0.0, (sum, ctrl) => sum + (double.tryParse(ctrl.text) ?? 0.0));

  @override
  Widget build(BuildContext context) {
    String winner = "";
    double margin = 0;
    if (debateRule == "WSDC" && _scoreMap.length == 2) {
      var keys = _scoreMap.keys.toList();
      double t1 = _getTeamTotal(keys[0]);
      double t2 = _getTeamTotal(keys[1]);
      if (t1 != t2) {
        winner = t1 > t2 ? keys[0] : keys[1];
        margin = (t1 - t2).abs();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text("$debateRule Ballot"), backgroundColor: const Color(0xFF2264D7), foregroundColor: Colors.white),
      body: _isSubmitting ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (debateRule == "WSDC" && winner.isNotEmpty) _buildWinnerBanner(winner, margin),
            ..._scoreMap.keys.map((teamName) => _buildTeamCard(teamName)).toList(),
            const SizedBox(height: 20),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerBanner(String winner, double margin) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text("CURRENT WINNER", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(winner, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Margin: ${margin.toStringAsFixed(1)} pts", style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String teamName) {
    String sideLabel = "";
    if (debateRule == "BP") {
      if (widget.matchData['sideOG'] == teamName) sideLabel = "Opening Government";
      if (widget.matchData['sideOO'] == teamName) sideLabel = "Opening Opposition";
      if (widget.matchData['sideCG'] == teamName) sideLabel = "Closing Government";
      if (widget.matchData['sideCO'] == teamName) sideLabel = "Closing Opposition";
    }

    return Card(
      elevation: 0, 
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), 
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sideLabel.isNotEmpty) 
                      Text(sideLabel.toUpperCase(), 
                        style: const TextStyle(color: Color(0xFF2264D7), fontWeight: FontWeight.bold, fontSize: 10)),
                    Text(teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (debateRule == "WSDC") Row(
                  children: [
                    const Text("Ironman", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Checkbox(
                      value: _teamIronmanStatus[teamName], 
                      activeColor: const Color(0xFF2264D7),
                      onChanged: (val) => setState(() => _teamIronmanStatus[teamName] = val!),
                    )
                  ],
                ),
                if (debateRule == "BP") _buildRankPicker(teamName) 
                else Text("${_getTeamTotal(teamName).toStringAsFixed(1)} pts", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
              ],
            ),
            const Divider(height: 24),
            ..._scoreMap[teamName]!.asMap().entries.map((e) => _buildSpeechRow(teamName, e.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechRow(String teamName, int idx) {
    String posLabel = "Speaker ${idx + 1}";
    if (debateRule == "BP") {
       posLabel = (idx == 0) ? "Member" : "Whip";
    } else if (idx == 3) {
      posLabel = "Reply";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: DropdownButtonFormField<String>(
            initialValue: _selectedSpeakers[teamName]![idx], // ✅ Fixed: changed 'value' to 'initialValue'
            hint: Text(posLabel, style: const TextStyle(fontSize: 12)),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: _speakerNames[teamName]!.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _selectedSpeakers[teamName]![idx] = v),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 1, child: TextField(
            controller: _scoreMap[teamName]![idx],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => setState(() {}),
          )),
        ],
      ),
    );
  }

  Widget _buildRankPicker(String teamName) {
    return DropdownButton<int>(
      value: _ranks[teamName],
      onChanged: (v) => setState(() => _ranks[teamName] = v!),
      items: [1,2,3,4].map((i) => DropdownMenuItem(value: i, child: Text("Rank $i"))).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submit,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
      child: const Text("SUBMIT FINAL BALLOT"),
    );
  }

  Future<void> _submit() async {
    Map<String, List<double>> currentScores = _scoreMap.map((key, value) => MapEntry(key, value.map((c) => double.tryParse(c.text) ?? 0.0).toList()));
    Map<String, dynamic> settings = {'minSub': minSub, 'maxSub': maxSub, 'minReply': minReply, 'maxReply': maxReply};
    
    final validator = (debateRule == "WSDC") ? WSDCValidator() : BPValidator();
    String? error = validator.validate(currentScores, _ranks, settings);
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }

    for (var team in _selectedSpeakers.keys) {
      if (_selectedSpeakers[team]!.any((s) => s == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Assign all speakers first!")));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    
    try {
      final db = FirebaseDatabase.instance.ref();
      Map<String, dynamic> results = {};

      for (var teamName in _scoreMap.keys) {
        String tId = _teamIdMap[teamName]!;
        double total = _getTeamTotal(teamName);
        
        if (debateRule == "WSDC") {
          double otherTotal = _getTeamTotal(_scoreMap.keys.firstWhere((k) => k != teamName));
          _ranks[teamName] = (total > otherTotal) ? 1 : 2;
        }

        results[tId] = {
          'teamName': teamName,
          'total': total,
          'rank': _ranks[teamName],
          'isIronman': _teamIronmanStatus[teamName] ?? false,
          'speeches': _scoreMap[teamName]!.asMap().entries.map((e) => {
            'speakerName': _selectedSpeakers[teamName]![e.key],
            'score': double.tryParse(e.value.text) ?? 0.0,
          }).toList(),
        };
      }

      await db.child('ballots/${widget.tournamentId}/${widget.matchId}').set({
        'results': results,
        'round': widget.matchData['round'],
        'timestamp': ServerValue.timestamp,
      });

      String winnerName = _ranks.entries.firstWhere((e) => e.value == 1).key;
      await db.child('matches/${widget.tournamentId}/round_${widget.matchData['round']}/${widget.matchId}').update({
        'status': 'Completed',
        'winner': winnerName,
      });

      for (var entry in results.entries) {
        double pts = (debateRule == "WSDC") 
          ? (entry.value['rank'] == 1 ? 1.0 : 0.0) 
          : (3.0 - (entry.value['rank'] - 1));

        await db.child('teams/${widget.tournamentId}/${entry.key}').runTransaction((Object? data) {
          if (data == null) return Transaction.abort();
          Map t = Map<String, dynamic>.from(data as Map);
          t['wins'] = (t['wins'] ?? 0).toDouble() + pts;
          t['totalMarks'] = (t['totalMarks'] ?? 0).toDouble() + entry.value['total'];
          return Transaction.success(t);
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ballot Submitted!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}