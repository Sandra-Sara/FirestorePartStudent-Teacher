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
  String? _userRole;
  String? _userId;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  final _courseIdController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _courseIdController.dispose();
    super.dispose();
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

      if (token == null || role == null) {
        setState(() {
          _errorMessage = 'Invalid session. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userRole = role;
        _userId = token.replaceFirst('mock_token_', '');
      });

      if (_userRole == 'teacher') {
        await _fetchStudents();
      } else {
        await _fetchStudentAttendance();
      }

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

  Future<void> _fetchStudents() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      setState(() {
        _students = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': doc.id,
            'name': data['name'] ?? 'Unknown',
            'reg': data['reg'] ?? 'N/A',
            'isPresent': false, // Default for attendance marking
          };
        }).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching students: $e';
      });
      if (kDebugMode) {
        print('Fetch students error: $e');
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
            'date': (data['date'] as Timestamp?)?.toDate().toString() ?? 'N/A',
            'status': data['status'] ?? 'Unknown',
            'markedBy': data['markedBy'] ?? 'Unknown',
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

  Future<void> _markAttendance(String studentId, String studentName, bool isPresent) async {
    if (_courseIdController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a course ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance.collection('attendance').add({
        'studentId': studentId,
        'courseId': _courseIdController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'status': isPresent ? 'present' : 'absent',
        'markedBy': _userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance marked for $studentName')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error marking attendance: $e';
      });
      if (kDebugMode) {
        print('Mark attendance error: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2026),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userRole == 'teacher' ? 'Mark Attendance' : 'My Attendance'),
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
                          Text(
                            _userRole == 'teacher' ? 'Mark Attendance' : 'My Attendance Records',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_userRole == 'teacher') ...[
                            TextFormField(
                              controller: _courseIdController,
                              decoration: const InputDecoration(
                                labelText: 'Course ID (e.g., CSE 2201)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.book),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a course ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Date: ${_selectedDate.toString().substring(0, 10)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                ElevatedButton(
                                  onPressed: () => _selectDate(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text(
                                    'Select Date',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Students:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ..._students.map((student) {
                              return ListTile(
                                title: Text(student['name']),
                                subtitle: Text('Reg: ${student['reg']}'),
                                trailing: Switch(
                                  value: student['isPresent'],
                                  onChanged: (value) {
                                    setState(() {
                                      student['isPresent'] = value;
                                    });
                                    _markAttendance(student['userId'], student['name'], value);
                                  },
                                  activeColor: Colors.blue,
                                ),
                              );
                            }),
                          ] else ...[
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
                          ],
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
