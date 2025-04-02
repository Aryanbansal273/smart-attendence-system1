import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartt_attendance/admin_bottom_nav.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bottom_navigation_bar.dart';
import 'Sign Up.dart';

enum UserType { student, teacher }

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  UserType _selectedUserType = UserType.student;
  bool _isPasswordVisible = false;
  bool _hasFaceId = false;

  @override
  void initState() {
    super.initState();
    _checkFaceIdStatus();
  }

  Future<void> _checkFaceIdStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUserEmail = prefs.getString('last_user_email');
    final lastUserType = prefs.getString('last_user_type');
    final hasFaceId = lastUserEmail != null
        ? prefs.getBool('has_face_id_$lastUserEmail') ?? false
        : false;

    setState(() {
      _hasFaceId = hasFaceId;
      if (lastUserEmail != null) _emailController.text = lastUserEmail;
      if (lastUserType != null) {
        _selectedUserType = lastUserType == 'student' ? UserType.student : UserType.teacher;
      }
    });
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      await _performFirebaseLogin();
      if (!_hasFaceId) {
        await _promptForFaceIdSetup();
      }
    } on FirebaseAuthException catch (e) {
      _handleLoginError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateInputs() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return false;
    }
    return true;
  }

  Future<void> _performFirebaseLogin() async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    String collectionName = _selectedUserType == UserType.student ? 'students' : 'teachers';
    DocumentSnapshot userDoc = await _firestore.collection(collectionName).doc(userCredential.user!.uid).get();

    if (userDoc.exists) {
      if (userCredential.user!.emailVerified) {
        await _saveLoginDetails(userCredential.user!.email!);
        _showSnackBar('Login successful!');
        _navigateBasedOnUserType();
      } else {
        _showEmailVerificationSnackBar(userCredential.user!);
      }
    } else {
      _showSnackBar('User data not found. Please register as a Student or Teacher.');
    }
  }

  Future<void> _promptForFaceIdSetup() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();

    if (!canCheckBiometrics || !isDeviceSupported) {
      _showSnackBar('Face recognition not available on this device');
      return;
    }

    bool? shouldSetupFaceId = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Face ID'),
        content: const Text('Would you like to set up Face ID for future logins?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldSetupFaceId == true) {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to set up Face ID',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_face_id_${_emailController.text}', true);
        setState(() => _hasFaceId = true);
        _showSnackBar('Face ID setup successful!');
      } else {
        _showSnackBar('Face ID setup failed');
      }
    }
  }

  Future<void> _saveLoginDetails(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_email', email);
    await prefs.setString('last_user_type', _selectedUserType == UserType.student ? 'student' : 'teacher');
    final hasFaceId = prefs.getBool('has_face_id_$email') ?? false;
    setState(() => _hasFaceId = hasFaceId);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    await _checkFaceIdStatus();
  }

  void _navigateBasedOnUserType() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _selectedUserType == UserType.student
            ? const HomeScreen()
            : AdminBottomNav(),
      ),
    );
  }

  void _showEmailVerificationSnackBar(User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please verify your email first'),
        action: SnackBarAction(
          label: 'Resend',
          onPressed: () async => await user.sendEmailVerification(),
        ),
      ),
    );
  }

  void _handleLoginError(FirebaseAuthException e) {
    String errorMessage = _getErrorMessage(e);
    _showSnackBar(errorMessage);
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      default:
        return 'An error occurred: ${e.message}';
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
              child: _buildLoginContainer(),
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
                'Welcome Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Sign in to continue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              LucideIcons.fingerprint,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginContainer() {
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
              _buildEmailTextField(),
              const SizedBox(height: 20),
              _buildPasswordTextField(),
              const SizedBox(height: 20),
              _buildForgotPasswordLink(),
              const SizedBox(height: 30),
              _buildLoginButton(),
              const SizedBox(height: 30),
              _buildSocialLoginSection(),
              const SizedBox(height: 20),
              _buildRegisterLink(),
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
          color: Colors.grey.shade50,
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

  Widget _buildEmailTextField() {
    return _buildTextField(
      controller: _emailController,
      labelText: 'Email Address',
      hintText: 'Enter your email',
      prefixIcon: LucideIcons.mail,
      keyboardType: TextInputType.emailAddress,
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
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: Colors.black),
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
            borderSide: BorderSide(color: Colors.grey, width: 1),
          ),
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.black),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _login,
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
        'LOGIN',
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
            Expanded(child: Divider(color: Colors.green[200])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  color: Colors.black,
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

  Widget _buildSocialButton(IconData icon, Color color, VoidCallback onPressed) {
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

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: TextStyle(color: Colors.black),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUp()),
            );
          },
          child: Text(
            'Register Now',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}