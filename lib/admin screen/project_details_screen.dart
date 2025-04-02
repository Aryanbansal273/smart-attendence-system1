import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Map<String, dynamic> _projectData;
  bool _isLoading = true;
  String _creatorName = 'Loading...';
  List<String> _employeeNames = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _projectData = widget.project.data() as Map<String, dynamic>;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _fetchNames();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchNames() async {
    try {
      setState(() => _isLoading = true);

      String creatorUid = _projectData['creatorUid'] ?? 'Unknown';
      DocumentSnapshot creatorDoc = await _firestore.collection('teachers').doc(creatorUid).get();
      _creatorName = creatorDoc.exists ? (creatorDoc.data() as Map<String, dynamic>)['name'] ?? creatorUid : creatorUid;

      List<dynamic> employeeUids = _projectData['employeeUids'] ?? [];
      List<String> names = [];
      for (String uid in employeeUids) {
        DocumentSnapshot employeeDoc = await _firestore.collection('students').doc(uid).get();
        String name = employeeDoc.exists ? (employeeDoc.data() as Map<String, dynamic>)['name'] ?? uid : uid;
        names.add(name);
      }
      _employeeNames = names;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching names: $e');
      setState(() {
        _isLoading = false;
        _creatorName = 'Error';
        _employeeNames = (_projectData['employeeUids'] as List<dynamic>?)?.map((uid) => uid.toString()).toList() ?? [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load names: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = _projectData['name'] ?? 'Unnamed Project';
    final String description = _projectData['description'] ?? 'No description provided';
    final Timestamp deadlineTimestamp = _projectData['deadline'] ?? Timestamp.now();
    final DateTime deadline = deadlineTimestamp.toDate();
    final Timestamp createdAtTimestamp = _projectData['createdAt'] ?? Timestamp.now();
    final DateTime createdAt = createdAtTimestamp.toDate();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
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
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade50, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.briefcase, color: Colors.green.shade700, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Project Overview',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Timeline Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTimelineCard(
                    icon: LucideIcons.calendar,
                    title: 'Deadline',
                    value: DateFormat('MMM dd, yyyy').format(deadline),
                    gradientColors: [Colors.green.shade100, Colors.white],
                  ),
                  _buildTimelineCard(
                    icon: LucideIcons.clock,
                    title: 'Created At',
                    value: DateFormat('MMM dd, yyyy').format(createdAt),
                    gradientColors: [Colors.green.shade100, Colors.white],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Creator Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.green.shade100,
                          child: Icon(LucideIcons.user, color: Colors.green.shade700, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Created By',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _creatorName,
                      style: TextStyle(fontSize: 16, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Employees Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.green.shade100,
                          child: Icon(LucideIcons.users, color: Colors.green.shade700, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Assigned Team',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _employeeNames.isEmpty
                        ? Text(
                      'No team members assigned',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    )
                        : Column(
                      children: _employeeNames
                          .map((name) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        backgroundColor: Colors.green.shade700,
        child: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildTimelineCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.43,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}