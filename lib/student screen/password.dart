import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordChangeSheet extends StatefulWidget {
  const PasswordChangeSheet({Key? key}) : super(key: key);

  @override
  _PasswordChangeSheetState createState() => _PasswordChangeSheetState();
}

class _PasswordChangeSheetState extends State<PasswordChangeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isObscureCurrentPassword = true;
  bool _isObscureNewPassword = true;
  bool _isObscureConfirmPassword = true;
  bool _isLoading = false;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the current user
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnackBar('No user is currently signed in');
        return;
      }

      // Re-authenticate the user
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text.trim());

      _showSnackBar('Password changed successfully');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak';
          break;
        default:
          errorMessage = e.message ?? 'An unknown error occurred';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('Error changing password: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Stack(
          children: [
            // Blurred background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Change Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Current Password Field
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _isObscureCurrentPassword,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _isObscureCurrentPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscureCurrentPassword = !_isObscureCurrentPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your current password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // New Password Field
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _isObscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _isObscureNewPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscureNewPassword = !_isObscureNewPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a new password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _isObscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _isObscureConfirmPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscureConfirmPassword = !_isObscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Change Password Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade900,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cancel Button
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}