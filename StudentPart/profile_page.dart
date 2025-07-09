import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;
  Map<String, String> _profileData = {
    'Name': 'unknown',
    'Registration Number': 'N/A',
    'Department': 'N/A',
    'Email': 'N/A',
    'Phone': 'N/A',
    'Current Semester': 'N/A',
    'Attached Hall': 'N/A',
    'Percentage': '0%',
  };
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'Name': TextEditingController(),
      'Registration Number': TextEditingController(),
      'Department': TextEditingController(),
      'Email': TextEditingController(),
      'Phone': TextEditingController(),
      'Current Semester': TextEditingController(),
      'Attached Hall': TextEditingController(),
      'Percentage': TextEditingController(),
    };
    _initializeUser();
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
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

      setState(() {
        _userId = token.replaceFirst('mock_token_', '');
      });

      await _loadProfile();
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

  Future<void> _loadProfile() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();

      if (userDoc.exists && userDoc.data()!['role'] == 'student') {
        final userData = userDoc.data()!;
        setState(() {
          _profileData = {
            'Name': userData['name'] ?? 'unknown',
            'Registration Number': userData['reg'] ?? 'N/A',
            'Department': userData['department'] ?? 'N/A',
            'Email': userData['email'] ?? 'N/A',
            'Phone': userData['phone'] ?? 'N/A',
            'Current Semester': userData['currentSemester'] ?? 'N/A',
            'Attached Hall': userData['attachedHall'] ?? 'N/A',
            'Percentage': userData['percentage'] ?? '0%',
          };
          _controllers.forEach((key, controller) {
            controller.text = _profileData[key]!;
          });
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Student profile not found.';
          _isLoading = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Profile load error: $e');
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _controllers.forEach((key, controller) {
        _profileData[key] = controller.text.isNotEmpty ? controller.text : _profileData[key]!;
      });

      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'name': _profileData['Name'],
        'reg': _profileData['Registration Number'],
        'department': _profileData['Department'],
        'email': _profileData['Email'],
        'phone': _profileData['Phone'],
        'currentSemester': _profileData['Current Semester'],
        'attachedHall': _profileData['Attached Hall'],
        'percentage': _profileData['Percentage'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving profile: $e';
      });
      if (kDebugMode) {
        print('Profile save error: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        _saveProfile();
      }
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Student Profile'),
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
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/profile.png',
                                  height: 150,
                                  width: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 150,
                                      width: 150,
                                      color: Colors.grey,
                                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                                    );
                                  },
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
                                'Student Profile',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 30),
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
                                    ProfileInfoRow(
                                      label: 'Name',
                                      value: _profileData['Name']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Name']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Registration Number',
                                      value: _profileData['Registration Number']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Registration Number']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Department',
                                      value: _profileData['Department']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Department']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Email',
                                      value: _profileData['Email']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Email']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Phone',
                                      value: _profileData['Phone']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Phone']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Current Semester',
                                      value: _profileData['Current Semester']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Current Semester']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Attached Hall',
                                      value: _profileData['Attached Hall']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Attached Hall']!,
                                    ),
                                    ProfileInfoRow(
                                      label: 'Percentage',
                                      value: _profileData['Percentage']!,
                                      isEditing: _isEditing,
                                      controller: _controllers['Percentage']!,
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton(
                                onPressed: _toggleEdit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: const Size(200, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                ),
                                child: Text(
                                  _isEditing ? 'Save' : 'Edit',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 800.ms),
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

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController controller;

  const ProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isEditing,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  )
                : Text(
                    value,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
          ),
        ],
      ),
    );
  }
}
