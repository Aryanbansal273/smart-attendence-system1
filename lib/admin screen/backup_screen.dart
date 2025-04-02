import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _backupHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBackupHistory();
  }

  Future<void> _loadBackupHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('teachers')
          .doc(userId)
          .collection('backups')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _backupHistory = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
            'size': data['size'] ?? 0,
            'status': data['status'] ?? 'completed',
          };
        }).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading backup history: $e');
    }
  }

  Map<String, dynamic> _convertTimestamp(Map<String, dynamic> data) {
    Map<String, dynamic> converted = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = {
          '_timestamp': true,
          'seconds': value.seconds,
          'nanoseconds': value.nanoseconds,
        };
      } else if (value is Map) {
        converted[key] = _convertTimestamp(Map<String, dynamic>.from(value));
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is Map) {
            return _convertTimestamp(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });
    return converted;
  }

  Map<String, dynamic> _convertTimestampBack(Map<String, dynamic> data) {
    Map<String, dynamic> converted = {};
    data.forEach((key, value) {
      if (value is Map && value.containsKey('_timestamp')) {
        converted[key] = Timestamp(value['seconds'], value['nanoseconds']);
      } else if (value is Map) {
        converted[key] = _convertTimestampBack(Map<String, dynamic>.from(value));
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is Map) {
            return _convertTimestampBack(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });
    return converted;
  }

  Future<void> _createBackup() async {
    try {
      setState(() => _isLoading = true);
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get all collections data
      final Map<String, dynamic> backupData = {};

      // Get teacher data and friends
      final teacherDoc = await _firestore.collection('teachers').doc(userId).get();
      if (teacherDoc.exists) {
        backupData['teacher'] = {
          'id': teacherDoc.id,
          'data': _convertTimestamp(teacherDoc.data() ?? {}),
        };

        // Get friends subcollection
        final friendsSnapshot = await _firestore
            .collection('teachers')
            .doc(userId)
            .collection('friends')
            .get();
        
        backupData['friends'] = friendsSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': _convertTimestamp(doc.data()),
        }).toList();
      }

      // Get students data (from friends' references)
      final List<String> friendIds = (backupData['friends'] as List)
          .map((friend) => friend['data']['friendId'] as String)
          .toList();

      final List<Map<String, dynamic>> studentsData = [];
      for (String friendId in friendIds) {
        final studentDoc = await _firestore.collection('students').doc(friendId).get();
        if (studentDoc.exists) {
          studentsData.add({
            'id': studentDoc.id,
            'data': _convertTimestamp(studentDoc.data() ?? {}),
          });

          // Get attendance subcollection for each student
          final attendanceSnapshot = await _firestore
              .collection('students')
              .doc(friendId)
              .collection('attendance')
              .get();
          
          final attendanceData = attendanceSnapshot.docs.map((doc) => {
            'studentId': friendId,
            'id': doc.id,
            'data': _convertTimestamp(doc.data()),
          }).toList();

          if (attendanceData.isNotEmpty) {
            if (!backupData.containsKey('attendance')) {
              backupData['attendance'] = [];
            }
            (backupData['attendance'] as List).addAll(attendanceData);
          }
        }
      }
      backupData['students'] = studentsData;

      // Convert to JSON string
      final jsonString = jsonEncode(backupData);

      // Save backup to Firestore
      await _firestore
          .collection('teachers')
          .doc(userId)
          .collection('backups')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'data': jsonString,
        'size': jsonString.length,
        'status': 'completed',
      });

      // Save backup locally
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      _showSnackBar('Backup created successfully');
      _loadBackupHistory();
    } catch (e) {
      _showSnackBar('Error creating backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    try {
      setState(() => _isLoading = true);

      // Pick backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

      // Start a batch write
      WriteBatch batch = _firestore.batch();
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Restore teacher data
      if (backupData.containsKey('teacher')) {
        final teacherData = backupData['teacher'];
        batch.set(
          _firestore.collection('teachers').doc(userId),
          _convertTimestampBack(teacherData['data']),
        );
      }

      // Restore friends
      if (backupData.containsKey('friends')) {
        for (var friend in backupData['friends']) {
          batch.set(
            _firestore
                .collection('teachers')
                .doc(userId)
                .collection('friends')
                .doc(friend['id']),
            _convertTimestampBack(friend['data']),
          );
        }
      }

      // Commit first batch (to avoid batch size limits)
      await batch.commit();
      batch = _firestore.batch();

      // Restore students
      if (backupData.containsKey('students')) {
        for (var student in backupData['students']) {
          batch.set(
            _firestore.collection('students').doc(student['id']),
            _convertTimestampBack(student['data']),
          );
        }
      }

      // Commit second batch
      await batch.commit();
      batch = _firestore.batch();

      // Restore attendance records
      if (backupData.containsKey('attendance')) {
        for (var attendance in backupData['attendance']) {
          batch.set(
            _firestore
                .collection('students')
                .doc(attendance['studentId'])
                .collection('attendance')
                .doc(attendance['id']),
            _convertTimestampBack(attendance['data']),
          );
        }
      }

      // Commit final batch
      await batch.commit();

      _showSnackBar('Backup restored successfully');
      _loadBackupHistory();
    } catch (e) {
      _showSnackBar('Error restoring backup: $e');
    } finally {
      setState(() => _isLoading = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Management'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Backup & Restore',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _createBackup,
                                icon: const Icon(Icons.backup),
                                label: const Text('Create Backup'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _restoreBackup,
                                icon: const Icon(Icons.restore),
                                label: const Text('Restore Backup'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Backup History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _backupHistory.length,
                      itemBuilder: (context, index) {
                        final backup = _backupHistory[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.backup),
                            title: Text(
                              DateFormat('MMM dd, yyyy HH:mm').format(backup['timestamp']),
                            ),
                            subtitle: Text(
                              'Size: ${(backup['size'] / 1024).toStringAsFixed(2)} KB',
                            ),
                            trailing: Icon(
                              backup['status'] == 'completed'
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: backup['status'] == 'completed'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
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