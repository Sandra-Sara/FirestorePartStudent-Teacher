import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'login.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String? _department;
  String? _userId;
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedType = 'All';
  List<Map<String, dynamic>> _notifications = [];
  final List<String> _notificationTypes = ['All', 'System', 'Personal'];

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
        });
        await _fetchNotifications();
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

  Future<void> _fetchNotifications() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true);

      if (_selectedType == 'System') {
        query = query.where('type', isEqualTo: 'system').where('department', isEqualTo: _department);
      } else if (_selectedType == 'Personal') {
        query = query.where('type', isEqualTo: 'personal').where('recipientId', isEqualTo: _userId);
      } else {
        query = query.where('recipientId', isEqualTo: _userId);
        final systemQuery = FirebaseFirestore.instance
            .collection('notifications')
            .where('type', isEqualTo: 'system')
            .where('department', isEqualTo: _department)
            .orderBy('timestamp', descending: true);
        final personalSnapshot = await query.get();
        final systemSnapshot = await systemQuery.get();
        setState(() {
          _notifications = [
            ...personalSnapshot.docs.map((doc) => {
                  'title': doc['title'] ?? 'N/A',
                  'message': doc['message'] ?? 'N/A',
                  'type': doc['type'] ?? 'N/A',
                  'timestamp': doc['timestamp'] != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format((doc['timestamp'] as Timestamp).toDate())
                      : 'N/A',
                }),
            ...systemSnapshot.docs.map((doc) => {
                  'title': doc['title'] ?? 'N/A',
                  'message': doc['message'] ?? 'N/A',
                  'type': doc['type'] ?? 'N/A',
                  'timestamp': doc['timestamp'] != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format((doc['timestamp'] as Timestamp).toDate())
                      : 'N/A',
                }),
          ];
          _notifications.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
          _isLoading = false;
        });
        return;
      }

      final snapshot = await query.get();
      setState(() {
        _notifications = snapshot.docs
            .map((doc) => {
                  'title': doc['title'] ?? 'N/A',
                  'message': doc['message'] ?? 'N/A',
                  'type': doc['type'] ?? 'N/A',
                  'timestamp': doc['timestamp'] != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format((doc['timestamp'] as Timestamp).toDate())
                      : 'N/A',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching notifications: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Fetch notifications error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Notifications'),
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
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Filter Notifications',
                                labelStyle: TextStyle(color: Colors.white),
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white24,
                              ),
                              items: _notificationTypes
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value;
                                  _isLoading = true;
                                });
                                _fetchNotifications();
                              },
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 20),
                            _notifications.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No notifications available.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _notifications.length,
                                    itemBuilder: (context, index) {
                                      final notification = _notifications[index];
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
                                                notification['title'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                notification['message'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Type: ${notification['type'][0].toUpperCase() + notification['type'].substring(1)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: notification['type'] == 'system'
                                                      ? Colors.blue
                                                      : Colors.green,
                                                ),
                                              ),
                                              Text(
                                                'Time: ${notification['timestamp']}',
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
