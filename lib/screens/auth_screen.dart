import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/health_check_service.dart'; // New Import

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  // State variables
  bool isLoginMode = true;
  String email = '';
  String password = '';
  String error = '';
  bool loading = false;
  bool checkingHealth = false; // For health check status

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      // --- ADDED APPBAR FOR HEALTH CHECK ---
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.health_and_safety_outlined, 
              color: checkingHealth ? const Color(0xFF46C3D7) : Colors.grey.withOpacity(0.5)
            ),
            tooltip: 'System Health Check',
            onPressed: checkingHealth ? null : _runSystemCheck,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel_rounded, size: 80, color: Color(0xFF46C3D7)),
                  const SizedBox(height: 15),
                  const Text(
                    "DebateFlow",
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF2264D7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    "Tournament Management Simplified",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 50),

                  _buildTextField(
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    onChanged: (val) => setState(() => email = val),
                    validator: (val) => val!.isEmpty ? 'Please enter an email' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    onChanged: (val) => setState(() => password = val),
                    validator: (val) => val!.length < 6 ? 'Min. 6 characters required' : null,
                  ),
                  const SizedBox(height: 35),

                  if (loading)
                    const CircularProgressIndicator(color: Color(0xFF2264D7))
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2264D7),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _handleAuth,
                      child: Text(
                        isLoginMode ? 'Login' : 'Create Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () => setState(() {
                      isLoginMode = !isLoginMode;
                      error = '';
                    }),
                    child: Text(
                      isLoginMode 
                        ? "Don't have an account? Sign Up" 
                        : "Already have an account? Log In",
                      style: const TextStyle(color: Color(0xFF2264D7), fontWeight: FontWeight.w600),
                    ),
                  ),

                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          error, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HEALTH CHECK LOGIC ---
  void _runSystemCheck() async {
    setState(() => checkingHealth = true);
    bool isHealthy = await HealthCheckService.performCheck();
    
    if (mounted) {
      setState(() => checkingHealth = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isHealthy ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 10),
              Text(isHealthy ? "Firebase Connection Stable" : "Connection Failed: Check JSON/Rules"),
            ],
          ),
          backgroundColor: isHealthy ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildTextField({
    required String label, 
    required IconData icon, 
    bool isPassword = false,
    required Function(String) onChanged,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2264D7), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  void _handleAuth() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        loading = true;
        error = '';
      });
      
      dynamic result = isLoginMode 
        ? await _auth.loginWithEmail(email, password)
        : await _auth.registerWithEmail(email, password);
      
      if (result == null) {
        setState(() {
          error = 'Authentication failed. Please check your details.';
          loading = false;
        });
      }
    }
  }
}