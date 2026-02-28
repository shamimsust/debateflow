import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/motion_service.dart';

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
    
    // Saves to Firebase but keeps 'is_released' as false
    await context.read<MotionService>().setMotion(
      tId: widget.tournamentId,
      round: _selectedRound,
      motionText: _motionController.text.trim(),
      infoSlide: _infoController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Motion for Round $_selectedRound Saved (Draft)"))
      );
    }
  }

  void _handleRelease() async {
    if (_motionController.text.isEmpty) {
      _showError("Cannot release an empty motion.");
      return;
    }

    // Confirmation Dialog
    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("RELEASE MOTION?"),
        content: Text("This will reveal the Round $_selectedRound motion to ALL participants immediately. This cannot be undone."),
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
      // First save it to ensure the text is current
      await context.read<MotionService>().setMotion(
        tId: widget.tournamentId,
        round: _selectedRound,
        motionText: _motionController.text.trim(),
        infoSlide: _infoController.text.trim(),
      );
      
      // Then trigger the release_time and is_released flag
      await context.read<MotionService>().releaseMotion(widget.tournamentId, _selectedRound);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("MOTION IS NOW LIVE!"))
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ROUND SELECTION", 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 8),
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
                  onChanged: (v) => setState(() => _selectedRound = v!),
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
              decoration: _inputStyle("e.g., THBT we should abolish standardized testing."),
            ),
            
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleSave,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: Color(0xFF1E293B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("SAVE DRAFT", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("RELEASE NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Warning: Releasing will notify all users and start prep timers.",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
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
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey, letterSpacing: 1.2)),
    );
  }
}