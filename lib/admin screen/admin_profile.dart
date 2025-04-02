import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../student screen/delete_account_page.dart';
import '../student screen/login_screen.dart';
import '../student screen/password.dart';
import 'FriendRequestPage.dart';
import 'admin_edit_profile_sheet.dart';
class AdminProfilePage extends StatefulWidget {
  final String? adminId;

  const AdminProfilePage({Key? key, this.adminId}) : super(key: key);

  @override
  _AdminProfilePageState createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  String? _profileImageUrl;
  String _name = "Admin User";
  String _role = "System Administrator";
  String _department = "IT Department";
  String _location = "Head Office";
  String _mobile = "7479519946";
  String _email = "admin@example.com";
  String _joinDate = "01-01-2023";
  String _adminLevel = "Admin";
  String _adminId = "";
  final Map<String, int> _stats = {
    'employees': 0,
    'projects': 12,
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
    _userId = widget.adminId ?? _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      print('No user is currently signed in.');
      // Handle navigation to login student screen if needed
    } else {
      _fetchAdminProfile();
      _fetchSummaryData();
    }
  }

  Future<void> _fetchAdminProfile() async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('teachers').doc(_userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        // Format the createdAt timestamp to "dd-MM-yyyy"
        String formattedJoinDate = "01-01-2023"; // Default value
        if (data['createdAt'] != null) {
          Timestamp createdAt = data['createdAt'] as Timestamp;
          DateTime dateTime = createdAt.toDate();
          formattedJoinDate = DateFormat('dd-MM-yyyy').format(dateTime);
        }

        setState(() {
          _name = data['name'] ?? "Admin User";
          _role = data['role'] ?? "System Administrator";
          _department = data['department'] ?? "IT Department";
          _location = data['location'] ?? "Head Office";
          _mobile = data['mobile'] ?? "7479519946";
          _email = data['email'] ?? "admin@example.com";
          _joinDate = formattedJoinDate; // Use the formatted createdAt
          _adminLevel = data['adminLevel'] ?? "Admin";
          _adminId = "A-" + _userId.substring(0, 6);
          _profileImageUrl = data['profileImageUrl'];
        });
      } else {
        await _firestore.collection('teachers').doc(_userId).set({
          'name': _name,
          'role': _role,
          'department': _department,
          'location': _location,
          'mobile': _mobile,
          'email': _auth.currentUser?.email ?? 'admin@example.com',
          'joinDate': _joinDate,
          'adminLevel': _adminLevel,
          'createdAt': FieldValue.serverTimestamp(),
          'isEmailVerified': _auth.currentUser?.emailVerified ?? false,
          'profileImageUrl': null,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      _showSnackBar('Error fetching admin profile: $e');
    }
  }

  Future<void> _fetchSummaryData() async {
    try {
      QuerySnapshot friendsSnapshot = await _firestore
          .collection('teachers')
          .doc(_userId)
          .collection('friends')
          .get();
      int totalFriends = friendsSnapshot.docs.length;
      print('Total friends fetched: $totalFriends');

      setState(() {
        _stats['employees'] = totalFriends;
      });
    } catch (e) {
      _showSnackBar('Error fetching summary data: $e');
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

      // Pick an image
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
          print('Error deleting old image: $e');
        }
      }

      // Upload the image to Supabase
      await _supabase.storage
          .from('profile_pictures')
          .upload(fileName, imageFile, fileOptions: const FileOptions(upsert: true));

      // Get the public URL of the uploaded image
      final String imageUrl = _supabase.storage.from('profile_pictures').getPublicUrl(fileName);

      // Update Firestore with the image URL
      await _firestore.collection('teachers').doc(_userId).update({
        'profileImageUrl': imageUrl,
      });

      // Update the UI
      setState(() {
        _profileImageUrl = imageUrl;
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

  Future<void> _logout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: Colors.green.shade900,
          ),
        ),
      );
      await FirebaseAuth.instance.signOut();
      Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar('Logged out successfully');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      // Close loading dialog if open
      Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar('Error logging out: $e');
    }
  }

  void _showEditProfileSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
              ),
              child: AdminEditProfileSheet(
                initialName: _name,
                initialRole: _role,
                initialDepartment: _department,
                initialLocation: _location,
                initialMobile: _mobile,
                initialAdminLevel: _adminLevel,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _name = result['name'] ?? _name;
        _role = result['role'] ?? _role;
        _department = result['department'] ?? _department;
        _location = result['location'] ?? _location;
        _mobile = result['mobile'] ?? _mobile;
        _adminLevel = result['adminLevel'] ?? _adminLevel;
      });

      try {
        await _firestore.collection('teachers').doc(_userId).update({
          'name': _name,
          'role': _role,
          'department': _department,
          'location': _location,
          'mobile': _mobile,
          'adminLevel': _adminLevel,
        });
        _showSnackBar('Admin profile updated successfully');
      } catch (e) {
        _showSnackBar('Error updating admin profile: $e');
      }
    }
  }

  // In your AdminProfilePage or wherever you want to trigger the password change
  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => const PasswordChangeSheet(),
    );
  }

  void _viewAuditLogs() {
    _showSnackBar('Audit logs feature will be implemented soon');
  }

  void _navigateToEmployeeList() {
    _showSnackBar('Employee list feature to be implemented');
  }

  @override
  Widget build(BuildContext context) {
    const Color baseColor = Colors.green;
    final Color gradientStart = baseColor;
    final Color gradientEnd = Color.fromRGBO(0, 255, 0, 0.8);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.green.shade900,
        elevation: 0,
        toolbarHeight: 5,
      ),
      body: Column(
        children: [
          _buildProfileHeader(gradientStart, gradientEnd),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildAdminInfoCard(),
                  ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logout,
        backgroundColor: Colors.green.shade900,
        child: const Icon(Icons.logout, color: Colors.white),
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
          colors: [
            const Color(0xFF1B5E20),
            Color.fromRGBO(27, 94, 32, 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
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
                    colors: [
                      Color.fromRGBO(0, 255, 0, 0.9),
                      Color.fromRGBO(0, 255, 0, 0.7),
                    ],
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
                        border: Border.all(color: Colors.white, width: 2),
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage('assets/admin_default.jpg') as ImageProvider,
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
              color: Color.fromRGBO(0, 0, 0, 0.2),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  "ID: $_adminId",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _role,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.1),
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

  Widget _buildAdminInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.apartment, "firm", _department),
          const Divider(height: 16),
          _buildInfoRow(Icons.email, "Email", _email),
          const Divider(height: 16),
          _buildInfoRow(Icons.phone, "Mobile", _mobile),
          const Divider(height: 16),
          _buildInfoRow(Icons.calendar_today, "Join Date", _joinDate),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.right,
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
            color: Color.fromRGBO(0, 0, 0, 0.05),
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
          label: "Edit Profilee",
          onTap: _showEditProfileSheet,
        ),
        const SizedBox(height: 12),
        _buildOptionButton(
          icon: Icons.history,
          label: "View Audit Logs",
          onTap: _viewAuditLogs,
        ),
        const SizedBox(height: 16),
        _buildOptionButton(
          icon: Icons.settings,
          label: "Settings",
          onTap: _changePassword,
        ),
        const SizedBox(height: 16),
        _buildOptionButton(
          icon: Icons.ad_units,
          label: "Add employee",
          onTap: _navigateToEmployeeList,
        ),
        const SizedBox(height: 16),
        _buildOptionButton(
          icon: Icons.delete_forever,
          label: "Delete Account",
          onTap: () async {
            // Navigate to DeleteAccountPage for teacher
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DeleteAccountPage(userType: 'teacher'),
              ),
            );
            if (result == 'delete') {
              // Navigate to login screen or home screen after deletion
              _showSnackBar('Account deleted successfully');
              // Example: Navigate to login screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            }
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
              color: Color.fromRGBO(0, 0, 0, 0.2),
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