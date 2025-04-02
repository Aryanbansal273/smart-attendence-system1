import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smartt_attendance/admin_bottom_nav.dart';
import 'package:smartt_attendance/bottom_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartt_attendance/student%20screen/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await sp.Supabase.initialize(
    url: 'https://xzoyevujxvqaumrdskhd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6b3lldnVqeHZxYXVtcmRza2hkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyMTE1MjMsImV4cCI6MjA1NDc4NzUyM30.mbV_Scy2fXbMalxVRGHNKOxYx0o6t-nUPmDLlH5Mr_U',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Method to determine the initial home page based on user role
  Future<Widget> _getInitialHomePage() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User is logged out, return LoginScreen
      return const LoginScreen();
    }

    // User is logged in, check their role in Firestore
    try {
      // Check 'students' collection first
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (studentDoc.exists) {
        return const HomeScreen(); // Student logged in
      }

      // If not found in 'students', check 'teachers' collection
      DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();

      if (teacherDoc.exists) {
        return const AdminBottomNav(); // Teacher logged in
      }

      // If no role is found (edge case), fallback to LoginScreen
      return const LoginScreen();
    } catch (e) {
      // Handle any errors (e.g., Firestore unavailable) by showing LoginScreen
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialHomePage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while checking user state
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Return the determined home page (LoginScreen, HomeScreen, or TeacherAdminPanel)
            return snapshot.data!;
          }
          // Fallback in case of error
          return const LoginScreen();
        },
      ),
    );
  }
}
