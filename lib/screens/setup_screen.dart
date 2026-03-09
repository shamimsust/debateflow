import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  final String tournamentId;
  const SetupScreen({Key? key, required this.tournamentId}) : super(key: key);

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

  /// round -> rule
  Map<int, String> roundPairingRules = {
    1: 'Random',
    2: 'Power Paired',
    3: 'Power Paired',
  };

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

  Future<void> _loadExistingSettings() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('tournaments/${widget.tournamentId}')
          .get();

      if (!mounted) return;
      final v = snap.value;
      if (v is Map) {
        final data = Map<dynamic, dynamic>.from(v);

        setState(() {
          selectedFormat = data['rule']?.toString() ?? 'WSDC';
          prelimRounds = int.tryParse(data['prelims']?.toString() ?? "3") ?? 3;

          final settingsRaw = data['settings'];
          if (settingsRaw is Map) {
            final s = Map<dynamic, dynamic>.from(settingsRaw);
            _minSubController.text = s['minSubstantive']?.toString() ?? "60";
            _maxSubController.text = s['maxSubstantive']?.toString() ?? "80";
            _minReplyController.text = s['minReply']?.toString() ?? "30";
            _maxReplyController.text = s['maxReply']?.toString() ?? "40";

            final rulesRaw = s['pairingRules'];
            if (rulesRaw is Map) {
              final rules = Map<dynamic, dynamic>.from(rulesRaw);
              roundPairingRules = rules.map(
                (k, v) => MapEntry(int.tryParse(k.toString()) ?? 1, v.toString()),
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Load settings error: $e');
      // Non-fatal: keep defaults
    }
  }

  void _updateRoundRules(int total) {
    setState(() {
      prelimRounds = total;
      for (int i = 1; i <= total; i++) {
        roundPairingRules.putIfAbsent(i, () => i == 1 ? 'Random' : 'Power Paired');
      }
      roundPairingRules.removeWhere((key, _) => key > total);
    });
  }

  Future<void> _launchTournament() async {
    setState(() => _isBusy = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      final Map<String, String> firebasePairingRules =
          roundPairingRules.map((k, v) => MapEntry(k.toString(), v));

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

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            tournamentId: widget.tournamentId,
            tournamentName: "Tournament Dashboard",
          ),
        ),
        (route) => false,
      );
    } on FirebaseException catch (e, st) {
      debugPrint('Launch FirebaseException: ${e.code} ${e.message}');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase error: ${e.code}')),
        );
      }
    } catch (e, st) {
      debugPrint('Launch Error: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start tournament. See logs.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference db = FirebaseDatabase.instance.ref();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "TOURNAMENT SETUP",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
      ),
      body: _isBusy
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepTapped: (step) => setState(() => _currentStep = step),
              onStepContinue: () {
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              steps: [
                Step(title: const Text("Rules"), content: _buildRulesStep()),
                Step(
                  title: const Text("Teams"),
                  content: _ListManager(
                    dbRef: db.child('teams/${widget.tournamentId}'),
                    label: "Team",
                    includeStatsFields: true, // wins/totalMarks
                  ),
                ),
                Step(
                  title: const Text("Logistics"),
                  content: _buildLogisticsStep(db),
                ),
                Step(
                  title: const Text("Launch"),
                  content: _buildLaunchStep(db),
                ),
              ],
            ),
    );
  }

  Widget _buildRulesStep() {
    final rounds = roundPairingRules.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedFormat,
          decoration: const InputDecoration(
            labelText: "Format",
            border: OutlineInputBorder(),
          ),
          items: const ['WSDC', 'BP', 'AP']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) => setState(() => selectedFormat = val!),
        ),
        const SizedBox(height: 20),
        const Text(
          "SCORE RANGES",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2264D7)),
        ),
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
          value: prelimRounds.toDouble(),
          min: 1,
          max: 8,
          divisions: 7,
          activeColor: const Color(0xFF2264D7),
          onChanged: (v) => _updateRoundRules(v.toInt()),
        ),
        const Divider(),
        ...rounds.map(
          (roundNum) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Round $roundNum:"),
              DropdownButton<String>(
                value: roundPairingRules[roundNum],
                items: const ['Random', 'Power Paired']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => roundPairingRules[roundNum] = val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildLogisticsStep(DatabaseReference db) {
    return Column(
      children: [
        _ListManager(
          dbRef: db.child('adjudicators/${widget.tournamentId}'),
          label: "Judge",
          includeStatsFields: false,
        ),
        const SizedBox(height: 20),
        _ListManager(
          dbRef: db.child('rooms/${widget.tournamentId}'),
          label: "Room",
          includeStatsFields: false,
        ),
      ],
    );
  }

  /// Optimized: listen only to the 3 subtrees we need and avoid root-level `onValue`.
  Widget _buildLaunchStep(DatabaseReference db) {
    final teamsRef  = db.child('teams/${widget.tournamentId}');
    final judgesRef = db.child('adjudicators/${widget.tournamentId}');
    final roomsRef  = db.child('rooms/${widget.tournamentId}');

    return StreamBuilder<DatabaseEvent>(
      stream: teamsRef.onValue,
      builder: (context, teamsSnap) {
        final int teams = _safeMapLen(teamsSnap.data?.snapshot.value);

        return StreamBuilder<DatabaseEvent>(
          stream: judgesRef.onValue,
          builder: (context, judgesSnap) {
            final int judges = _safeMapLen(judgesSnap.data?.snapshot.value);

            return StreamBuilder<DatabaseEvent>(
              stream: roomsRef.onValue,
              builder: (context, roomsSnap) {
                final int rooms = _safeMapLen(roomsSnap.data?.snapshot.value);

                final int minRooms =
                    (teams / (selectedFormat == "BP" ? 4 : 2)).ceil();
                final bool canLaunch = teams >= 2 && judges >= 1 && rooms >= minRooms;

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
                      child: const Text(
                        "INITIALIZE TOURNAMENT",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildValidationTile(String text, bool isValid) {
    return ListTile(
      leading: Icon(isValid ? Icons.check_circle : Icons.error_outline,
          color: isValid ? Colors.green : Colors.orange),
      title: Text(text, style: const TextStyle(fontSize: 13)),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Defensive helper: treat non-Map as empty.
  int _safeMapLen(dynamic v) => (v is Map) ? v.length : 0;
}

// --- OPTIMIZED LIST MANAGER WITH BULK ADD ---
class _ListManager extends StatefulWidget {
  final DatabaseReference dbRef;
  final String label;
  final bool includeStatsFields; // teams need wins/totalMarks, others don't

  const _ListManager({
    Key? key,
    required this.dbRef,
    required this.label,
    required this.includeStatsFields,
  }) : super(key: key);

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

  Map<String, dynamic> _baseFields(String name) {
    // ensure the map can hold values of varying types (strings and ints)
    final Map<String, dynamic> base = {'name': name};
    if (widget.includeStatsFields) {
      base.addAll({'wins': 0, 'totalMarks': 0});
    }
    return base;
  }

  Future<void> _addItem() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    try {
      await widget.dbRef.push().set(_baseFields(name));
      _controller.clear();
    } on FirebaseException catch (e) {
      debugPrint('Add ${widget.label} FirebaseException: ${e.code} ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add ${widget.label}: ${e.code}')),
        );
      }
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
            onPressed: () async {
              final text = _bulkController.text.trim();
              if (text.isEmpty) return;

              final names = text.split(RegExp(r'\n|,')).map((s) => s.trim()).where((s) => s.isNotEmpty);
              final Map<String, Object?> updates = {};

              for (final name in names) {
                final key = widget.dbRef.push().key;
                if (key != null) {
                  updates[key] = _baseFields(name);
                }
              }

              try {
                if (updates.isNotEmpty) {
                  await widget.dbRef.update(updates); // one batched write
                }
                _bulkController.clear();
                if (mounted) Navigator.pop(context);
              } on FirebaseException catch (e) {
                debugPrint('Bulk add ${widget.label} error: ${e.code} ${e.message}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bulk add failed: ${e.code}')),
                  );
                }
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
                ),
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
          child: StreamBuilder<DatabaseEvent>(
            stream: widget.dbRef.onValue,
            builder: (context, snapshot) {
              final v = snapshot.data?.snapshot.value;
              if (v is! Map || v.isEmpty) {
                return const Center(
                  child: Text("None added", style: TextStyle(fontSize: 12, color: Colors.grey)),
                );
              }

              final Map data = v;
              final entries = data.entries.toList();

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  final String name = (e.value is Map)
                      ? (e.value['name']?.toString() ?? '')
                      : e.toString();

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => widget.dbRef.child(e.key).remove(),
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