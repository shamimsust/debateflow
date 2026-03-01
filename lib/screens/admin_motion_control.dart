import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart'; // Needed for direct fetch
import '../services/motion_service.dart';
import 'motion_reveal_screen.dart'; // Ensure this import exists

class AdminMotionControl extends StatefulWidget {
  final String tournamentId;
  const AdminMotionControl({super.key, required this.tournamentId});

  @override
  State<AdminMotionControl> createState() => _AdminMotionControlState();
}

class _AdminMotionControlState extends State<AdminMotionControl> {
  final _motionController = TextEditingController();
  final _infoController = TextEditingController();
  String _selectedRound = "1";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData(); // Load data for Round 1 on startup
  }

  // 🛠️ FIX: Fetch data when switching rounds so you don't overwrite Round 2 with Round 1 text
  void _loadExistingData() async {
    setState(() => _isLoading = true);
    
    final cleanRound = _selectedRound.toLowerCase().replaceAll(' ', '_');
    final ref = FirebaseDatabase.instance
        .ref('motions/${widget.tournamentId}/round_$cleanRound');

    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      _motionController.text = data['text'] ?? "";
      _infoController.text = data['info_slide'] ?? "";
    } else {
      _motionController.clear();
      _infoController.clear();
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _motionController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_motionController.text.isEmpty) {
      _showError("Please enter a motion first.");
      return;
    }
    
    await context.read<MotionService>().setMotion(
      tId: widget.tournamentId,
      round: _selectedRound,
      motionText: _motionController.text.trim(),
      infoSlide: _infoController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Motion for Round $_selectedRound Saved"))
      );
    }
  }

  void _handleRelease() async {
    if (_motionController.text.isEmpty) {
      _showError("Cannot release an empty motion.");
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("RELEASE MOTION?"),
        content: Text("Reveal Round $_selectedRound motion to ALL participants?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("RELEASE NOW"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      // 1. Save current text to ensure the release contains the latest edits
      await context.read<MotionService>().setMotion(
        tId: widget.tournamentId,
        round: _selectedRound,
        motionText: _motionController.text.trim(),
        infoSlide: _infoController.text.trim(),
      );
      
      // 2. Set is_released to true
      await context.read<MotionService>().releaseMotion(widget.tournamentId, _selectedRound);
      
      if (mounted) {
        // 3. 🚀 THE REDIRECT FIX: Navigate to the reveal page with the CORRECT round
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MotionRevealScreen(
              tournamentId: widget.tournamentId, 
              round: _selectedRound, // Passes "1", "2", etc.
            ),
          ),
        );
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(msg))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Chief Adjudicator Panel"),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("ROUND SELECTION"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRound,
                  isExpanded: true,
                  items: ["1", "2", "3", "4", "5", "Semi-Final", "Grand Final"]
                      .map((r) => DropdownMenuItem(value: r, child: Text("Round $r")))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedRound = v!);
                    _loadExistingData(); // 🔥 Update text fields when round changes
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            _buildLabel("INFORMATION SLIDE (OPTIONAL)"),
            TextField(
              controller: _infoController,
              maxLines: 3,
              decoration: _inputStyle("Add definitions or context here..."),
            ),
            
            const SizedBox(height: 30),
            _buildLabel("MOTION TEXT"),
            TextField(
              controller: _motionController,
              maxLines: 6,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
              decoration: _inputStyle("Enter motion..."),
            ),
            
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleSave,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("SAVE DRAFT"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleRelease,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("RELEASE NOW"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey)),
    );
  }
}