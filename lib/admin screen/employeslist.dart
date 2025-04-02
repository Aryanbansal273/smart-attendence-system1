import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; // Add this import for DateFormat

class EmployeeAttendanceScreen extends StatefulWidget {
  @override
  _EmployeeAttendanceScreenState createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> with SingleTickerProviderStateMixin {
  bool _showDepartments = false;
  String _selectedDepartment = 'Select Department';
  int _currentTabIndex = 0;
  TabController? _tabController;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;

  // Data for tabs
  List<Map<String, dynamic>> _loggedInData = [];
  List<Map<String, dynamic>> _onTimeData = [];
  List<Map<String, dynamic>> _lateData = [];
  bool _isLoading = true;

  // Job statistics for the department sheet
  Map<String, Map<String, dynamic>> _jobStats = {};

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      print('No user is currently signed in.');
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController!.index;
        });
      }
    });
    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String street = placemark.street ?? 'Unknown location';
        return street.isNotEmpty ? street : 'Unknown location';
      }
    } catch (e) {
      print('Error decoding coordinates: $e');
    }
    return 'Unknown location';
  }

  Future<void> _fetchAttendanceData() async {
    try {
      setState(() => _isLoading = true);

      // Step 1: Fetch the current teacher's friends subcollection
      QuerySnapshot friendsSnapshot = await _firestore
          .collection('teachers')
          .doc(_userId)
          .collection('friends')
          .get();

      if (friendsSnapshot.docs.isEmpty) {
        print('No friends found for teacher: $_userId');
        setState(() => _isLoading = false);
        return;
      }

      // Extract friend UIDs from the subcollection
      List<String> friendUids = friendsSnapshot.docs
          .map((doc) => doc.get('friendId') as String)
          .toList();

      // Step 2: Fetch attendance details for each friend from the 'students' collection
      List<Map<String, dynamic>> loggedInList = [];
      List<Map<String, dynamic>> onTimeList = [];
      List<Map<String, dynamic>> lateList = [];

      // Initialize job statistics
      Map<String, Map<String, dynamic>> jobStats = {};

      for (String friendUid in friendUids) {
        DocumentSnapshot studentDoc = await _firestore.collection('students').doc(friendUid).get();
        if (studentDoc.exists) {
          final data = studentDoc.data() as Map<String, dynamic>;
          String job = data['job'] ?? 'Student';

          // Initialize stats for this job if not already present
          if (!jobStats.containsKey(job)) {
            jobStats[job] = {
              'total': 0,
              'onTime': 0,
              'late': 0,
              'leave': 0, // We'll assume 'leave' if the student is not checked in
            };
          }

          // Increment total count for this job
          jobStats[job]!['total'] = (jobStats[job]!['total'] as int) + 1;

          bool isCheckedIn = data['isCheckedIn'] ?? false;
          if (isCheckedIn) {
            // Extract check-in location and decode it
            String location = 'Not specified';
            if (data['checkInLocation'] != null) {
              double latitude = data['checkInLocation']['latitude']?.toDouble() ?? 0.0;
              double longitude = data['checkInLocation']['longitude']?.toDouble() ?? 0.0;
              if (latitude != 0.0 && longitude != 0.0) {
                location = await _getAddressFromCoordinates(latitude, longitude);
              }
            }

            // Format the check-in time to show only the time (e.g., "14:42")
            String loginTime = '--:--';
            if (data['checkInTime'] != null) {
              Timestamp checkInTimestamp = data['checkInTime'] as Timestamp;
              DateTime checkInDateTime = checkInTimestamp.toDate();
              loginTime = DateFormat('HH:mm').format(checkInDateTime); // Format to show only time
            }

            // Prepare employee data
            Map<String, dynamic> employee = {
              'name': data['name'] ?? 'Unknown',
              'position': job,
              'status': 'Regular',
              'loginTime': loginTime, // Use the formatted time
              'attendance': data['status'] ?? 'Unknown',
              'avatar': _getAvatarColor(data['name']),
              'location': location,
            };

            // Add to Logged In list
            loggedInList.add(employee);

            // Update job stats based on attendance
            if (employee['attendance'] == 'On Time') {
              jobStats[job]!['onTime'] = (jobStats[job]!['onTime'] as int) + 1;
              onTimeList.add(employee);
            } else if (employee['attendance'] == 'Late') {
              jobStats[job]!['late'] = (jobStats[job]!['late'] as int) + 1;
              lateList.add(employee);
            }
          } else {
            // If not checked in, assume they are on leave
            jobStats[job]!['leave'] = (jobStats[job]!['leave'] as int) + 1;
          }
        }
      }

      setState(() {
        _loggedInData = loggedInList;
        _onTimeData = onTimeList;
        _lateData = lateList;
        _jobStats = jobStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching attendance data: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getAvatarColor(String? name) {
    if (name == null) return Colors.grey[400]!;
    int hash = name.hashCode;
    List<Color> colors = [
      Colors.blue[200]!,
      Colors.purple[200]!,
      Colors.orange[200]!,
      Colors.green[200]!,
      Colors.red[200]!,
      Colors.teal[200]!,
      Colors.amber[200]!,
    ];
    return colors[hash % colors.length];
  }

  // Helper method to map jobs to department names, icons, and colors
  Map<String, dynamic> _getDepartmentDetails(String job) {
    switch (job.toLowerCase()) {
      case 'software engineer':
        return {
          'title': 'Development',
          'icon': Icons.code,
          'iconColor': Colors.purple,
        };
      case 'designer':
        return {
          'title': 'Design',
          'icon': Icons.design_services,
          'iconColor': Colors.blue,
        };
      case 'data scientist':
        return {
          'title': 'Data Science',
          'icon': Icons.analytics,
          'iconColor': Colors.green,
        };
      case 'sales representative':
        return {
          'title': 'Sales',
          'icon': Icons.people,
          'iconColor': Colors.orange,
        };
      case 'customer support':
        return {
          'title': 'Customer Support',
          'icon': Icons.support_agent,
          'iconColor': Colors.red,
        };
      case 'finance manager':
        return {
          'title': 'Finance',
          'icon': Icons.money,
          'iconColor': Colors.green,
        };
      case 'hr manager':
        return {
          'title': 'HR',
          'icon': Icons.person,
          'iconColor': Colors.deepPurple,
        };
      case 'marketing specialist':
        return {
          'title': 'Marketing',
          'icon': Icons.shopping_cart,
          'iconColor': Colors.amber,
        };
      default:
        return {
          'title': job,
          'icon': Icons.work,
          'iconColor': Colors.teal,
        };
    }
  }

  void _showDepartmentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            // Calculate "All Departments" stats
            int totalAll = _jobStats.values.fold(0, (sum, stats) => sum + (stats['total'] as int));
            int onTimeAll = _jobStats.values.fold(0, (sum, stats) => sum + (stats['onTime'] as int));
            int lateAll = _jobStats.values.fold(0, (sum, stats) => sum + (stats['late'] as int));
            int leaveAll = _jobStats.values.fold(0, (sum, stats) => sum + (stats['leave'] as int));

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _selectedDepartment != 'Select Department' ? _selectedDepartment : 'Select Department',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(thickness: 1, height: 1),
                  Expanded(
                    child: GridView.count(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16.0),
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        // "All Departments" card
                        _buildDepartmentCard(
                          icon: Icons.corporate_fare,
                          iconColor: Colors.teal,
                          title: 'All Departments',
                          total: totalAll,
                          onTime: onTimeAll,
                          late: lateAll,
                          leave: leaveAll,
                          onTap: () {
                            setState(() {
                              _selectedDepartment = 'All Departments';
                            });
                            Navigator.pop(context);
                          },
                        ),
                        // Dynamically generate cards for each job
                        ..._jobStats.entries.map((entry) {
                          String job = entry.key;
                          Map<String, dynamic> stats = entry.value;
                          Map<String, dynamic> deptDetails = _getDepartmentDetails(job);

                          return _buildDepartmentCard(
                            icon: deptDetails['icon'],
                            iconColor: deptDetails['iconColor'],
                            title: deptDetails['title'],
                            total: stats['total'],
                            onTime: stats['onTime'],
                            late: stats['late'],
                            leave: stats['leave'],
                            onTap: () {
                              setState(() {
                                _selectedDepartment = deptDetails['title'];
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDepartmentCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int total,
    required int onTime,
    required int late,
    required int leave,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 70,
                  width: 1,
                  color: Colors.grey[200],
                ),
                Expanded(
                  flex: 8,
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'On-time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Spacer(),
                            Text(
                              onTime.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 8, thickness: 0.5, color: Colors.grey[200]),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Late',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Spacer(),
                            Text(
                              late.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 8, thickness: 0.5, color: Colors.grey[200]),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Leave',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Spacer(),
                            Text(
                              leave > 0 ? leave.toString().padLeft(2, '0') : '--',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, thickness: 0.5, color: Colors.grey[200]),
            ),
            Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Departments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _showDepartmentSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[100]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.badge,
                          size: 18,
                          color: Colors.black,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _selectedDepartment,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 18),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.black,
                    indicatorWeight: 2,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
                    tabs: [
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.login, size: 16), SizedBox(width: 6), Text('Logged In')])),
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.table_chart_sharp, size: 16), SizedBox(width: 6), Text('On Time')])),
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.schedule, size: 14), SizedBox(width: 6), Text('Late')])),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return ScaleTransition(scale: animation, child: child);
                                },
                                child: Icon(
                                  Icons.search,
                                  key: ValueKey('searchIcon'),
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 400),
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: child,
                                  );
                                },
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search employees...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onChanged: (value) {
                                    // Add your search functionality here
                                  },
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                  cursorColor: Colors.blue[700],
                                  cursorWidth: 1.5,
                                  cursorRadius: Radius.circular(2),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {},
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmployeeList(_loggedInData),
                      _buildEmployeeList(_onTimeData),
                      _buildEmployeeList(_lateData),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final employee = data[index];
        final bool isLate = employee['attendance'] == 'Late';

        return Card(
          color: Colors.white,
          shadowColor: Colors.black26,
          elevation: 5,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[100]!)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 58,
                    decoration: BoxDecoration(
                      color: employee['avatar'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        employee['name']?.substring(0, 1) ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(_getPositionIcon(employee['position']), size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text('${employee['position']} | ${employee['status']}', style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Location: ${employee['location']}',
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[200], thickness: 1, height: 5),
                        Row(
                          children: [
                            Icon(Icons.login, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text('Login: ${employee['loginTime']}', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLate ? Colors.red[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLate ? Icons.schedule : Icons.check_circle,
                              size: 14,
                              color: isLate ? Colors.red[400] : Colors.green[400],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              employee['attendance'],
                              style: TextStyle(
                                color: isLate ? Colors.red[400] : Colors.green[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLate)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Late by ${employee['lateDuration'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.red[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getPositionIcon(String position) {
    switch (position.toLowerCase()) {
      case 'student':
        return Icons.school;
      case 'software engineer':
        return Icons.code;
      case 'designer':
        return Icons.design_services;
      case 'data scientist':
        return Icons.analytics;
      case 'sales representative':
        return Icons.people;
      case 'customer support':
        return Icons.support_agent;
      case 'finance manager':
        return Icons.money;
      case 'hr manager':
        return Icons.person;
      case 'marketing specialist':
        return Icons.shopping_cart;
      default:
        return Icons.work;
    }
  }
}