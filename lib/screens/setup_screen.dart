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

  // --- Rules State ---
  String selectedFormat = 'WSDC';
  int prelimRounds = 3;

  // Mark Range Controllers
  final _minSubController = TextEditingController(text: "60");
  final _maxSubController = TextEditingController(text: "80");
  final _minReplyController = TextEditingController(text: "30");
  final _maxReplyController = TextEditingController(text: "40");

  // Round Pairing Rules (Round Number -> Pairing Method)
  Map<int, String> roundPairingRules = {
    1: 'Random', 
    2: 'Power Paired', 
    3: 'Power Paired'
  };

  // --- Validation Counters ---
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
    
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        selectedFormat = data['rule'] ?? 'WSDC';
        prelimRounds = data['prelims'] ?? 3;
        
        if (data['settings'] != null) {
          final s = data['settings'];
          _minSubController.text = s['minSubstantive']?.toString() ?? "60";
          _maxSubController.text = s['maxSubstantive']?.toString() ?? "80";
          _minReplyController.text = s['minReply']?.toString() ?? "30";
          _maxReplyController.text = s['maxReply']?.toString() ?? "40";
          
          if (s['pairingRules'] != null) {
            Map rules = s['pairingRules'];
            roundPairingRules = rules.map((k, v) => MapEntry(int.parse(k), v.toString()));
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
      // Remove rules for rounds that were decreased
      roundPairingRules.removeWhere((key, value) => key > total);
    });
  }

  Future<void> _launchTournament() async {
    setState(() => _isBusy = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      
      // Convert Map keys to String for Firebase compatibility
      Map<String, String> firebasePairingRules = 
          roundPairingRules.map((k, v) => MapEntry(k.toString(), v));

      await db.child('tournaments/${widget.tournamentId}').update({
        'status': 'Active',
        'currentRound': 1,
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              tournamentId: widget.tournamentId, 
              tournamentName: "Tournament Dashboard"
            )
          ),
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
        title: const Text("TOURNAMENT SETUP", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                Step(
                  title: const Text("Rules"),
                  isActive: _currentStep >= 0,
                  content: _buildRulesStep(),
                ),
                Step(
                  title: const Text("Teams"),
                  isActive: _currentStep >= 1,
                  content: _ListManager(
                    ref: db.child('teams/${widget.tournamentId}'),
                    label: "Team",
                    onCountChanged: (count) => setState(() => teamCount = count),
                  ),
                ),
                Step(
                  title: const Text("Logistics"),
                  isActive: _currentStep >= 2,
                  content: Column(
                    children: [
                      _ListManager(
                        ref: db.child('adjudicators/${widget.tournamentId}'),
                        label: "Judge",
                        onCountChanged: (count) => setState(() => judgeCount = count),
                      ),
                      const Divider(height: 30),
                      _ListManager(
                        ref: db.child('rooms/${widget.tournamentId}'),
                        label: "Room",
                        onCountChanged: (count) => setState(() => roomCount = count),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text("Launch"),
                  isActive: _currentStep >= 3,
                  content: _buildLaunchStep(),
                ),
              ],
            ),
    );
  }

  Widget _buildRulesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedFormat,
          decoration: const InputDecoration(labelText: "Debate Format", border: OutlineInputBorder()),
          items: ['WSDC', 'BP', 'AP'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => selectedFormat = val!),
        ),
        const SizedBox(height: 20),
        const Text("MARK RANGES", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF2264D7))),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildRangeInput("Min Sub", _minSubController)),
            const SizedBox(width: 10),
            Expanded(child: _buildRangeInput("Max Sub", _maxSubController)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildRangeInput("Min Reply", _minReplyController)),
            const SizedBox(width: 10),
            Expanded(child: _buildRangeInput("Max Reply", _maxReplyController)),
          ],
        ),
        const SizedBox(height: 25),
        Text("Preliminary Rounds: $prelimRounds", style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: prelimRounds.toDouble(), min: 1, max: 8, divisions: 7,
          activeColor: const Color(0xFF2264D7),
          onChanged: (v) => _updateRoundRules(v.toInt()),
        ),
        const Divider(),
        const Text("PAIRING PER ROUND", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF2264D7))),
        const SizedBox(height: 10),
        ...List.generate(prelimRounds, (index) {
          int roundNum = index + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Round $roundNum:"),
                DropdownButton<String>(
                  value: roundPairingRules[roundNum],
                  items: ['Random', 'Power Paired'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => roundPairingRules[roundNum] = val!),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRangeInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  Widget _buildLaunchStep() {
    bool canLaunch = teamCount >= 2 && roomCount >= 1;
    return Column(
      children: [
        const Icon(Icons.rocket_launch, size: 50, color: Color(0xFF2264D7)),
        const SizedBox(height: 10),
        _buildValidationTile("Teams Added ($teamCount/2+)", teamCount >= 2),
        _buildValidationTile("Judges Added ($judgeCount/1+)", judgeCount >= 1),
        _buildValidationTile("Rooms Added ($roomCount/1+)", roomCount >= 1),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: canLaunch ? _launchTournament : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text("FINALIZE & START TOURNAMENT", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildValidationTile(String text, bool isValid) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Icon(isValid ? Icons.check_circle : Icons.cancel, color: isValid ? Colors.green : Colors.red, size: 20),
      title: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}

// --- REUSABLE LIST MANAGER ---
class _ListManager extends StatefulWidget {
  final DatabaseReference ref;
  final String label;
  final Function(int) onCountChanged;

  const _ListManager({super.key, required this.ref, required this.label, required this.onCountChanged});

  @override
  State<_ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<_ListManager> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addItem() {
    String name = _controller.text.trim();
    if (name.isNotEmpty) {
      widget.ref.push().set({
        'name': name,
        'wins': 0,
        'totalMarks': 0,
      });
      _controller.clear();
      FocusScope.of(context).unfocus(); // Hides keyboard
    }
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
                decoration: InputDecoration(
                  hintText: "Enter ${widget.label} Name", 
                  isDense: true, 
                  border: const OutlineInputBorder()
                ),
                onSubmitted: (_) => _addItem(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF2264D7), size: 32), 
              onPressed: _addItem
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: StreamBuilder(
            stream: widget.ref.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                Future.microtask(() => widget.onCountChanged(0));
                return const Center(child: Text("No items added yet", style: TextStyle(color: Colors.grey, fontSize: 12)));
              }
              
              Map data = snapshot.data!.snapshot.value as Map;
              Future.microtask(() => widget.onCountChanged(data.length));
              
              return ListView(
                children: data.entries.map((e) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(e.value['name'] ?? ""),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                      onPressed: () => widget.ref.child(e.key).remove()
                    ),
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