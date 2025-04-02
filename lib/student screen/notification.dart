import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
class FriendRequestAcceptPage extends StatefulWidget {
  const FriendRequestAcceptPage({super.key});

  @override
  _FriendRequestAcceptPageState createState() => _FriendRequestAcceptPageState();
}

class _FriendRequestAcceptPageState extends State<FriendRequestAcceptPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    if (_currentUserId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptFriendRequest(String senderId, String senderName) async {
    try {
      // Add sender (teacher) to current user's (student's) friends list
      await _firestore.collection('students').doc(_currentUserId).collection('friends').doc(senderId).set({
        'friendId': senderId,
        'friendName': senderName,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Fetch current user's (student's) name
      DocumentSnapshot currentUserDoc = await _firestore.collection('students').doc(_currentUserId).get();
      String currentUserName = (currentUserDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';

      // Add current user (student) to sender's (teacher's) friends list
      await _firestore.collection('teachers').doc(senderId).collection('friends').doc(_currentUserId).set({
        'friendId': _currentUserId,
        'friendName': currentUserName,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Remove the friend request after acceptance
      await _firestore
          .collection('students')
          .doc(_currentUserId)
          .collection('friend_requests')
          .doc(senderId)
          .delete();

      _showSnackBar('Friend request from $senderName accepted');
    } catch (e) {
      _showSnackBar('Error accepting friend request: $e');
    }
  }

  Future<void> _rejectFriendRequest(String senderId, String senderName) async {
    try {
      // Simply delete the friend request
      await _firestore
          .collection('students')
          .doc(_currentUserId)
          .collection('friend_requests')
          .doc(senderId)
          .delete();

      _showSnackBar('Friend request from $senderName rejected');
    } catch (e) {
      _showSnackBar('Error rejecting friend request: $e');
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
        title: const Text('Friend Requests'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Requests',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('students')
                    .doc(_currentUserId)
                    .collection('friend_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No pending friend requests'));
                  }

                  final requests = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestData = requests[index].data() as Map<String, dynamic>;
                      final senderId = requestData['senderId'] ?? '';
                      final senderName = requestData['senderName'] ?? 'Unknown';

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundImage: AssetImage('assets/default_avatar.jpg'), // Placeholder image
                          ),
                          title: Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Wants to be your friend'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => _acceptFriendRequest(senderId, senderName),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _rejectFriendRequest(senderId, senderName),
                              ),
                            ],
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