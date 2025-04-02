import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'delete_account_page.dart'; // Import the new page

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _currentPasswordError = _currentPasswordController.text.trim().isEmpty
          ? 'Current password cannot be empty'
          : null;
      _newPasswordError = _newPasswordController.text.trim().isEmpty
          ? 'New password cannot be empty'
          : _newPasswordController.text.length < 6
          ? 'New password must be at least 6 characters'
          : null;
      _confirmPasswordError = _confirmPasswordController.text.trim().isEmpty
          ? 'Confirm password cannot be empty'
          : _confirmPasswordController.text != _newPasswordController.text
          ? 'Passwords do not match'
          : null;
    });

    return _currentPasswordError == null &&
        _newPasswordError == null &&
        _confirmPasswordError == null;
  }

  Future<void> _updatePassword() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently signed in.',
        );
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(_newPasswordController.text.trim());

      Navigator.pop(context, 'update');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect.';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak.';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again to update your password.';
          break;
        default:
          errorMessage = 'Error updating password: ${e.message}';
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDeleteAccountPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeleteAccountPage(userType: 'student',)),
    );

    if (result == 'delete') {
      Navigator.pop(context, 'delete'); // Pass 'delete' back to ModernProfilePage
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      errorText: _currentPasswordError,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      icon: Icons.lock_open,
                      obscureText: true,
                      errorText: _newPasswordError,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      errorText: _confirmPasswordError,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Update Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _isLoading ? null : _navigateToDeleteAccountPage,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Delete Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          errorText: errorText,
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
    );
  }
}