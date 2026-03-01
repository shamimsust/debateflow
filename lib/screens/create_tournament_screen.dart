import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateTournamentScreen extends StatefulWidget {
  final String uid; // The authenticated user's ID (Admin)
  const CreateTournamentScreen({super.key, required this.uid});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  
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
      final String? tId = db.child('tournaments').push().key;
      if (tId == null) throw Exception("Could not generate tournament ID");

      final String ruleSystem = _mapFormatToRule(_selectedFormat);

      // 2. Prepare Global Tournament Data
      final tournamentData = {
        'tId': tId,
        'adminUid': widget.uid, // 🔑 Crucial for Security Rules
        'name': name,
        'rule': ruleSystem,
        'date': _dateController.text,
        'status': 'Setup',
        'currentRound': "1", // Saved as String to match your Reveal logic
        'createdAt': ServerValue.timestamp,
      };

      // 3. Prepare Format-Specific Settings
      final settingsData = {
        'formatName': _selectedFormat,
        'minMarks': ruleSystem == "WSDC" ? 60.0 : 50.0,
        'maxMarks': ruleSystem == "WSDC" ? 80.0 : 100.0,
        'isLocked': false,
      };

      // 4. MULTI-PATH ATOMIC UPDATE
      // This writes to the Global "tournaments" folder (visible to everyone)
      // AND the private user "my_tournaments" folder simultaneously.
      Map<String, dynamic> updates = {};
      
      // Node 1: Global List (For all users to see)
      updates['tournaments/$tId'] = tournamentData;
      
      // Node 2: Tournament Settings
      updates['settings/$tId'] = settingsData;
      
      // Node 3: User Shortcut (To filter "My Tournaments")
      updates['users/${widget.uid}/my_tournaments/$tId'] = true;

      await db.update(updates);

      if (mounted) {
        Navigator.pop(context); // Return to Tournament List
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tournament Initialized on SEA-1!"), 
            backgroundColor: Color(0xFF2264D7),
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
        title: const Text("New Tournament", style: TextStyle(fontWeight: FontWeight.bold)),
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
            _buildTextField("e.g. Asia Pacific Debating 2026", _nameController, Icons.emoji_events_outlined),
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

  // --- UI COMPONENTS ---

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Launch a New Circuit", 
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text("Your tournament will be hosted globally and visible to all participants.", 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(), 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF2264D7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedFormat,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: _dateController,
        readOnly: true,
        onTap: _selectDate,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: "Select Date",
          prefixIcon: Icon(Icons.calendar_today_outlined, color: Color(0xFF2264D7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dateController.text = picked.toString().split(' ')[0]);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createTournament,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2264D7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
          shadowColor: const Color(0xFF2264D7).withOpacity(0.4),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("INITIALIZE TOURNAMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
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