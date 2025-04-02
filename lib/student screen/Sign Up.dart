import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum UserType { student, teacher }

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserType _selectedUserType = UserType.student;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _register() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      String collectionName =
          _selectedUserType == UserType.student ? 'students' : 'teachers';

      await _firestore.collection(collectionName).doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': _selectedUserType == UserType.student ? 'student' : 'teacher',
      });

      await userCredential.user!.sendEmailVerification();

      _showSnackBar('Registration successful! Please verify your email.');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _handleRegistrationError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateInputs() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _mobileController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return false;
    }
    return true;
  }

  void _handleRegistrationError(FirebaseAuthException e) {
    String errorMessage = _getErrorMessage(e);
    _showSnackBar(errorMessage);
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBackground(),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[900]!,
            Colors.green[600]!,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildSignUpContainer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Sign up to get started',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7 * 255),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2 * 255),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              LucideIcons.userPlus,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUserTypeToggle(),
              const SizedBox(height: 30),
              _buildNameTextField(),
              const SizedBox(height: 20),
              _buildEmailTextField(),
              const SizedBox(height: 20),
              _buildMobileTextField(),
              const SizedBox(height: 20),
              _buildPasswordTextField(),
              const SizedBox(height: 30),
              _buildRegisterButton(),
              const SizedBox(height: 20),
              _buildSocialLoginSection(),
              const SizedBox(height: 20),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeToggle() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUserTypeChip(UserType.student, 'Student'),
            _buildUserTypeChip(UserType.teacher, 'Teacher'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeChip(UserType type, String label) {
    bool isSelected = _selectedUserType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    IconButton? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.green[800]),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: Colors.grey),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.white),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildNameTextField() {
    return _buildTextField(
      controller: _nameController,
      labelText: 'Full Name',
      hintText: 'Enter your full name',
      prefixIcon: LucideIcons.user,
    );
  }

  Widget _buildEmailTextField() {
    return _buildTextField(
      controller: _emailController,
      labelText: 'Email Address',
      hintText: 'Enter your email',
      prefixIcon: LucideIcons.mail,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildMobileTextField() {
    return _buildTextField(
      controller: _mobileController,
      labelText: 'Mobile Number',
      hintText: 'Enter your mobile number',
      prefixIcon: LucideIcons.phone,
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildPasswordTextField() {
    return _buildTextField(
      controller: _passwordController,
      labelText: 'Password',
      hintText: 'Enter your password',
      prefixIcon: LucideIcons.lock,
      obscureText: !_isPasswordVisible,
      suffixIcon: IconButton(
        icon: Icon(
          _isPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff,
          color: Colors.black,
        ),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _register,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 5,
      ),
      child: _isLoading
          ? CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            )
          : Text(
              'REGISTER',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
    );
  }

  Widget _buildSocialLoginSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.green[900])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  color: Colors.green[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.green[200])),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(LucideIcons.facebook, Colors.blue, () {}),
            const SizedBox(width: 20),
            _buildSocialButton(LucideIcons.github, Colors.black, () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(
      IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: CircleBorder(),
        padding: const EdgeInsets.all(15),
        elevation: 5,
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.green[900]),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Text(
            'Login',
            style: TextStyle(
              color: Colors.green.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
