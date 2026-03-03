import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  final String tournamentId;
  const SetupScreen({super.key, required this.tournamentId});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentStep = 0;
  bool _isBusy = false;

  String selectedFormat = 'WSDC';
  int prelimRounds = 3;

  final _minSubController = TextEditingController(text: "60");
  final _maxSubController = TextEditingController(text: "80");
  final _minReplyController = TextEditingController(text: "30");
  final _maxReplyController = TextEditingController(text: "40");

  Map<int, String> roundPairingRules = {1: 'Random', 2: 'Power Paired', 3: 'Power Paired'};

  @override
  void initState() {
    super.initState();
    _loadExistingSettings();
  }

  @override
  void dispose() {
    _minSubController.dispose();
    _maxSubController.dispose();
    _minReplyController.dispose();
    _maxReplyController.dispose();
    super.dispose();
  }

  void _loadExistingSettings() async {
    final snapshot = await FirebaseDatabase.instance
        .ref('tournaments/${widget.tournamentId}')
        .get();
    
    if (snapshot.exists && mounted) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      setState(() {
        selectedFormat = data['rule']?.toString() ?? 'WSDC';
        prelimRounds = int.tryParse(data['prelims']?.toString() ?? "3") ?? 3;
        
        if (data['settings'] != null) {
          final s = Map<dynamic, dynamic>.from(data['settings']);
          _minSubController.text = s['minSubstantive']?.toString() ?? "60";
          _maxSubController.text = s['maxSubstantive']?.toString() ?? "80";
          _minReplyController.text = s['minReply']?.toString() ?? "30";
          _maxReplyController.text = s['maxReply']?.toString() ?? "40";
          
          if (s['pairingRules'] != null) {
            Map rules = s['pairingRules'] as Map;
            roundPairingRules = rules.map((k, v) => MapEntry(int.parse(k.toString()), v.toString()));
          }
        }
      });
    }
  }

  void _updateRoundRules(int total) {
    setState(() {
      prelimRounds = total;
      for (int i = 1; i <= total; i++) {
        roundPairingRules.putIfAbsent(i, () => i == 1 ? 'Random' : 'Power Paired');
      }
      roundPairingRules.removeWhere((key, value) => key > total);
    });
  }

  Future<void> _launchTournament() async {
    setState(() => _isBusy = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      Map<String, String> firebasePairingRules = roundPairingRules.map((k, v) => MapEntry(k.toString(), v));

      await db.child('tournaments/${widget.tournamentId}').update({
        'status': 'Active',
        'currentRound': "1",
        'rule': selectedFormat,
        'prelims': prelimRounds,
        'lastUpdated': ServerValue.timestamp,
        'settings': {
          'minSubstantive': double.tryParse(_minSubController.text) ?? 60.0,
          'maxSubstantive': double.tryParse(_maxSubController.text) ?? 80.0,
          'minReply': double.tryParse(_minReplyController.text) ?? 30.0,
          'maxReply': double.tryParse(_maxReplyController.text) ?? 40.0,
          'isPairingLocked': false,
          'pairingRules': firebasePairingRules,
        }
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(tournamentId: widget.tournamentId, tournamentName: "Tournament Dashboard")),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Launch Error: $e");
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instance.ref();

    return Scaffold(
      appBar: AppBar(
        title: const Text("TOURNAMENT SETUP", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
      ),
      body: _isBusy 
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepTapped: (step) => setState(() => _currentStep = step),
              onStepContinue: () => setState(() => _currentStep < 3 ? _currentStep++ : null),
              onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
              steps: [
                Step(title: const Text("Rules"), content: _buildRulesStep()),
                Step(title: const Text("Teams"), content: _ListManager(dbRef: db.child('teams/${widget.tournamentId}'), label: "Team")),
                Step(title: const Text("Logistics"), content: _buildLogisticsStep(db)),
                Step(title: const Text("Launch"), content: _buildLaunchStep(db)),
              ],
            ),
    );
  }

  Widget _buildRulesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedFormat,
          decoration: const InputDecoration(labelText: "Format", border: OutlineInputBorder()),
          items: ['WSDC', 'BP', 'AP'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => selectedFormat = val!),
        ),
        const SizedBox(height: 20),
        const Text("SCORE RANGES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2264D7))),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _buildRangeInput("Min Sub", _minSubController)), const SizedBox(width: 10), Expanded(child: _buildRangeInput("Max Sub", _maxSubController))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _buildRangeInput("Min Reply", _minReplyController)), const SizedBox(width: 10), Expanded(child: _buildRangeInput("Max Reply", _maxReplyController))]),
        const SizedBox(height: 25),
        Text("Preliminary Rounds: $prelimRounds", style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: prelimRounds.toDouble(), min: 1, max: 8, divisions: 7, activeColor: const Color(0xFF2264D7), onChanged: (v) => _updateRoundRules(v.toInt())),
        const Divider(),
        ...roundPairingRules.keys.map((roundNum) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Round $roundNum:"),
            DropdownButton<String>(
              value: roundPairingRules[roundNum],
              items: ['Random', 'Power Paired'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => roundPairingRules[roundNum] = val!),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildRangeInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl, 
      keyboardType: TextInputType.number, 
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder())
    );
  }

  Widget _buildLogisticsStep(DatabaseReference db) {
    return Column(
      children: [
        _ListManager(dbRef: db.child('adjudicators/${widget.tournamentId}'), label: "Judge"),
        const SizedBox(height: 20),
        _ListManager(dbRef: db.child('rooms/${widget.tournamentId}'), label: "Room"),
      ],
    );
  }

  Widget _buildLaunchStep(DatabaseReference db) {
    return StreamBuilder(
      stream: db.onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final data = snapshot.data!.snapshot.value as Map? ?? {};
        final int teams = (data['teams']?[widget.tournamentId] as Map? ?? {}).length;
        final int judges = (data['adjudicators']?[widget.tournamentId] as Map? ?? {}).length;
        final int rooms = (data['rooms']?[widget.tournamentId] as Map? ?? {}).length;
        
        // Rooms needed: Teams / 2 for WSDC, Teams / 4 for BP
        final int minRooms = (teams / (selectedFormat == "BP" ? 4 : 2)).ceil();
        bool canLaunch = teams >= 2 && judges >= 1 && rooms >= minRooms;

        return Column(
          children: [
            const Icon(Icons.rocket_launch_rounded, size: 50, color: Colors.green),
            _buildValidationTile("Teams ($teams/2+)", teams >= 2),
            _buildValidationTile("Judges ($judges/1+)", judges >= 1),
            _buildValidationTile("Rooms ($rooms/$minRooms needed)", rooms >= minRooms),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: canLaunch ? _launchTournament : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("INITIALIZE TOURNAMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValidationTile(String text, bool isValid) {
    return ListTile(
      leading: Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? Colors.green : Colors.orange),
      title: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}

// --- OPTIMIZED LIST MANAGER WITH BULK ADD ---
class _ListManager extends StatefulWidget {
  final DatabaseReference dbRef;
  final String label;
  const _ListManager({required this.dbRef, required this.label}); 

  @override
  State<_ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<_ListManager> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _bulkController = TextEditingController();

  @override
  void dispose() { 
    _controller.dispose(); 
    _bulkController.dispose();
    super.dispose(); 
  }

  void _addItem() {
    if (_controller.text.trim().isNotEmpty) {
      widget.dbRef.push().set({'name': _controller.text.trim(), 'wins': 0, 'totalMarks': 0});
      _controller.clear();
    }
  }

  void _showBulkAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Bulk Add ${widget.label}s"),
        content: TextField(
          controller: _bulkController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: "Enter names (one per line or separated by commas)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final text = _bulkController.text.trim();
              if (text.isNotEmpty) {
                final names = text.split(RegExp(r'\n|,'));
                for (var name in names) {
                  final trimmed = name.trim();
                  if (trimmed.isNotEmpty) {
                    widget.dbRef.push().set({'name': trimmed, 'wins': 0, 'totalMarks': 0});
                  }
                }
                _bulkController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller, 
                onSubmitted: (_) => _addItem(),
                decoration: InputDecoration(
                  hintText: "Add ${widget.label}...", 
                  isDense: true, 
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded, size: 20),
                    onPressed: _showBulkAddDialog,
                  ),
                )
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF2264D7), size: 36), 
              onPressed: _addItem,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: StreamBuilder(
            stream: widget.dbRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text("None added", style: TextStyle(fontSize: 12, color: Colors.grey)));
              }
              final Map data = snapshot.data!.snapshot.value as Map;
              final entries = data.entries.toList();
              
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      dense: true,
                      title: Text(e.value['name']?.toString() ?? "", style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), 
                        onPressed: () => widget.dbRef.child(e.key).remove()
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}