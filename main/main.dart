import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'dashboard_page.dart';
import 'teacher_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for web
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDsVkaW5sCeETJzSv4jh_mgp4cG7JMtUeI",
          authDomain: "app1-87264.firebaseapp.com",
          projectId: "app1-87264",
          storageBucket: "app1-87264.firebasestorage.app",
          messagingSenderId: "61554267045",
          appId: "1:61554267045:web:39c3409d26fcae5f988e4c",
          measurementId: "G-RRRXT1RHM1",
        ),
      );
    } catch (e) {
      print('Error initializing Firebase: $e');
    }
  } else {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Error initializing Firebase: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  Future<Map<String, String?>> _checkLoginStatus() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final role = prefs.getString('user_role');
      print('Checking login status: token=$token, role=$role');

      if (token != null && role != null) {
        // Verify token in Firestore
        final userDoc = await firestore
            .collection('users')
            .doc(token.replaceFirst('mock_token_', ''))
            .get();
        if (userDoc.exists && userDoc.data()!['role'] == role) {
          return {'token': token, 'role': role};
        }
      }
      return {'token': null, 'role': null};
    } catch (e) {
      print('Error checking login status: $e');
      return {'token': null, 'role': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print('Error checking login status: ${snapshot.error}');
          return const LoginPage();
        }

        if (snapshot.hasData) {
          final token = snapshot.data!['token'];
          final role = snapshot.data!['role'];

          if (token != null && role != null) {
            if (role == 'student') {
              return const DashboardPage();
            } else if (role == 'teacher') {
              return const TeacherDashboardPage();
            }
          }
        }

        // Default to LoginPage if token is null or role is invalid
        return const LoginPage();
      },
    );
  }
}
