import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartt_attendance/student%20screen/settingsheet.dart';
import 'dart:io';
import 'leave.dart';
import 'login_screen.dart';
import 'edit_profile_sheet.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification.dart'; // For Supabase integration

class ModernProfilePage extends StatefulWidget {
  const ModernProfilePage({super.key});

  @override
  _ModernProfilePageState createState() => _ModernProfilePageState();
}

class _ModernProfilePageState extends State<ModernProfilePage> {
  File? _profileImage;
  String? _profileImageUrl; // To store the image URL from Firestore
  String _name = "Aryan Bansal";
  String _job = "Flutter Developer";
  String _location = "Chandigarh";
  String _mobile = "7479519946";
  final Map<String, int> _stats = {
    'Projects': 12,
    'Attended': 25,
    'Leaves': 2,
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      if (kDebugMode) {
        print('No user is currently signed in.');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      _fetchUserProfile();
      _fetchAttendanceStats();
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('students').doc(_userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _name = data['name'] ?? "Aryan Bansal";
          _job = data['job'] ?? "Flutter Developer";
          _location = data['location'] ?? "Chandigarh";
          _mobile = data['mobile'] ?? "7479519946";
          _stats['Projects'] = data['projects'] ?? 12;
          _profileImageUrl = data['profileImageUrl'];
        });
      } else {
        await _firestore.collection('students').doc(_userId).set({
          'name': _name,
          'job': _job,
          'location': _location,
          'mobile': _mobile,
          'projects': _stats['Projects'],
          'createdAt': FieldValue.serverTimestamp(),
          'email': _auth.currentUser?.email ?? 'unknown',
          'isEmailVerified': _auth.currentUser?.emailVerified ?? false,
          'role': 'student',
          'profileImageUrl': null,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      _showSnackBar('Error fetching profile: $e');
    }
  }

  Future<void> _fetchAttendanceStats() async {
    try {
      DateTime now = DateTime.now();
      final snapshot = await _firestore
          .collection('students')
          .doc(_userId)
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1))
          .where('date', isLessThan: DateTime(now.year, now.month + 1, 1))
          .get();

      int attendedDays = snapshot.docs.length;

      int totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
      int workingDays = 0;
      for (int day = 1; day <= totalDaysInMonth; day++) {
        DateTime date = DateTime(now.year, now.month, day);
        if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
          workingDays++;
        }
      }

      int leaves = workingDays - attendedDays;
      if (leaves < 0) leaves = 0;

      setState(() {
        _stats['Attended'] = attendedDays;
        _stats['Leaves'] = leaves;
      });
    } catch (e) {
      _showSnackBar('Error fetching attendance stats: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Show a dialog to choose between gallery and camera
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Camera'),
            ),
          ],
        ),
      );

      if (source == null) return; // User canceled the dialog

      // Pick an image using the non-deprecated API
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Reduce image quality to decrease file size
      );

      if (pickedFile == null) return; // User canceled the picker

      setState(() {
        _isUploading = true;
      });

      // Create a unique file name using the user ID and timestamp
      String fileName = '$_userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      File imageFile = File(pickedFile.path);

      // Delete the old image from Supabase if it exists
      if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
        String oldFileName = _profileImageUrl!.split('/').last;
        try {
          await _supabase.storage.from('profile_pictures').remove([oldFileName]);
        } catch (e) {
          if (kDebugMode) {
            print('Error deleting old image: $e');
          }
        }
      }

      // Upload the image to Supabase
      final String path = await _supabase.storage
          .from('profile_pictures')
          .upload(fileName, imageFile, fileOptions: const FileOptions(upsert: true));

      // Get the public URL of the uploaded image
      final String imageUrl = _supabase.storage.from('profile_pictures').getPublicUrl(fileName);

      // Update Firestore with the image URL
      await _firestore.collection('students').doc(_userId).update({
        'profileImageUrl': imageUrl,
      });

      // Update the UI
      setState(() {
        _profileImageUrl = imageUrl;
        _profileImage = imageFile; // For local preview before URL fetch
      });

      _showSnackBar('Profile picture updated successfully');
    } catch (e) {
      _showSnackBar('Error uploading image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

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

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      _showSnackBar('Logged out successfully');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showSnackBar('Error logging out: $e');
    }
  }

  void _showEditProfileSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
              ),
              child: EditProfileSheet(
                initialName: _name,
                initialJob: _job,
                initialLocation: _location,
                initialProjects: _stats['Projects']!,
                initialMobile: _mobile,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _name = result['name'];
        _job = result['job'];
        _location = result['location'];
        _mobile = result['mobile'];
        _stats['Projects'] = result['projects'];
      });

      try {
        await _firestore.collection('students').doc(_userId).update({
          'name': _name,
          'job': _job,
          'location': _location,
          'mobile': _mobile,
          'projects': _stats['Projects'],
        });
        _showSnackBar('Profile updated successfully');
      } catch (e) {
        _showSnackBar('Error updating profile: $e');
      }
    }
  }
  void _navigateToleavePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LeaveApplicationPage()),
    );

    if (result == 'update') {
      _showSnackBar('Password updated successfully');
    } else if (result == 'delete') {
      try {
        _showSnackBar('Account deleted successfully');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      } catch (e) {
        _showSnackBar('Error deleting account: $e');
      }
    }
  }

  void _navigateToSettingsPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    if (result == 'update') {
      _showSnackBar('Password updated successfully');
    } else if (result == 'delete') {
      try {
        _showSnackBar('Account deleted successfully');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      } catch (e) {
        _showSnackBar('Error deleting account: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color baseColor = Color(0xFF1B5E20);
    final Color gradientStart = baseColor;
    final Color gradientEnd = baseColor.withOpacity(0.8);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: baseColor,
        elevation: 0,
        toolbarHeight: 5,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(gradientStart, gradientEnd),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildUserStatsRow(),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildOptionsCard(baseColor),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logout,
        backgroundColor: baseColor,
        child: const Icon(Icons.logout),
      ),
    );
  }

  Widget _buildProfileHeader(Color gradientStart, Color gradientEnd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [gradientStart.withOpacity(0.9), gradientEnd.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Hero(
                tag: 'profile-image',
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage('assets/12.jpg') as ImageProvider,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: _isUploading
                            ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        )
                            : const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _job,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  _location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsRow() {
    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _stats.entries
            .map(
              (entry) => Expanded(
            child: Column(
              children: [
                Text(
                  entry.value.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildOptionsCard(Color baseColor) {
    return Column(
      children: [
        _buildOptionButton(
          icon: Icons.edit,
          label: "Edit Profile",
          onTap: _showEditProfileSheet,
        ),
        const SizedBox(height: 16),
        _buildOptionButton(
          icon: Icons.settings,
          label: "Settings",
          onTap: _navigateToSettingsPage,
        ),
        const SizedBox(height: 16),
        _buildOptionButton(
          icon: Icons.leave_bags_at_home,
          label: "leave application",
          onTap: _navigateToleavePage,
        ),
        const SizedBox(height: 16),
        _buildOptionButton(
          icon: Icons.person_add,
          label: "Connect Friends",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FriendRequestAcceptPage()),
            );
          },
        ),

      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}