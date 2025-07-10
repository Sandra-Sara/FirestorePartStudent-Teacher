import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'login.dart';

class ClassworkPage extends StatefulWidget {
  const ClassworkPage({super.key});

  @override
  _ClassworkPageState createState() => _ClassworkPageState();
}

class _ClassworkPageState extends State<ClassworkPage> {
  String? _department;
  String? _userId;
  String? _name;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _assignments = [];
  String? _selectedCourseId;
  List<String> _courseIds = ['All'];

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
          _userId = userId;
          _name = userData['name'] ?? 'N/A';
        });
        await _fetchAssignments();
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

  Future<void> _fetchAssignments() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('classwork_assignments')
          .where('department', isEqualTo: _department)
          .orderBy('dueDate', descending: false);

      if (_selectedCourseId != null && _selectedCourseId != 'All') {
        query = query.where('courseId', isEqualTo: _selectedCourseId);
      }

      final snapshot = await query.get();
      final assignments = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'courseId': doc['courseId'] ?? 'N/A',
                'courseName': doc['courseName'] ?? 'N/A',
                'title': doc['title'] ?? 'N/A',
                'description': doc['description'] ?? 'N/A',
                'dueDate': doc['dueDate'] ?? 'N/A',
                'submissionStatus': 'Not Submitted',
                'grade': null,
              })
          .toList();

      // Fetch unique course IDs
      final courseIds = ['All'] +
          snapshot.docs
              .map((doc) => doc['courseId'] as String)
              .toSet()
              .toList()
              .cast<String>();

      // Check submission status
      for (var assignment in assignments) {
        final submissionSnapshot = await FirebaseFirestore.instance
            .collection('classwork_submissions')
            .where('assignmentId', isEqualTo: assignment['id'])
            .where('studentId', isEqualTo: _userId)
            .limit(1)
            .get();

        if (submissionSnapshot.docs.isNotEmpty) {
          final submission = submissionSnapshot.docs.first.data();
          assignment['submissionStatus'] = submission['status'] ?? 'Submitted';
          assignment['grade'] = submission['grade'];
        }
      }

      setState(() {
        _assignments = assignments;
        _courseIds = courseIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching assignments: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Fetch assignments error: $e');
      }
    }
  }

  void _showSubmissionDialog(String assignmentId, String title, String courseId) {
    final TextEditingController submissionTextController = TextEditingController();
    final TextEditingController submissionUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit Assignment: $title ($courseId)'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: submissionTextController,
                  decoration: const InputDecoration(
                    labelText: 'Submission Text (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: submissionUrlController,
                  decoration: const InputDecoration(
                    labelText: 'File URL (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value!.isEmpty && submissionTextController.text.isEmpty) {
                      return 'Provide either text or URL';
                    }
                    if (value.isNotEmpty &&
                        !RegExp(r'^(https?:\/\/[^\s$.?#].[^\s]*)$').hasMatch(value)) {
                      return 'Enter a valid URL';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _isLoading = true;
                });
                try {
                  await FirebaseFirestore.instance.collection('classwork_submissions').add({
                    'assignmentId': assignmentId,
                    'studentId': _userId,
                    'studentName': _name,
                    'submissionText': submissionTextController.text,
                    'submissionUrl': submissionUrlController.text,
                    'status': 'pending',
                    'grade': null,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Submission successful')),
                  );
                  await _fetchAssignments();
                } catch (e) {
                  setState(() {
                    _errorMessage = 'Error submitting assignment: $e';
                    _isLoading = false;
                  });
                  if (kDebugMode) {
                    print('Submit assignment error: $e');
                  }
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Classwork'),
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
                                'Classwork',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedCourseId,
                              decoration: const InputDecoration(
                                labelText: 'Select Course',
                                labelStyle: TextStyle(color: Colors.white),
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white24,
                              ),
                              items: _courseIds
                                  .map((courseId) => DropdownMenuItem(
                                        value: courseId,
                                        child: Text(
                                          courseId,
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCourseId = value;
                                  _isLoading = true;
                                });
                                _fetchAssignments();
                              },
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            _assignments.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No assignments available.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _assignments.length,
                                    itemBuilder: (context, index) {
                                      final assignment = _assignments[index];
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
                                                '${assignment['courseId']} - ${assignment['courseName']}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Title: ${assignment['title']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Description: ${assignment['description']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Due Date: ${assignment['dueDate']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Status: ${assignment['submissionStatus']}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: assignment['submissionStatus'] == 'pending'
                                                      ? Colors.orange
                                                      : assignment['submissionStatus'] == 'graded'
                                                          ? Colors.green
                                                          : Colors.black87,
                                                ),
                                              ),
                                              if (assignment['grade'] != null)
                                                Text(
                                                  'Grade: ${assignment['grade']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              const SizedBox(height: 10),
                                              if (assignment['submissionStatus'] == 'Not Submitted')
                                                ElevatedButton(
                                                  onPressed: () => _showSubmissionDialog(
                                                    assignment['id'],
                                                    assignment['title'],
                                                    assignment['courseId'],
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Submit Assignment',
                                                    style: TextStyle(color: Colors.white),
                                                  ),
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
