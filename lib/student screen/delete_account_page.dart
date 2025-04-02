import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteAccountPage extends StatefulWidget {
  final String userType; // "student" or "teacher"

  const DeleteAccountPage({Key? key, required this.userType}) : super(key: key);

  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  String? _passwordError;
  String? _confirmPasswordError;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _passwordError = _passwordController.text.trim().isEmpty
          ? 'Password cannot be empty'
          : null;
      _confirmPasswordError = _confirmPasswordController.text.trim().isEmpty
          ? 'Confirm password cannot be empty'
          : _confirmPasswordController.text != _passwordController.text
          ? 'Passwords do not match'
          : null;
    });

    return _passwordError == null && _confirmPasswordError == null;
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close confirmation dialog
              _deleteAccount(); // Proceed with deletion
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
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

      // Re-authenticate the user with their password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // Delete the user's Firestore data based on userType
      String userId = user.uid;
      if (widget.userType == 'student') {
        await _firestore.collection('students').doc(userId).delete();
      } else if (widget.userType == 'teacher') {
        // Delete the teacher's data
        await _firestore.collection('teachers').doc(userId).delete();
        // Optionally, delete the teacher's subcollections (e.g., friends)
        await _firestore
            .collection('teachers')
            .doc(userId)
            .collection('friends')
            .get()
            .then((snapshot) {
          for (DocumentSnapshot doc in snapshot.docs) {
            doc.reference.delete();
          }
        });
      } else {
        throw Exception('Invalid user type: ${widget.userType}');
      }

      // Delete the user account from Firebase Authentication
      await user.delete();

      // Return 'delete' to indicate success
      Navigator.pop(context, 'delete');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Password is incorrect.';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again to delete your account.';
          break;
        default:
          errorMessage = 'Error deleting account: ${e.message}';
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
          'Delete Account',
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
                      'Confirm Account Deletion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'To delete your account, please enter your password twice to confirm.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      errorText: _passwordError,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      errorText: _confirmPasswordError,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showDeleteConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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