import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateTournamentScreen extends StatefulWidget {
  final String uid; // The authenticated user's ID
  const CreateTournamentScreen({super.key, required this.uid});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  
  // Options aligned with your ResultCalculator and StandingsService logic
  final List<String> _formats = [
    'WSDC (3 vs 3)', 
    'British Parliamentary (BP)', 
    'Asian Parliamentary (AP)'
  ];
  
  String _selectedFormat = 'WSDC (3 vs 3)';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to today's date for convenience
    _dateController.text = DateTime.now().toString().split(' ')[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// Maps the UI dropdown string to the shorthand logic used in our Services
  String _mapFormatToRule(String format) {
    if (format.contains("BP")) return "BP";
    if (format.contains("Asian")) return "AP";
    return "WSDC";
  }

  Future<void> _createTournament() async {
    final String name = _nameController.text.trim();
    
    if (name.isEmpty) {
      _showError("Please enter a tournament name");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseDatabase.instance.ref();
      
      // 1. Generate a globally unique ID for the tournament
      final tournamentRef = db.child('tournaments').push();
      final String tId = tournamentRef.key!;
      final String ruleSystem = _mapFormatToRule(_selectedFormat);

      // 2. Prepare Data Structure for the Dashboard and Pairings
      final tournamentData = {
        'adminUid': widget.uid,
        'name': name,
        'rule': ruleSystem, // The "Pipe" for BallotScreen/Standings
        'date': _dateController.text,
        'status': 'Setup',
        'currentRound': 1,
        'createdAt': ServerValue.timestamp,
      };

      // 3. Prepare Settings for the Validation Engine
      final settingsData = {
        'formatName': _selectedFormat,
        'minMarks': ruleSystem == "WSDC" ? 60.0 : 50.0,
        'maxMarks': ruleSystem == "WSDC" ? 80.0 : 100.0,
        'isLocked': false,
      };

      // 4. Multi-path Atomic Write
      // This ensures all nodes are created at once or not at all
      await Future.wait([
        db.child('tournaments/$tId').set(tournamentData),
        db.child('settings/$tId').set(settingsData),
        // Link to the user's personal list for the Lobby/Home view
        db.child('users/${widget.uid}/my_tournaments/$tId').set(true),
      ]);

      if (mounted) {
        Navigator.pop(context); // Return to Lobby
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tournament Initialized Successfully!"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Database Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("New Tournament"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 30),
            
            _buildLabel("Tournament Name"),
            _buildTextField("e.g. World Schools 2026", _nameController, Icons.emoji_events_outlined),
            const SizedBox(height: 25),
            
            _buildLabel("Debate Format"),
            _buildDropdown(),
            const SizedBox(height: 25),
            
            _buildLabel("Start Date"),
            _buildDatePicker(),
            const SizedBox(height: 50),

            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Create a New Circuit", 
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text("Set the rules and format for your tournament node on the SEA-1 Singapore cluster.", 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(), 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF2264D7)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedFormat,
        items: _formats.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
        onChanged: (val) => setState(() => _selectedFormat = val!),
        decoration: const InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.gavel_rounded, color: Color(0xFF2264D7)),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return TextField(
      controller: _dateController,
      readOnly: true,
      onTap: _selectDate,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: "Select Date",
        prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF2264D7)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2264D7))), child: child!);
      },
    );
    if (picked != null) setState(() => _dateController.text = picked.toString().split(' ')[0]);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createTournament,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2264D7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("INITIALIZE TOURNAMENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), 
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }
}