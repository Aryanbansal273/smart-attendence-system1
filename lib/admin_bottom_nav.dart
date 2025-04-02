import 'package:flutter/material.dart';
import 'package:smartt_attendance/admin%20screen/admin_profile.dart';
import 'package:smartt_attendance/admin%20screen/employeslist.dart';
import 'package:smartt_attendance/admin%20screen/homeadmin.dart';

class AdminBottomNav extends StatefulWidget {
  const AdminBottomNav({super.key});

  @override
  State<AdminBottomNav> createState() => _AdminBottomNavState();
}

class _AdminBottomNavState extends State<AdminBottomNav> {


  int _selectedIndex = 0;

  // Use const where possible to avoid unnecessary rebuilds
  final List<Widget> _pages = [
     AdminDashboard(),
     EmployeeAttendanceScreen(),
     AdminProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex], // Display the selected student screen
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(15),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.green[900],
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, "Attendance", 0),
            _buildNavItem(Icons.calendar_month, "dashboard", 1),
            _buildNavItem(Icons.person, "Profile", 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 20 : 10, vertical: 10),
        decoration: isSelected
            ? BoxDecoration(
          color: Colors.green[700],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}