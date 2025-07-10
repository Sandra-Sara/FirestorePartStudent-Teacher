import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'login.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  _LeavePageState createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  String? _name;
  String? _department;
  String? _userId;
  bool _isLoading = true;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _reasonController.dispose();
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
          _name = userData['name'] ?? 'N/A';
          _department = userData['department'] ?? 'N/A';
          _userId = userId;
        });
        await _fetchLeaveRequests();
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

  Future<void> _fetchLeaveRequests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('studentId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _leaveRequests = snapshot.docs
            .map((doc) => {
                  'reason': doc['reason'] ?? 'N/A',
                  'startDate': doc['startDate'] ?? 'N/A',
                  'endDate': doc['endDate'] ?? 'N/A',
                  'status': doc['status'] ?? 'pending',
                  'timestamp': doc['timestamp'] != null
                      ? (doc['timestamp'] as Timestamp).toDate().toString()
                      : 'N/A',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching leave requests: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Fetch leave requests error: $e');
      }
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'studentId': _userId,
        'studentName': _name,
        'department': _department,
        'reason': _reasonController.text,
        'startDate': _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        'endDate': _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted successfully')),
      );

      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });
      await _fetchLeaveRequests();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting leave request: $e';
      });
      if (kDebugMode) {
        print('Submit leave request error: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Leave Application'),
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
                                'Leave Application',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _reasonController,
                                        decoration: const InputDecoration(
                                          labelText: 'Reason for Leave',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 3,
                                        validator: (value) =>
                                            value!.isEmpty ? 'Enter reason for leave' : null,
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: 'Start Date',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.calendar_today),
                                            onPressed: () => _selectDate(context, true),
                                          ),
                                        ),
                                        controller: TextEditingController(
                                          text: _startDate != null
                                              ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                              : '',
                                        ),
                                        validator: (value) =>
                                            _startDate == null ? 'Select start date' : null,
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: 'End Date',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.calendar_today),
                                            onPressed: () => _selectDate(context, false),
                                          ),
                                        ),
                                        controller: TextEditingController(
                                          text: _endDate != null
                                              ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                              : '',
                                        ),
                                        validator: (value) =>
                                            _endDate == null ? 'Select end date' : null,
                                      ),
                                      const SizedBox(height: 20),
                                      Center(
                                        child: ElevatedButton(
                                          onPressed: _submitLeaveRequest,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            minimumSize: const Size(200, 50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 5,
                                          ),
                                          child: const Text(
                                            'Submit Request',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
                            const SizedBox(height: 20),
                            const Text(
                              'Leave Request History',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 10),
                            _leaveRequests.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No leave requests found.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _leaveRequests.length,
                                    itemBuilder: (context, index) {
                                      final request = _leaveRequests[index];
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
                                                'Reason: ${request['reason']}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Start Date: ${request['startDate']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'End Date: ${request['endDate']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Status: ${request['status'][0].toUpperCase() + request['status'].substring(1)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: request['status'] == 'approved'
                                                      ? Colors.green
                                                      : request['status'] == 'rejected'
                                                          ? Colors.red
                                                          : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Submitted: ${request['timestamp']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
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
