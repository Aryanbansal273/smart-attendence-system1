import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smartt_attendance/admin%20screen/project_list_screen.dart';

import 'addgroup.dart'; // ProjectAssignmentScreen
import 'employee_list_screen.dart';
import 'analyzer_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return const DashboardHome();
  }
}

class _DashboardHomeState extends State<DashboardHome> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isMenuOpen = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;
  String? _profileImageUrl;
  bool _isImageLoading = true;

  Map<String, dynamic> _summaryData = {
    'totalEmployees': 0,
    'totalEmployeesChange': 0.0,
    'presentToday': 0,
    'presentTodayChange': 0.0,
    'onLeave': 0,
    'activeProjects': 0,
  };
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _userId = _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      print('No user is currently signed in.');
    }
    _fetchDashboardData();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    try {
      setState(() => _isLoading = true);
      await _fetchSummaryData();
      await _fetchProjects();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSummaryData() async {
    QuerySnapshot friendsSnapshot = await _firestore
        .collection('teachers')
        .doc(_userId)
        .collection('friends')
        .get();
    int totalFriends = friendsSnapshot.docs.length;

    double totalFriendsChange = 0.0;
    DateTime now = DateTime.now();
    DateTime firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    DateTime lastDayOfPreviousMonth = firstDayOfCurrentMonth.subtract(Duration(days: 1));
    QuerySnapshot previousFriendsSnapshot = await _firestore
        .collection('teachers')
        .doc(_userId)
        .collection('friendHistory')
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfPreviousMonth))
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (previousFriendsSnapshot.docs.isNotEmpty) {
      int previousFriendsCount = previousFriendsSnapshot.docs.first.get('count') ?? 0;
      if (previousFriendsCount > 0) {
        totalFriendsChange = ((totalFriends - previousFriendsCount) / previousFriendsCount) * 100;
      }
    }

    List<String> friendUids = friendsSnapshot.docs
        .map((doc) => doc.get('friendId') as String)
        .toList();

    int presentToday = 0;
    int onLeave = 0;
    DateTime today = DateTime(now.year, now.month, now.day);

    for (String friendUid in friendUids) {
      DocumentSnapshot studentDoc = await _firestore.collection('students').doc(friendUid).get();
      if (studentDoc.exists) {
        var data = studentDoc.data() as Map<String, dynamic>;
        if (data.containsKey('checkInTime') && data['checkInTime'] != null) {
          Timestamp checkInTimestamp = data['checkInTime'] as Timestamp;
          DateTime checkInDate = checkInTimestamp.toDate();
          if (DateTime(checkInDate.year, checkInDate.month, checkInDate.day) == today) {
            presentToday++;
          }
        }
        if (data['leaveStatus'] == 'On Leave') {
          onLeave++;
        }
      }
    }

    double presentTodayChange = 0.0;
    DateTime yesterday = now.subtract(Duration(days: 1));
    QuerySnapshot yesterdayAttendanceSnapshot = await _firestore
        .collection('attendanceRecords')
        .where('date', isEqualTo: Timestamp.fromDate(DateTime(yesterday.year, yesterday.month, yesterday.day)))
        .limit(1)
        .get();

    if (yesterdayAttendanceSnapshot.docs.isNotEmpty) {
      int yesterdayPresent = yesterdayAttendanceSnapshot.docs.first.get('present') ?? 0;
      if (yesterdayPresent > 0) {
        presentTodayChange = ((presentToday - yesterdayPresent) / yesterdayPresent) * 100;
      }
    }

    QuerySnapshot projectsSnapshot = await _firestore.collection('projects').get();
    int activeProjects = projectsSnapshot.docs.length;

    setState(() {
      _summaryData = {
        'totalEmployees': totalFriends,
        'totalEmployeesChange': totalFriendsChange,
        'presentToday': presentToday,
        'presentTodayChange': presentTodayChange,
        'onLeave': onLeave,
        'activeProjects': activeProjects,
      };
    });
  }

  Future<void> _fetchProjects() async {
    QuerySnapshot projectsSnapshot = await _firestore.collection('projects').get();
    List<Map<String, dynamic>> projects = projectsSnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'name': data['name'] ?? 'Unknown',
        'team': data['team'] ?? 'Unknown',
        'deadline': DateFormat('dd MMM').format((data['deadline'] as Timestamp).toDate()),
        'progress': (data['progress'] ?? 0).toDouble(),
        'color': _getTeamColor(data['team']),
      };
    }).toList();

    setState(() => _projects = projects);
  }

  Color _getTeamColor(String team) {
    switch (team.toLowerCase()) {
      case 'development': return Colors.purple;
      case 'design': return Colors.blue;
      case 'ui/ux': return Colors.green;
      case 'qa team': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      if (_userId.isEmpty) return;
      final teacherDoc = await _firestore.collection('teachers').doc(_userId).get();
      if (teacherDoc.exists) {
        setState(() {
          _profileImageUrl = teacherDoc.data()?['profileImageUrl'];
          _isImageLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
      setState(() => _isImageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: _isImageLoading
              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
              : CircleAvatar(
            radius: 16,
            backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? NetworkImage(_profileImageUrl!)
                : const NetworkImage('https://i.pravatar.cc/100'),
            onBackgroundImageError: (e, s) => print('Error loading profile image: $e'),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryCards(summaryData: _summaryData),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Project Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add', style: TextStyle(fontSize: 12)),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectAssignmentScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProjectStatusList(projects: _projects),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedOpacity(
            opacity: _isMenuOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                FloatingActionButton.extended(
                  heroTag: 'fab_department', // Unique tag
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
                    _toggleMenu();
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  label: const Text('Department'),
                  icon: const Icon(Icons.business),
                  elevation: 4,
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'fab_group', // Unique tag
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectListScreen()));
                    _toggleMenu();
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  label: const Text('Group'),
                  icon: const Icon(Icons.group),
                  elevation: 4,
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'fab_analyzer', // Unique tag
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyzerScreen()));
                    _toggleMenu();
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  label: const Text('Analyzer'),
                  icon: const Icon(Icons.analytics),
                  elevation: 4,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          FloatingActionButton(
            heroTag: 'fab_menu', // Unique tag
            onPressed: _toggleMenu,
            backgroundColor: const Color(0xff006600),
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _animationController,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// SummaryCards and ProjectStatusList remain unchanged for brevity
class SummaryCards extends StatelessWidget {
  final Map<String, dynamic> summaryData;

  const SummaryCards({Key? key, required this.summaryData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen())),
          child: _buildSummaryCard(
            context,
            title: 'Total Employees',
            value: summaryData['totalEmployees'].toString(),
            changePercentage: summaryData['totalEmployeesChange'],
            iconData: Icons.people,
            iconColor: Colors.blue,
          ),
        ),
        _buildSummaryCard(
          context,
          title: 'Present Today',
          value: summaryData['presentToday'].toString(),
          changePercentage: summaryData['presentTodayChange'],
          iconData: Icons.check_circle,
          iconColor: Colors.green,
        ),
        _buildSummaryCard(
          context,
          title: 'On Leave',
          value: summaryData['onLeave'].toString(),
          changePercentage: -8.3,
          iconData: Icons.calendar_today,
          iconColor: Colors.orange,
        ),
        _buildSummaryCard(
          context,
          title: 'Active Projects',
          value: summaryData['activeProjects'].toString(),
          changePercentage: 4.1,
          iconData: Icons.work,
          iconColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required String title,
        required String value,
        required double changePercentage,
        required IconData iconData,
        required Color iconColor,
      }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.2),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Icon(iconData, color: iconColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(changePercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: changePercentage >= 0 ? Colors.green : Colors.red, size: 14),
                const SizedBox(width: 4),
                Text('${changePercentage.abs().toStringAsFixed(1)}%', style: TextStyle(color: changePercentage >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 4),
                Expanded(child: Text('last ${title == 'Present Today' ? 'day' : 'month'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 10))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectStatusList extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const ProjectStatusList({Key? key, required this.projects}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final project = projects[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(project['team'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text('Deadline: ${project['deadline']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), const SizedBox(width: 16)]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: project['progress'] as double,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(project['color'] as Color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),
        );
      },
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}