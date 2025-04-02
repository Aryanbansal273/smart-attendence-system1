import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../student screen/login_screen.dart';
class FriendRequestPage extends StatefulWidget {
  const FriendRequestPage({super.key});

  @override
  _FriendRequestPageState createState() => _FriendRequestPageState();
}

class _FriendRequestPageState extends State<FriendRequestPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _currentUserId;
  String _currentUserName = "Unknown";
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<String> _friendIds = []; // Store friend IDs to filter out

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    if (_currentUserId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      });
    } else {
      _initializeUserData();
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    await _fetchCurrentUserData();
    await _fetchFriendIds(); // Fetch friend IDs after user data
  }

  Future<void> _fetchCurrentUserData() async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('teachers').doc(_currentUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data['name'] != null && data['name'].isNotEmpty) {
          setState(() {
            _currentUserName = data['name'];
            _isLoading = false;
          });
        } else {
          _showSnackBar('Teacher data is incomplete');
          setState(() => _isLoading = false);
        }
      } else {
        await _firestore.collection('teachers').doc(_currentUserId).set({
          'name': _auth.currentUser?.displayName ?? _currentUserName,
          'email': _auth.currentUser?.email ?? 'unknown',
          'role': 'teacher',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        setState(() {
          _currentUserName = _auth.currentUser?.displayName ?? _currentUserName;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error fetching teacher data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFriendIds() async {
    try {
      QuerySnapshot friendsSnapshot = await _firestore
          .collection('teachers')
          .doc(_currentUserId)
          .collection('friends')
          .get();
      setState(() {
        _friendIds = friendsSnapshot.docs.map((doc) => doc['friendId'] as String).toList();
      });
    } catch (e) {
      _showSnackBar('Error fetching friends: $e');
    }
  }

  Future<void> _sendFriendRequest(String receiverId, String receiverName) async {
    if (_currentUserName == "Unknown") {
      _showSnackBar('Cannot send request: Your name is not set');
      return;
    }

    try {
      DocumentSnapshot requestDoc = await _firestore
          .collection('students')
          .doc(receiverId)
          .collection('friend_requests')
          .doc(_currentUserId)
          .get();

      DocumentSnapshot friendDoc = await _firestore
          .collection('teachers')
          .doc(_currentUserId)
          .collection('friends')
          .doc(receiverId)
          .get();

      if (requestDoc.exists) {
        _showSnackBar('Friend request already sent to $receiverName');
        return;
      }
      if (friendDoc.exists) {
        _showSnackBar('$receiverName is already your friend');
        return;
      }

      await _firestore.collection('students').doc(receiverId).collection('friend_requests').doc(_currentUserId).set({
        'senderId': _currentUserId,
        'senderName': _currentUserName,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Friend request sent to $receiverName');
    } catch (e) {
      _showSnackBar('Error sending friend request: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      _showSnackBar('Logged out successfully');
    } catch (e) {
      _showSnackBar('Error logging out: $e');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friends'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Students',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('students').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No students found'));
                  }

                  final students = snapshot.data!.docs.where((doc) {
                    final studentData = doc.data() as Map<String, dynamic>;
                    final studentId = doc.id;
                    final studentName = (studentData['name'] ?? '').toString().toLowerCase();
                    final studentEmail = (studentData['email'] ?? '').toString().toLowerCase();

                    // Exclude current user, existing friends, and filter by search query
                    return studentId != _currentUserId &&
                        !_friendIds.contains(studentId) &&
                        (_searchQuery.isEmpty ||
                            studentName.contains(_searchQuery) ||
                            studentEmail.contains(_searchQuery));
                  }).toList();

                  if (students.isEmpty) {
                    return const Center(child: Text('No matching students found'));
                  }

                  return ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final studentData = students[index].data() as Map<String, dynamic>;
                      final studentId = students[index].id;
                      final studentName = studentData['name'] ?? 'Unknown';
                      final studentEmail = studentData['email'] ?? 'No email';

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: studentData['profileImageUrl'] != null
                                ? NetworkImage(studentData['profileImageUrl'])
                                : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                          ),
                          title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(studentEmail),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add, color: Colors.teal),
                            onPressed: () => _sendFriendRequest(studentId, studentName),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}