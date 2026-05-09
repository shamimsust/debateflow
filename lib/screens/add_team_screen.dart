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
  final _bulkSpeakerController = TextEditingController();
  
  List<TextEditingController> _speakerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  String? _selectedTeamId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bulkSpeakerController.dispose();
    for (var c in _speakerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Speaker Management ---

  void _addSpeakerField([String initialValue = ""]) {
    setState(() {
      _speakerControllers.add(TextEditingController(text: initialValue));
    });
  }

  void _removeSpeakerField(int index) {
    if (_speakerControllers.length > 1) {
      setState(() {
        _speakerControllers[index].dispose();
        _speakerControllers.removeAt(index);
      });
    }
  }

  void _showBulkImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bulk Add Speakers"),
        content: TextField(
          controller: _bulkSpeakerController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: "Enter names (one per line)\ne.g.\nJohn Doe\nJane Smith",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final names = _bulkSpeakerController.text
                  .split('\n')
                  .where((s) => s.trim().isNotEmpty)
                  .toList();
              
              if (names.isNotEmpty) {
                setState(() {
                  if (_speakerControllers.length == 1 && _speakerControllers[0].text.isEmpty) {
                    _speakerControllers.clear();
                  }
                  for (var name in names) {
                    _speakerControllers.add(TextEditingController(text: name.trim()));
                  }
                });
                _bulkSpeakerController.clear();
              }
              Navigator.pop(context);
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  // --- Database Operations ---

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseDatabase.instance.ref();
      // If a team is selected, update it; otherwise, push a new one
      final DatabaseReference teamRef = _selectedTeamId != null 
          ? db.child('teams/${widget.tournamentId}/$_selectedTeamId')
          : db.child('teams/${widget.tournamentId}').push();

      List<String> speakerNames = _speakerControllers
          .map((c) => c.text.trim())
          .where((name) => name.isNotEmpty)
          .toList();

      await teamRef.update({
        'name': _nameController.text.trim(),
        'speakers': speakerNames,
        'lastUpdated': ServerValue.timestamp,
        'wins': 0.0,
        'totalMarks': 0.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Roster updated successfully!"), backgroundColor: Colors.green),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedTeamId = null;
      _nameController.clear();
      for (var c in _speakerControllers) {
        c.dispose();
      }
      _speakerControllers = [TextEditingController(), TextEditingController(), TextEditingController()];
    });
  }

  // Populate form when a team is selected from dropdown
  void _onTeamSelected(String? id, Map? data) {
    if (id == null || data == null) return;
    
    setState(() {
      _selectedTeamId = id;
      _nameController.text = data['name'] ?? "";
      
      // Clear current controllers
      for (var c in _speakerControllers) { c.dispose(); }
      
      final List? speakers = data['speakers'];
      if (speakers != null && speakers.isNotEmpty) {
        _speakerControllers = speakers.map((s) => TextEditingController(text: s.toString())).toList();
      } else {
        _speakerControllers = [TextEditingController(), TextEditingController(), TextEditingController()];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Team Roster"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedTeamId != null)
            IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearForm)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder(
            stream: FirebaseDatabase.instance.ref('teams/${widget.tournamentId}').onValue,
            builder: (context, snapshot) {
              List<DropdownMenuItem<String>> teamItems = [
                const DropdownMenuItem(value: null, child: Text("Create New Team..."))
              ];
              Map<String, dynamic> allTeamsData = {};

              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                allTeamsData = data;
                data.forEach((key, value) {
                  teamItems.add(DropdownMenuItem(
                    value: key,
                    child: Text(value['name'] ?? "Unnamed Team"),
                  ));
                });
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Select Existing Team"),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTeamId,
                        items: teamItems,
                        onChanged: (val) => _onTeamSelected(val, allTeamsData[val]),
                        decoration: _inputStyle("Choose a team from setup"),
                      ),
                      
                      const SizedBox(height: 30),
                      _buildSectionTitle("Team Name"),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputStyle("Team Name (e.g. Harvard A)"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle("Speakers"),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _showBulkImportDialog,
                                icon: const Icon(Icons.list_alt_rounded),
                                label: const Text("Bulk"),
                              ),
                              TextButton.icon(
                                onPressed: () => _addSpeakerField(),
                                icon: const Icon(Icons.add),
                                label: const Text("Add"),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _speakerControllers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _speakerControllers[index],
                                  decoration: _inputStyle("Speaker Name"),
                                  // For debate, usually need at least 2 or 3 speakers
                                  validator: (v) => index < 2 && v!.isEmpty ? "Required" : null,
                                ),
                              ),
                              if (_speakerControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                                  onPressed: () => _removeSpeakerField(index),
                                ),
                            ],
                          );
                        },
                      ),

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
                          child: Text(_selectedTeamId == null ? "SAVE TEAM" : "UPDATE ROSTER"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
    );
  }

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _buildSectionTitle(String title) => Text(
    title.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2),
  );
}