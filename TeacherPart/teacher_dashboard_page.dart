import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'teacher_profile_page.dart';
import 'student_attendance_page.dart';
import 'student_cgpa_page.dart';
import 'class_routine_page.dart';
import 'drop_update_page.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  // Function to log logout action to Firestore
  Future<void> _logLogoutAction(String? userEmail) async {
    try {
      await FirebaseFirestore.instance.collection('logout_logs').add({
        'email': userEmail ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging logout to Firestore: $e');
    }
  }

  // Function to log navigation actions to Firestore
  Future<void> _logNavigationAction(String? userEmail, String option) async {
    try {
      await FirebaseFirestore.instance.collection('navigation_logs').add({
        'email': userEmail ?? 'unknown',
        'option': option,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging navigation to Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/dulogo.png',
                    height: 150,
                    width: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error, size: 100, color: Colors.white70);
                    },
                  ).animate().fadeIn(duration: 800.ms),
                  const SizedBox(height: 20),
                  const Text(
                    'University Of Dhaka',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Teacher Dashboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      OptionBox(
                        title: 'Profile',
                        icon: Icons.person,
                        onTap: () {
                          _logNavigationAction(user?.email, 'Profile');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TeacherProfilePage()),
                          );
                        },
                      ),
                      OptionBox(
                        title: 'Student Attendance',
                        icon: Icons.check_circle,
                        onTap: () {
                          _logNavigationAction(user?.email, 'Student Attendance');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StudentAttendancePage()),
                          );
                        },
                      ),
                      OptionBox(
                        title: 'Student CGPA',
                        icon: Icons.school,
                        onTap: () {
                          _logNavigationAction(user?.email, 'Student CGPA');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StudentCGPAPage()),
                          );
                        },
                      ),
                      OptionBox(
                        title: 'Class Routine',
                        icon: Icons.schedule,
                        onTap: () {
                          _logNavigationAction(user?.email, 'Class Routine');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ClassRoutinePage()),
                          );
                        },
                      ),
                      OptionBox(
                        title: 'Drop Update',
                        icon: Icons.announcement,
                        onTap: () {
                          _logNavigationAction(user?.email, 'Drop Update');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DropUpdatePage()),
                          );
                        },
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.9, end: 1.0),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      await _logLogoutAction(user?.email);
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(200, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9, end: 1.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OptionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const OptionBox({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
