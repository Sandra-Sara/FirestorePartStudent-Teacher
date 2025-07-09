import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  _StudentAttendancePageState createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  String? _userId;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  String _hashEmail(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _initializeUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final role = prefs.getString('user_role');

      if (token == null || role != 'student') {
        setState(() {
          _errorMessage = 'Invalid session or not a student. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userId = token.replaceFirst('mock_token_', '');
      });

      await _fetchStudentAttendance();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Initialization error: $e');
      }
    }
  }

  Future<void> _fetchStudentAttendance() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _attendanceRecords = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'courseId': data['courseId'] ?? 'N/A',
            'date': (data['date'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? 'N/A',
            'status': data['status'] ?? 'Unknown',
          };
        }).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching attendance: $e';
      });
      if (kDebugMode) {
        print('Fetch attendance error: $e');
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Attendance Records',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_attendanceRecords.isEmpty)
                            const Text(
                              'No attendance records found.',
                              style: TextStyle(fontSize: 16),
                            )
                          else
                            ..._attendanceRecords.map((record) {
                              return ListTile(
                                title: Text('Course: ${record['courseId']}'),
                                subtitle: Text('Date: ${record['date']} | Status: ${record['status']}'),
                                trailing: Icon(
                                  record['status'] == 'present' ? Icons.check_circle : Icons.cancel,
                                  color: record['status'] == 'present' ? Colors.green : Colors.red,
                                ),
                              );
                            }),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: Colors.blue,
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
