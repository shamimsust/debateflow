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

  @override
  void dispose() {
    _nameController.dispose();
    _s1Controller.dispose();
    _s2Controller.dispose();
    _s3Controller.dispose();
    super.dispose();
  }

  Future<void> _loadTournamentRule() async {
    final snap = await FirebaseDatabase.instance.ref('tournaments/${widget.tournamentId}/rule').get();
    if (snap.exists && mounted) {
      setState(() {
        _tournamentRule = snap.value.toString();
      });
    }
  }

  // ✅ New: Delete Team Logic
  Future<void> _deleteTeam() async {
    if (_selectedTeamId == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Team?"),
        content: Text("Are you sure you want to remove ${_nameController.text}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      await FirebaseDatabase.instance.ref('teams/${widget.tournamentId}/$_selectedTeamId').remove();
      _clearForm();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Team deleted successfully")));
      }
    }
  }

  void _clearForm() {
    setState(() {
      _selectedTeamId = null;
      _isIronman = false;
      _nameController.clear();
      _s1Controller.clear();
      _s2Controller.clear();
      _s3Controller.clear();
    });
    _formKey.currentState?.reset();
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
        'wins': 0.0, // Initialize/Reset stats if new
        'totalMarks': 0.0,
        'lastUpdated': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${_nameController.text.trim()} saved!"), backgroundColor: Colors.green),
        );
        _clearForm();
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
        title: Text(isBP ? "Add Teams (BP)" : "Add Teams"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedTeamId != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteTeam),
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
                      
                      Map teams = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                      
                      // 🛠️ THE FIX: Check if ID still exists in the list to avoid Null Value error
                      String? safeVal = teams.containsKey(_selectedTeamId) ? _selectedTeamId : null;

                      return DropdownButtonFormField<String>(
                        key: UniqueKey(), // 🛠️ Fix: Force rebuild to prevent state conflicts
                        initialValue: safeVal,
                        decoration: _inputStyle("Choose Team to Edit"),
                        items: teams.entries.map((e) => DropdownMenuItem<String>(
                          value: e.key.toString(),
                          child: Text(e.value['name'] ?? "Unnamed"),
                        )).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedTeamId = val;
                            var t = teams[val];
                            _nameController.text = t['name']?.toString() ?? "";
                            _s1Controller.text = t['speaker1']?.toString() ?? "";
                            _s2Controller.text = t['speaker2']?.toString() ?? "";
                            _s3Controller.text = t['speaker3']?.toString() ?? "";
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
                  if(_selectedTeamId != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: TextButton(
                          onPressed: _clearForm,
                          child: const Text("Clear and Add New instead"),
                        ),
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