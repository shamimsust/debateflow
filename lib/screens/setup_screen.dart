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

  int teamCount = 0;
  int judgeCount = 0;
  int roomCount = 0;

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
        'currentRound': "1", // Saved as String for consistency
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
        title: const Text("TOURNAMENT SETUP", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
      ),
      body: _isBusy 
          ? const Center(child: CircularProgressIndicator())
          : Theme(
              data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2264D7))),
              child: Stepper(
                type: StepperType.horizontal,
                currentStep: _currentStep,
                onStepTapped: (step) => setState(() => _currentStep = step),
                onStepContinue: () => setState(() => _currentStep < 3 ? _currentStep++ : null),
                onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
                steps: [
                  Step(title: const Text("Rules"), isActive: _currentStep >= 0, content: _buildRulesStep()),
                  Step(title: const Text("Teams"), isActive: _currentStep >= 1, content: _ListManager(ref: db.child('teams/${widget.tournamentId}'), label: "Team", onCountChanged: (count) { if(mounted) setState(() => teamCount = count); })),
                  Step(title: const Text("Logistics"), isActive: _currentStep >= 2, content: _buildLogisticsStep(db)),
                  Step(title: const Text("Launch"), isActive: _currentStep >= 3, content: _buildLaunchStep()),
                ],
              ),
            ),
    );
  }

  Widget _buildLogisticsStep(DatabaseReference db) {
    return Column(
      children: [
        _ListManager(ref: db.child('adjudicators/${widget.tournamentId}'), label: "Judge", onCountChanged: (count) { if(mounted) setState(() => judgeCount = count); }),
        const Divider(height: 40),
        _ListManager(ref: db.child('rooms/${widget.tournamentId}'), label: "Room", onCountChanged: (count) { if(mounted) setState(() => roomCount = count); }),
      ],
    );
  }

  Widget _buildRulesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedFormat,
          decoration: const InputDecoration(labelText: "Format", border: OutlineInputBorder()),
          items: ['WSDC', 'BP', 'AP'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => selectedFormat = val!),
        ),
        const SizedBox(height: 20),
        const Text("SPEAKER SCORE RANGES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2264D7))),
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
        )).toList(),
      ],
    );
  }

  Widget _buildRangeInput(String label, TextEditingController ctrl) {
    return TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder()));
  }

  Widget _buildLaunchStep() {
    bool canLaunch = teamCount >= 2 && judgeCount >= 1 && roomCount >= (teamCount / 2).ceil();
    return Column(
      children: [
        const Icon(Icons.rocket_launch_rounded, size: 60, color: Colors.green),
        const SizedBox(height: 20),
        _buildValidationTile("Teams ($teamCount/2+)", teamCount >= 2),
        _buildValidationTile("Judges ($judgeCount/1+)", judgeCount >= 1),
        _buildValidationTile("Rooms ($roomCount needed)", roomCount >= (teamCount / 2).ceil()),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: canLaunch ? _launchTournament : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text("INITIALIZE TOURNAMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildValidationTile(String text, bool isValid) {
    return ListTile(leading: Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? Colors.green : Colors.orange), title: Text(text));
  }
}

class _ListManager extends StatefulWidget {
  final DatabaseReference ref;
  final String label;
  final Function(int) onCountChanged;

  const _ListManager({required this.ref, required this.label, required this.onCountChanged}); 
  
  @override
  State<_ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<_ListManager> {
  final TextEditingController _controller = TextEditingController();

  void _addItem() {
    String name = _controller.text.trim();
    if (name.isNotEmpty) {
      widget.ref.push().set({'name': name, 'wins': 0, 'totalMarks': 0});
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: "Add ${widget.label}...", border: const OutlineInputBorder()))),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add_box, size: 40, color: Color(0xFF2264D7)), onPressed: _addItem),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 180,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: StreamBuilder(
            stream: widget.ref.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                // 🛡️ Safe callback to parent
                Future.microtask(() { if(mounted) widget.onCountChanged(0); });
                return const Center(child: Text("Empty", style: TextStyle(color: Colors.grey)));
              }
              
              final Map data = snapshot.data!.snapshot.value as Map;
              // 🛡️ Safe callback to parent
              Future.microtask(() { if(mounted) widget.onCountChanged(data.length); });
              
              return ListView(
                padding: const EdgeInsets.all(4),
                children: data.entries.map((e) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(e.value['name']?.toString() ?? ""),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => widget.ref.child(e.key).remove()),
                  ),
                )).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}