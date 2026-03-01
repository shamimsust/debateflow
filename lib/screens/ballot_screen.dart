import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';

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
    
    final settingsSnap = await FirebaseDatabase.instance
        .ref('tournaments/${widget.tournamentId}/settings')
        .get();
        
    if (settingsSnap.exists) {
      final s = Map<dynamic, dynamic>.from(settingsSnap.value as Map);
      setState(() {
        minSub = (s['minSubstantive'] ?? 60).toDouble();
        maxSub = (s['maxSubstantive'] ?? 80).toDouble();
        minReply = (s['minReply'] ?? 30).toDouble();
        maxReply = (s['maxReply'] ?? 40).toDouble();
      });
    }

    List<String> sideKeys = (debateRule == "BP") 
        ? ["sideOG", "sideOO", "sideCG", "sideCO"] 
        : ["sideA", "sideB"];

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

        final teamSnap = await FirebaseDatabase.instance
            .ref('teams/${widget.tournamentId}/$teamId')
            .get();
        
        if (teamSnap.exists) {
          Map data = teamSnap.value as Map;
          List<String> names = [];
          if (data['speaker1']?.isNotEmpty == true) names.add(data['speaker1']);
          if (data['speaker2']?.isNotEmpty == true) names.add(data['speaker2']);
          if (data['speaker3']?.isNotEmpty == true) names.add(data['speaker3']);
          
          setState(() {
            _speakerNames[teamName] = names;
          });
        }
      }
    }
  }

  // 🛠️ UPDATED AUTO-DETECT: Ignores the Reply speech (idx 3)
  void _checkAndSetIronman(String teamName) {
    if (debateRule != "WSDC") return;
    
    List<String?> selected = _selectedSpeakers[teamName]!;
    
    // Only check Pos 1, 2, and 3 (substantive speeches)
    // The reply speaker is expected to be a duplicate and shouldn't trigger Ironman
    List<String> substantiveNames = selected
        .sublist(0, 3) 
        .whereType<String>()
        .toList();
    
    bool hasSubstantiveDuplicates = substantiveNames.length > substantiveNames.toSet().length;

    if (_teamIronmanStatus[teamName] != hasSubstantiveDuplicates) {
      setState(() {
        _teamIronmanStatus[teamName] = hasSubstantiveDuplicates;
      });
    }
  }

  double _getTeamTotal(String teamName) {
    return _scoreMap[teamName]!.fold(0.0, (sum, ctrl) => sum + (double.tryParse(ctrl.text) ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text("$debateRule Ballot — R${widget.matchData['round']}"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._scoreMap.keys.map((teamName) => _buildTeamCard(teamName)).toList(),
                const SizedBox(height: 20),
                _buildSubmitButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildTeamCard(String teamName) {
    bool isIronman = _teamIronmanStatus[teamName] ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isIronman ? const Color(0xFF2264D7).withOpacity(0.3) : Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Total: ${_getTeamTotal(teamName).toStringAsFixed(1)} pts", 
                        style: const TextStyle(color: Color(0xFF2264D7), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (debateRule == "WSDC") ...[
                   Row(
                     children: [
                       Text("Ironman?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isIronman ? const Color(0xFF2264D7) : Colors.blueGrey)),
                       Checkbox(
                         value: isIronman,
                         activeColor: const Color(0xFF2264D7),
                         onChanged: (v) => setState(() => _teamIronmanStatus[teamName] = v!),
                       ),
                     ],
                   ),
                ],
                if (debateRule == "BP") _buildRankPicker(teamName),
              ],
            ),
            const Divider(height: 20),
            ..._scoreMap[teamName]!.asMap().entries.map((entry) => _buildSpeechRow(teamName, entry.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechRow(String teamName, int idx) {
    bool isReply = (debateRule == "WSDC" && idx == 3);
    List<String> speakers = _speakerNames[teamName] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedSpeakers[teamName]![idx],
              hint: Text(isReply ? "Reply" : "Pos ${idx + 1}"),
              decoration: InputDecoration(
                isDense: true, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              items: speakers.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (val) {
                setState(() => _selectedSpeakers[teamName]![idx] = val);
                _checkAndSetIronman(teamName); 
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _scoreMap[teamName]![idx],
              onChanged: (v) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: isReply ? minReply.toStringAsFixed(0) : minSub.toStringAsFixed(0),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankPicker(String teamName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: DropdownButton<int>(
        value: _ranks[teamName],
        underline: const SizedBox(),
        onChanged: (v) => setState(() => _ranks[teamName] = v!),
        items: [1, 2, 3, 4].map((i) => DropdownMenuItem(value: i, child: Text("Rank $i"))).toList(),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _handleSubmission,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2264D7), 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        ),
        child: const Text("SUBMIT FINAL BALLOT", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _handleSubmission() async {
    try {
      for (var teamName in _selectedSpeakers.keys) {
        List<String?> selected = _selectedSpeakers[teamName]!;
        if (selected.any((s) => s == null)) {
          throw "Please select all speaker names for $teamName";
        }

        if (debateRule == "WSDC") {
          bool isIronmanChecked = _teamIronmanStatus[teamName] ?? false;
          
          // 🛠️ VALIDATION FIX: Only validate unique names for the first 3 speeches
          Set<String?> uniqueSubstantiveNames = selected.sublist(0, 3).where((n) => n != null).toSet();
          
          if (uniqueSubstantiveNames.length < 3 && !isIronmanChecked) {
            throw "Team $teamName has duplicate substantive speakers. Please verify if they are an Ironman team.";
          }
        }
      }

      for (var teamName in _scoreMap.keys) {
        for (int i = 0; i < _scoreMap[teamName]!.length; i++) {
          double score = double.tryParse(_scoreMap[teamName]![i].text) ?? 0;
          bool isReply = (debateRule == "WSDC" && i == 3);

          if (debateRule == "WSDC") {
            if (!isReply && (score < minSub || score > maxSub)) {
              throw "Substantive score for $teamName must be $minSub-$maxSub";
            }
            if (isReply && (score < minReply || score > maxReply)) {
              throw "Reply score for $teamName must be $minReply-$maxReply";
            }
          } else if (debateRule == "BP") {
             if (score < 50 || score > 100) throw "BP scores must be 50-100";
          }
        }
      }

      if (debateRule == "WSDC") {
        var teams = _scoreMap.keys.toList();
        if (_getTeamTotal(teams[0]) == _getTeamTotal(teams[1])) {
          throw "Total points cannot be equal. Please adjust to pick a winner.";
        }
      }

      setState(() => _isSubmitting = true);
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
          'isIronman': _teamIronmanStatus[teamName],
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

      await db.child('matches/${widget.tournamentId}/round_${widget.matchData['round']}/${widget.matchId}').update({
        'status': 'Completed',
        'winner': _ranks.entries.firstWhere((e) => e.value == 1).key,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}