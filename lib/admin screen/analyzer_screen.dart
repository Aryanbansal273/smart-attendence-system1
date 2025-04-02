import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({Key? key}) : super(key: key);

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;

  List<Map<String, dynamic>> _attendanceData = [];
  Map<String, double> _teamPerformance = {};
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _topPerformers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid ?? '';
    if (_userId.isEmpty) {
      print('No user is currently signed in.');
    }
    _fetchAnalyzerData();
  }

  Future<void> _fetchAnalyzerData() async {
    try {
      setState(() => _isLoading = true);
      await _fetchAttendanceData();
      await _fetchTeamPerformance();
      await _fetchActivities();
      await _fetchTopPerformers();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching analyzer data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendanceData() async {
    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendanceRecords')
        .orderBy('date', descending: true)
        .limit(7)
        .get();

    List<Map<String, dynamic>> attendanceData = attendanceSnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'present': (data['present'] ?? 0).toDouble(),
        'late': (data['late'] ?? 0).toDouble(),
        'absent': (data['absent'] ?? 0).toDouble(),
      };
    }).toList();

    setState(() => _attendanceData = attendanceData);
  }

  Future<void> _fetchTeamPerformance() async {
    QuerySnapshot studentsSnapshot = await _firestore.collection('students').get();
    Map<String, List<double>> teamScores = {};

    for (var doc in studentsSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String job = data['job'] ?? 'Student';
      double performanceScore = (data['performanceScore'] ?? 0).toDouble();
      String department = _mapJobToDepartment(job);
      teamScores.putIfAbsent(department, () => []).add(performanceScore);
    }

    Map<String, double> performance = {};
    teamScores.forEach((team, scores) {
      performance[team] = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0;
    });

    setState(() => _teamPerformance = performance);
  }

  Future<void> _fetchActivities() async {
    QuerySnapshot activitiesSnapshot = await _firestore
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    List<Map<String, dynamic>> activities = activitiesSnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'user': data['user'] ?? 'Unknown',
        'action': data['action'] ?? 'Unknown',
        'time': _formatTimestamp(data['timestamp']),
        'avatar': data['avatar'] ?? 'https://i.pravatar.cc/150',
      };
    }).toList();

    setState(() => _activities = activities);
  }

  Future<void> _fetchTopPerformers() async {
    QuerySnapshot performersSnapshot = await _firestore
        .collection('students')
        .orderBy('performanceScore', descending: true)
        .limit(4)
        .get();

    List<Map<String, dynamic>> performers = performersSnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'name': data['name'] ?? 'Unknown',
        'position': data['job'] ?? 'Student',
        'hours': data['hoursWorked'] ?? 0,
        'progress': (data['performanceScore'] ?? 0) / 100,
        'avatar': 'https://i.pravatar.cc/150?img=${doc.id.hashCode % 10}',
      };
    }).toList();

    setState(() => _topPerformers = performers);
  }

  String _mapJobToDepartment(String job) {
    switch (job.toLowerCase()) {
      case 'software engineer': return 'Development';
      case 'designer': return 'Design';
      case 'data scientist': return 'Data Science';
      case 'sales representative': return 'Sales';
      case 'customer support': return 'Customer Support';
      case 'finance manager': return 'Finance';
      case 'hr manager': return 'HR';
      case 'marketing specialist': return 'Marketing';
      default: return 'Others';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('dd MMM').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Analyzer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Attendance Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: 'This Month',
                            items: ['This Week', 'This Month', 'Last 3 Months', 'This Year']
                                .map((value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(height: 250, child: AttendanceChart(attendanceData: _attendanceData)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Team Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: () {}),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(height: 250, child: TeamPerformanceChart(teamPerformance: _teamPerformance)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recent Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(child: const Text('View All', style: TextStyle(fontSize: 12)), onPressed: () {}),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ActivityList(activities: _activities),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Top Performers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: 'This Month',
                            items: ['This Week', 'This Month', 'This Quarter']
                                .map((value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TopPerformersList(performers: _topPerformers),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> attendanceData;

  const AttendanceChart({Key? key, required this.attendanceData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final labels = ['1', '5', '10', '15', '20', '25', '30'];
                final index = value.toInt();
                if (index >= 0 && index < labels.length) {
                  return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(labels[index], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)));
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('${value.toInt()}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: attendanceData.length - 1,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(attendanceData.length, (index) => FlSpot(index.toDouble(), attendanceData[index]['present'])),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: List.generate(attendanceData.length, (index) => FlSpot(index.toDouble(), attendanceData[index]['late'])),
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: List.generate(attendanceData.length, (index) => FlSpot(index.toDouble(), attendanceData[index]['absent'])),
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String status = spot.bar.color == Colors.green ? 'Present' : spot.bar.color == Colors.orange ? 'Late' : 'Absent';
              return LineTooltipItem('$status: ${spot.y.toInt()}%', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class TeamPerformanceChart extends StatelessWidget {
  final Map<String, double> teamPerformance;

  const TeamPerformanceChart({Key? key, required this.teamPerformance}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<String> teams = teamPerformance.keys.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${teams[groupIndex]}: ${rod.toY.toInt()}%', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < teams.length) {
                  return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(teams[index].substring(0, teams[index].length > 4 ? 4 : teams[index].length), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)));
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('${value.toInt()}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(teams.length, (index) => BarChartGroupData(
          x: index,
          barRods: [BarChartRodData(toY: teamPerformance[teams[index]]!, color: _getTeamColor(teams[index]), width: 15, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
        )),
      ),
    );
  }

  Color _getTeamColor(String team) {
    switch (team.toLowerCase()) {
      case 'development': return Colors.blue;
      case 'design': return Colors.purple;
      case 'qa': return Colors.green;
      case 'marketing': return Colors.orange;
      case 'sales': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class ActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activities;

  const ActivityList({Key? key, required this.activities}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundImage: NetworkImage(activity['avatar'] as String)),
          title: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(text: activity['user'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' '),
                TextSpan(text: activity['action'] as String),
              ],
            ),
          ),
          subtitle: Text(activity['time'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        );
      },
    );
  }
}

class TopPerformersList extends StatelessWidget {
  final List<Map<String, dynamic>> performers;

  const TopPerformersList({Key? key, required this.performers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: performers.length,
      itemBuilder: (context, index) {
        final performer = performers[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(performer['avatar'] as String)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(performer['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(performer['position'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${performer['hours']} hrs', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4)]),
            ],
          ),
        );
      },
    );
  }
}