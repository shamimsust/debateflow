import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AddTeamScreen extends StatefulWidget {
  final String tournamentId;
  const AddTeamScreen({super.key, required this.tournamentId});

  @override
  State<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends State<AddTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _s1Controller = TextEditingController();
  final _s2Controller = TextEditingController();
  final _s3Controller = TextEditingController();
  
  String? _selectedTeamId; 
  bool _isIronman = false;
  bool _isLoading = false;
  String _tournamentRule = "WSDC"; 

  @override
  void initState() {
    super.initState();
    _loadTournamentRule();
  }

  Future<void> _loadTournamentRule() async {
    final snap = await FirebaseDatabase.instance.ref('tournaments/${widget.tournamentId}/rule').get();
    if (snap.exists && mounted) {
      setState(() {
        _tournamentRule = snap.value.toString();
      });
    }
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseDatabase.instance.ref();
      final DatabaseReference teamRef = _selectedTeamId != null 
          ? db.child('teams/${widget.tournamentId}/$_selectedTeamId')
          : db.child('teams/${widget.tournamentId}').push();

      await teamRef.update({
        'name': _nameController.text.trim(),
        'speaker1': _s1Controller.text.trim(),
        'speaker2': _s2Controller.text.trim(),
        'speaker3': (_tournamentRule == "BP" || _isIronman) ? "" : _s3Controller.text.trim(),
        'isIronman': _isIronman,
        'lastUpdated': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${_nameController.text.trim()} saved!"), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // 🛠️ THE FIX: Reset everything to allow adding another team immediately
        setState(() {
          _selectedTeamId = null;
          _nameController.clear();
          _s1Controller.clear();
          _s2Controller.clear();
          _s3Controller.clear();
          _isIronman = false;
        });
        _formKey.currentState!.reset(); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsQuery = FirebaseDatabase.instance.ref('teams/${widget.tournamentId}');
    bool isBP = _tournamentRule == "BP";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isBP ? "Add Teams (BP - 2 Spk)" : "Add Teams"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        // 🛠️ ADDED: Done button to go back only when finished
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Quick Select / Edit Existing"),
                  const SizedBox(height: 10),
                  
                  StreamBuilder(
                    stream: teamsQuery.onValue,
                    builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                      if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                        return const Text("No teams registered yet.");
                      }
                      Map teams = snapshot.data!.snapshot.value as Map;
                      return DropdownButtonFormField<String>(
                        value: _selectedTeamId,
                        decoration: _inputStyle("Choose Team to Edit"),
                        items: teams.entries.map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value['name'] ?? "Unnamed"),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedTeamId = val;
                            var t = teams[val];
                            _nameController.text = t['name'] ?? "";
                            _s1Controller.text = t['speaker1'] ?? "";
                            _s2Controller.text = t['speaker2'] ?? "";
                            _s3Controller.text = t['speaker3'] ?? "";
                            _isIronman = t['isIronman'] ?? false;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Team Identity"),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputStyle("Team Name"),
                    validator: (v) => v!.isEmpty ? "Enter team name" : null,
                  ),
                  
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Speakers"),
                      if (!isBP)
                        Row(
                          children: [
                            const Text("Ironman", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Switch(
                              value: _isIronman,
                              onChanged: (val) => setState(() => _isIronman = val),
                            ),
                          ],
                        ),
                    ],
                  ),
                  
                  TextFormField(
                    controller: _s1Controller,
                    decoration: _inputStyle("Speaker 1"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _s2Controller,
                    decoration: _inputStyle("Speaker 2"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  
                  if (!isBP && !_isIronman) ...[
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _s3Controller,
                      decoration: _inputStyle("Speaker 3"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveTeam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2264D7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_selectedTeamId == null ? "SAVE & ADD NEXT" : "UPDATE TEAM"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Button to clear form without saving
                  if(_selectedTeamId != null)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _selectedTeamId = null;
                          _nameController.clear();
                          _s1Controller.clear();
                          _s2Controller.clear();
                          _s3Controller.clear();
                        }),
                        child: const Text("Clear and Add New instead"),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2),
    );
  }
}