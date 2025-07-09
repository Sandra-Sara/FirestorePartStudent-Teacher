import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';

class DropUpdatePage extends StatefulWidget {
  const DropUpdatePage({super.key});

  @override
  _DropUpdatePageState createState() => _DropUpdatePageState();
}

class _DropUpdatePageState extends State<DropUpdatePage> {
  String? _userId;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _requestRecords = [];

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

      if (token == null || role != 'teacher') {
        setState(() {
          _errorMessage = 'Invalid session or not a teacher. Please log in again.';
          _isLoading = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        return;
      }

      setState(() {
        _userId = token.replaceFirst('mock_token_', '');
      });

      await _fetchRequests();
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

  Future<void> _fetchRequests() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('drop_update_requests')
          .where('teacherId', isEqualTo: _userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _requestRecords = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'requestId': doc.id,
            'studentName': data['studentName'] ?? 'N/A',
            'courseId': data['courseId'] ?? 'N/A',
            'semester': data['semester'] ?? 'N/A',
            'requestType': data['requestType'] ?? 'N/A',
            'reason': data['reason'] ?? 'No reason provided',
            'status': data['status'] ?? 'pending',
          };
        }).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching requests: $e';
      });
      if (kDebugMode) {
        print('Fetch requests error: $e');
      }
    }
  }

  Future<void> _updateRequestStatus(String requestId, String studentName, String status) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('drop_update_requests')
          .doc(requestId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$status request for $studentName')),
      );

      await _fetchRequests(); // Refresh the list
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating request: $e';
      });
      if (kDebugMode) {
        print('Update request error: $e');
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
                            const Text(
                              'Drop/Update Requests',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ).animate().fadeIn(duration: 800.ms),
                            const SizedBox(height: 20),
                            if (_requestRecords.isEmpty)
                              const Text(
                                'No pending requests found.',
                                style: TextStyle(fontSize: 16, color: Colors.white70),
                              ).animate().fadeIn(duration: 600.ms)
                            else
                              Column(
                                children: _requestRecords.map((record) {
                                  return Card(
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
                                            'Student: ${record['studentName']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Course: ${record['courseId']}'),
                                          Text('Semester: ${record['semester']}'),
                                          Text('Request: ${record['requestType']}'),
                                          Text('Reason: ${record['reason']}'),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () => _updateRequestStatus(
                                                  record['requestId'],
                                                  record['studentName'],
                                                  'approved',
                                                ),
                                                child: const Text(
                                                  'Approve',
                                                  style: TextStyle(color: Colors.green),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => _updateRequestStatus(
                                                  record['requestId'],
                                                  record['studentName'],
                                                  'rejected',
                                                ),
                                                child: const Text(
                                                  'Reject',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
                                }).toList(),
                              ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _logout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                minimumSize: const Size(double.infinity, 50),
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
