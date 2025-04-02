import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for Firebase Authentication
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';

import '../provider/attendance_history_notifier.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({Key? key, required String userEmail, required List attendanceData}) : super(key: key); // Removed unused attendanceData parameter

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceHistoryNotifier(),
      child: const _AttendanceHistoryView(),
    );
  }
}

class _AttendanceHistoryView extends StatefulWidget {
  const _AttendanceHistoryView();

  @override
  _AttendanceHistoryViewState createState() => _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends State<_AttendanceHistoryView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Future<List<Map<String, dynamic>>> _attendanceFuture;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Added for Firebase Authentication
  late String _userId; // Use UID instead of email

  @override
  void initState() {
    super.initState();
    // Fetch the current user's UID
    _userId = _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      print('No user is currently signed in.');
      // Optionally, redirect to login student screen
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
    }
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
    _attendanceFuture = _fetchAttendanceByMonth(DateTime.now()); // Initial fetch
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceByMonth(DateTime month) async {
    try {
      print('Fetching attendance for user: $_userId, month: ${DateFormat('MMMM yyyy').format(month)}');
      final snapshot = await _firestore
          .collection('students') // Changed from 'users' to 'students'
          .doc(_userId) // Use UID instead of email
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: DateTime(month.year, month.month, 1))
          .where('date', isLessThan: DateTime(month.year, month.month + 1, 1))
          .get();
      final data = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      print('Fetched ${data.length} records');
      return data;
    } catch (e) {
      print('Error fetching attendance: $e');
      return [];
    }
  }

  Map<String, dynamic>? _getSelectedDayRecord(List<Map<String, dynamic>> attendance, DateTime selectedDate) {
    for (var record in attendance) {
      DateTime recordDate = (record['date'] as Timestamp).toDate();
      if (isSameDay(recordDate, selectedDate)) {
        return record;
      }
    }
    return null;
  }

  Map<String, dynamic> getMonthlyStats(List<Map<String, dynamic>> attendance) {
    if (attendance.isEmpty) {
      return {
        'workdays': 0,
        'totalHours': '0h 0m',
        'avgHours': '0h 0m',
        'onTime': 0,
        'late': 0,
      };
    }

    int onTime = 0;
    int late = 0;
    int totalMinutes = 0;

    for (var record in attendance) {
      if (record['status'] == 'On Time' || record['status'] == 'Early') {
        onTime++;
      } else if (record['status'] == 'Late') {
        late++;
      }

      String hoursStr = record['totalHours'] ?? '0h 0m';
      List<String> parts = hoursStr.split('h ');
      if (parts.length == 2) {
        int hours = int.tryParse(parts[0]) ?? 0;
        int minutes = int.tryParse(parts[1].replaceAll('m', '')) ?? 0;
        totalMinutes += (hours * 60) + minutes;
      }
    }

    int avgMinutes = (attendance.isNotEmpty) ? (totalMinutes / attendance.length).round() : 0;
    String avgHours = '${(avgMinutes ~/ 60)}h ${avgMinutes % 60}m';
    String totalHoursFormatted = '${(totalMinutes ~/ 60)}h ${totalMinutes % 60}m';

    return {
      'workdays': attendance.length,
      'totalHours': totalHoursFormatted,
      'avgHours': avgHours,
      'onTime': onTime,
      'late': late,
    };
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'On Time':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      case 'Early':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<String> getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String? placeName = [
          place.street,
          place.name,
          place.locality,
        ].firstWhere((element) => element != null && element.isNotEmpty, orElse: () => null);
        return placeName ?? 'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      print('Error geocoding coordinates ($latitude, $longitude): $e');
      return 'Unable to fetch location';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AttendanceHistoryNotifier>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Attendance History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
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
        child: SingleChildScrollView(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _attendanceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final filteredAttendance = snapshot.data ?? [];
              final stats = getMonthlyStats(filteredAttendance);

              if (filteredAttendance.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No attendance data for ${DateFormat('MMMM yyyy').format(notifier.currentMonth)}',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              return FadeTransition(
                opacity: _animation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM yyyy').format(notifier.currentMonth),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${stats['workdays']} Workdays',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem(title: 'Total Hours', value: stats['totalHours'], icon: Icons.access_time),
                                _buildStatItem(title: 'Avg Hours/Day', value: stats['avgHours'], icon: Icons.trending_up),
                                _buildStatItem(title: 'On Time', value: '${stats['onTime']}/${stats['workdays']}', icon: Icons.check_circle_outline),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildNavigationButton(Icons.arrow_back_ios_new, () {
                                notifier.previousMonth();
                                _animationController.reset();
                                _animationController.forward();
                                setState(() {
                                  _attendanceFuture = _fetchAttendanceByMonth(notifier.currentMonth);
                                });
                              }),
                              const SizedBox(width: 8),
                              _buildNavigationButton(Icons.arrow_forward_ios, () {
                                notifier.nextMonth();
                                _animationController.reset();
                                _animationController.forward();
                                setState(() {
                                  _attendanceFuture = _fetchAttendanceByMonth(notifier.currentMonth);
                                });
                              }),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => notifier.toggleListView(true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: notifier.isListView ? Colors.white38 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: notifier.isListView
                                          ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                          : [],
                                    ),
                                    child: Icon(Icons.view_list, color: notifier.isListView ? Colors.blue[700] : Colors.grey[600]),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => notifier.toggleListView(false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !notifier.isListView ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: !notifier.isListView
                                          ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                          : [],
                                    ),
                                    child: Icon(Icons.calendar_month, color: !notifier.isListView ? Colors.blue[700] : Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    notifier.isListView
                        ? _buildAttendanceListView(filteredAttendance)
                        : Column(
                      children: [
                        _buildCalendarView(filteredAttendance, notifier),
                        Consumer<AttendanceHistoryNotifier>(
                          builder: (context, notifier, child) {
                            final selectedDayRecord = _getSelectedDayRecord(filteredAttendance, notifier.selectedDate);
                            return selectedDayRecord != null
                                ? _buildSelectedDayDetail(selectedDayRecord)
                                : Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No attendance data for ${DateFormat('MMMM d, yyyy').format(notifier.selectedDate)}',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({required String title, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: Colors.black, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNavigationButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IconButton(icon: Icon(icon, size: 20, color: Colors.grey[700]), onPressed: onPressed),
    );
  }

  Widget _buildAttendanceListView(List<Map<String, dynamic>> attendance) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: attendance.length,
      itemBuilder: (context, index) {
        final record = attendance[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.white],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE, MMM d').format((record['date'] as Timestamp).toDate()),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(record['status'] ?? 'Unknown').withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          record['status'] ?? 'Unknown',
                          style: TextStyle(color: _getStatusColor(record['status'] ?? 'Unknown'), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check In', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(record['checkInTime'] ?? '--:--', style: const TextStyle(fontSize: 16)),
                          if (record['checkInLocation'] != null)
                            FutureBuilder<String>(
                              future: getPlaceName(
                                record['checkInLocation']['latitude'],
                                record['checkInLocation']['longitude'],
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Text(
                                    'Loading location...',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    'Error fetching location',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  );
                                }
                                return Text(
                                  'Loc: ${snapshot.data}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                );
                              },
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check Out', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(record['checkOutTime'] ?? '--:--', style: const TextStyle(fontSize: 16)),
                          if (record['checkOutLocation'] != null)
                            FutureBuilder<String>(
                              future: getPlaceName(
                                record['checkOutLocation']['latitude'],
                                record['checkOutLocation']['longitude'],
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Text(
                                    'Loading location...',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    'Error fetching location',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  );
                                }
                                return Text(
                                  'Loc: ${snapshot.data}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                );
                              },
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(record['totalHours'] ?? '0h 0m', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  if ((record['notes'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Notes: ${record['notes']}', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(List<Map<String, dynamic>> attendance, AttendanceHistoryNotifier notifier) {
    return TableCalendar(
      firstDay: DateTime(notifier.currentMonth.year - 1),
      lastDay: DateTime(notifier.currentMonth.year + 1),
      focusedDay: notifier.currentMonth,
      selectedDayPredicate: (day) => isSameDay(notifier.selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) {
        notifier.selectDate(selectedDay, focusedDay);
      },
      calendarFormat: CalendarFormat.month,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(color: Colors.blue[700], shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(color: Colors.blue[500], shape: BoxShape.circle),
        markerDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          bool hasAttendance = attendance.any((record) {
            DateTime recordDate = (record['date'] as Timestamp).toDate();
            return isSameDay(recordDate, date);
          });
          if (hasAttendance) {
            return Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSelectedDayDetail(Map<String, dynamic> record) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format((record['date'] as Timestamp).toDate()),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(record['status'] ?? 'Unknown').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record['status'] ?? 'Unknown',
                  style: TextStyle(color: _getStatusColor(record['status'] ?? 'Unknown'), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildDetailItem('Check In', record['checkInTime'] ?? '--:--'),
              if (record['checkInLocation'] != null)
                FutureBuilder<String>(
                  future: getPlaceName(
                    record['checkInLocation']['latitude'],
                    record['checkInLocation']['longitude'],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildDetailItem('Check In Loc', 'Loading...');
                    }
                    if (snapshot.hasError) {
                      return _buildDetailItem('Check In Loc', 'Error');
                    }
                    return _buildDetailItem('Check In Loc', snapshot.data ?? 'Unknown');
                  },
                ),
              _buildDetailItem('Check Out', record['checkOutTime'] ?? '--:--'),
              if (record['checkOutLocation'] != null)
                FutureBuilder<String>(
                  future: getPlaceName(
                    record['checkOutLocation']['latitude'],
                    record['checkOutLocation']['longitude'],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildDetailItem('Check Out Loc', 'Loading...');
                    }
                    if (snapshot.hasError) {
                      return _buildDetailItem('Check Out Loc', 'Error');
                    }
                    return _buildDetailItem('Check Out Loc', snapshot.data ?? 'Unknown');
                  },
                ),
              _buildDetailItem('Total', record['totalHours'] ?? '0h 0m'),
            ],
          ),
          const SizedBox(height: 12),
          if ((record['notes'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Notes: ${record['notes']}', style: TextStyle(color: Colors.grey[700])),
            ),
          if ((record['breaks'] ?? []).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Breaks:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...record['breaks'].map<Widget>((breakTime) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${breakTime['start']} - ${breakTime['end']} (${breakTime['duration']})',
                style: TextStyle(color: Colors.grey[700]),
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}