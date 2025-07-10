import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';
import 'profile_page.dart';
import 'student_attendance_page.dart';
import 'student_cgpa_page.dart';
import 'student_class_routine_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  _StudentDashboardPageState createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  String? _name;
  String? _email;
  String? _reg;
  String? _department;
  bool _isLoading = true;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();
  final _courseIdController = TextEditingController();
  final _semesterController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _requestType;

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  @override
  void dispose() {
    _courseIdController.dispose();
    _semesterController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _hashEmail(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _fetchStudentProfile() async {
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
          _name = userData['name'];
          _email = userData['email'];
          _reg = userData['reg'];
          _department = userData['department'];
          _isLoading = false;
        });
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
        _errorMessage = 'Error fetching profile: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Profile fetch error: $e');
      }
    }
  }

  Future<void> _submitDropUpdateRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('token')?.replaceFirst('mock_token_', '');

      final routineSnapshot = await FirebaseFirestore.instance
          .collection('routines')
          .where('courseId', isEqualTo: _courseIdController.text)
          .limit(1)
          .get();
      final teacherId = routineSnapshot.docs.isNotEmpty
          ? routineSnapshot.docs.first.data()['teacherId']
          : 'default_teacher_id';

      await FirebaseFirestore.instance.collection('drop_update_requests').add({
        'studentId': userId,
        'studentName': _name ?? 'Unknown',
        'courseId': _courseIdController.text,
        'semester': _semesterController.text,
        'requestType': _requestType,
        'status': 'pending',
        'teacherId': teacherId,
        'reason': _reasonController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );

      _courseIdController.clear();
      _semesterController.clear();
      _reasonController.clear();
      setState(() {
        _requestType = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting request: $e';
      });
      if (kDebugMode) {
        print('Submit request error: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
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
                            const SizedBox(height: 20),
                            const Text(
                              'University Of Dhaka',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Welcome, ${_name ?? 'Student'}!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Name: ${_name ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Email: ${_email ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Reg No: ${_reg ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Department: ${_department ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.8, end: 1.0),
                            const SizedBox(height: 30),
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 16.0,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                OptionBox(
                                  option: 'Profile',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'Attendance',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const StudentAttendancePage()),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'CGPA',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const StudentCgpaPage()),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'Class Routine',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const StudentClassRoutinePage()),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'Exam Schedule',
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Exam Schedule Page not implemented')),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'Leave',
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Leave Page not implemented')),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'Notification',
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Notification Page not implemented')),
                                    );
                                  },
                                ),
                                OptionBox(
                                  option: 'Drop/Update Request',
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Submit Drop/Update Request'),
                                        content: Form(
                                          key: _formKey,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextFormField(
                                                  controller: _courseIdController,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Course ID',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  validator: (value) =>
                                                      value!.isEmpty ? 'Enter course ID' : null,
                                                ),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  controller: _semesterController,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Semester',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  validator: (value) =>
                                                      value!.isEmpty ? 'Enter semester' : null,
                                                ),
                                                const SizedBox(height: 10),
                                                DropdownButtonFormField<String>(
                                                  value: _requestType,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Request Type',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  items: ['drop', 'update']
                                                      .map((type) => DropdownMenuItem(
                                                            value: type,
                                                            child: Text(type[0].toUpperCase() + type.substring(1)),
                                                          ))
                                                      .toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _requestType = value;
                                                    });
                                                  },
                                                  validator: (value) =>
                                                      value == null ? 'Select request type' : null,
                                                ),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  controller: _reasonController,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Reason',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  maxLines: 3,
                                                  validator: (value) =>
                                                      value!.isEmpty ? 'Enter reason' : null,
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
                                            onPressed: _submitDropUpdateRequest,
                                            child: const Text('Submit'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.8, end: 1.0),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}

class OptionBox extends StatefulWidget {
  final String option;
  final Color textColor;
  final VoidCallback? onTap;

  const OptionBox({super.key, required this.option, this.textColor = Colors.blue, this.onTap});

  @override
  State<OptionBox> createState() => _OptionBoxState();
}

class _OptionBoxState extends State<OptionBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isTapped = true;
    });
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _isTapped = false;
        });
        if (widget.onTap != null) {
          widget.onTap!();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 150,
          width: 150,
          decoration: BoxDecoration(
            color: _isTapped ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.option,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isTapped ? Colors.white : widget.textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
