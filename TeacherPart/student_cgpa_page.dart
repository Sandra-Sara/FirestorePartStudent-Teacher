import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';

class StudentCgpaPage extends StatefulWidget {
  const StudentCgpaPage({super.key});

  @override
  _StudentCgpaPageState createState() => _StudentCgpaPageState();
}

class _StudentCgpaPageState extends State<StudentCgpaPage> {
  String? _userId;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _gradeRecords = [];
  double? _cgpa;

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

      await _fetchGrades();
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

  Future<void> _fetchGrades() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('grades')
          .where('studentId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _gradeRecords = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'courseId': data['courseId'] ?? 'N/A',
            'semester': data['semester'] ?? 'N/A',
            'grade': data['grade'] ?? 'N/A',
            'gradePoint': data['gradePoint']?.toDouble() ?? 0.0,
            'credits': data['credits']?.toDouble() ?? 0.0,
          };
        }).toList();

        // Calculate CGPA
        if (_gradeRecords.isNotEmpty) {
          double totalGradePoints = 0.0;
          double totalCredits = 0.0;
          for (var record in _gradeRecords) {
            totalGradePoints += record['gradePoint'] * record['credits'];
            totalCredits += record['credits'];
          }
          _cgpa = totalCredits > 0 ? (totalGradePoints / totalCredits) : 0.0;
        } else {
          _cgpa = null;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching grades: $e';
      });
      if (kDebugMode) {
        print('Fetch grades error: $e');
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
        title: const Text('My CGPA'),
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
                            'My CGPA and Grades',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'CGPA: ${_cgpa != null ? _cgpa!.toStringAsFixed(2) : 'N/A'}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          if (_gradeRecords.isEmpty)
                            const Text(
                              'No grade records found.',
                              style: TextStyle(fontSize: 16),
                            )
                          else
                            Column(
                              children: [
                                const Text(
                                  'Course Grades:',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                Table(
                                  border: TableBorder.all(color: Colors.grey),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(2),
                                    2: FlexColumnWidth(1),
                                    3: FlexColumnWidth(1),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(color: Colors.blue.shade100),
                                      children: const [
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Course',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Semester',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Grade',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Credits',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ..._gradeRecords.map((record) {
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(record['courseId']),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(record['semester']),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(record['grade']),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(record['credits'].toString()),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
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
