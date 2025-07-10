import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';

class ExamSchedulePage extends StatefulWidget {
  const ExamSchedulePage({super.key});

  @override
  _ExamSchedulePageState createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  String? _department;
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedSemester;
  List<Map<String, dynamic>> _examSchedules = [];
  List<String> _semesters = ['All', 'Spring 2025', 'Fall 2025', 'Spring 2026', 'Fall 2026'];

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        return;
      }

      final userId = token.replaceFirst('mock_token_', '');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data()!['role'] == 'student') {
        final userData = userDoc.data()!;
        setState(() {
          _department = userData['department'] ?? 'N/A';
        });
        await _fetchExamSchedules();
      } else {
        setState(() {
          _errorMessage = 'Student profile not found or invalid role.';
          _isLoading = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
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

  Future<void> _fetchExamSchedules() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('exam_schedules')
          .where('department', isEqualTo: _department);

      if (_selectedSemester != null && _selectedSemester != 'All') {
        query = query.where('semester', isEqualTo: _selectedSemester);
      }

      final snapshot = await query.get();
      setState(() {
        _examSchedules = snapshot.docs
            .map((doc) => {
                  'courseId': doc['courseId'] ?? 'N/A',
                  'courseName': doc['courseName'] ?? 'N/A',
                  'date': doc['date'] ?? 'N/A',
                  'time': doc['time'] ?? 'N/A',
                  'venue': doc['venue'] ?? 'N/A',
                  'semester': doc['semester'] ?? 'N/A',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching exam schedules: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Fetch exam schedules error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Exam Schedule'),
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blueAccent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/dulogo.png',
                                height: 150,
                                width: 300,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.error,
                                  size: 100,
                                  color: Colors.white70,
                                ),
                              ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.8, end: 1.0),
                            ),
                            const SizedBox(height: 20),
                            const Center(
                              child: Text(
                                'University Of Dhaka',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            const Center(
                              child: Text(
                                'Exam Schedule',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedSemester,
                              decoration: const InputDecoration(
                                labelText: 'Select Semester',
                                labelStyle: TextStyle(color: Colors.white),
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white24,
                              ),
                              items: _semesters
                                  .map((semester) => DropdownMenuItem(
                                        value: semester,
                                        child: Text(
                                          semester,
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSemester = value;
                                  _isLoading = true;
                                });
                                _fetchExamSchedules();
                              },
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            _examSchedules.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No exam schedules available.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _examSchedules.length,
                                    itemBuilder: (context, index) {
                                      final schedule = _examSchedules[index];
                                      return Card(
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Course: ${schedule['courseId']} - ${schedule['courseName']}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Date: ${schedule['date']}',
                                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                              ),
                                              Text(
                                                'Time: ${schedule['time']}',
                                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                              ),
                                              Text(
                                                'Venue: ${schedule['venue']}',
                                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                              ),
                                              Text(
                                                'Semester: ${schedule['semester']}',
                                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.2, end: 0);
                                    },
                                  ),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: const Size(200, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  'Back',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 800.ms),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
