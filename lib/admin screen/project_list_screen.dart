import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartt_attendance/admin%20screen/project_details_screen.dart';
import 'addgroup.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _projects = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      print('No user is currently signed in.');
    }
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _fetchProjects();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    try {
      setState(() => _isLoading = true);

      QuerySnapshot snapshot = await _firestore
          .collection('projects')
          .where(Filter.or(
        Filter('creatorUid', isEqualTo: _userId),
        Filter('employeeUids', arrayContains: _userId),
      ))
          .get();

      setState(() {
        _projects = snapshot.docs;
        _isLoading = false;
        _animationController.forward();
      });
    } catch (e) {
      print('Error fetching projects: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load projects: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Projects',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff003300), Color(0xff006600)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Colors.green.shade700,
          strokeWidth: 3,
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: _projects.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.folderX,
                  size: 60,
                  color: Colors.green.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Projects Found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create or join a project to get started!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _projects.length,
          itemBuilder: (context, index) {
            final project = _projects[index];
            final data = project.data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'Unnamed Project';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(project: project),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.green.shade50],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green.shade100,
                      child: Icon(
                        LucideIcons.briefcase,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      // Add the FloatingActionButton here
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProjectAssignmentScreen(),
            ),
          ).then((value) {
            // Refresh projects when returning from the assignment screen
            if (value == true) {
              _fetchProjects();
            }
          });
        },
        backgroundColor: Colors.green.shade700,
        tooltip: 'Create New Project',
        child: const Icon(
          LucideIcons.plus,
          color: Colors.white,
        ),
      ),
    );
  }
}