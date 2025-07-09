import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  _TeacherProfilePageState createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _email;
  String? _teacherId;
  String? _department;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  final _nameController = TextEditingController();
  final _teacherIdController = TextEditingController();
  final _departmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeacherProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  String _hashEmail(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _fetchTeacherProfile() async {
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
          _errorMessage = 'Invalid session. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final userId = token.replaceFirst('mock_token_', '');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data()!['role'] == 'teacher') {
        final userData = userDoc.data()!;
        setState(() {
          _name = userData['name'];
          _email = userData['email'];
          _teacherId = userData['teacherId'];
          _department = userData['department'];
          _nameController.text = _name ?? '';
          _teacherIdController.text = _teacherId ?? '';
          _departmentController.text = _department ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Teacher profile not found or invalid role.';
          _isLoading = false;
        });
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

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        final userId = token!.replaceFirst('mock_token_', '');

        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'name': _nameController.text.trim(),
          'teacherId': _teacherIdController.text.trim(),
          'department': _departmentController.text.trim(),
        });

        setState(() {
          _name = _nameController.text.trim();
          _teacherId = _teacherIdController.text.trim();
          _department = _departmentController.text.trim();
          _isEditing = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Error updating profile: $e';
          _isLoading = false;
        });
        if (kDebugMode) {
          print('Profile update error: $e');
        }
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
        title: const Text('Teacher Profile'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.blue)
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Teacher Profile',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _isEditing
                                  ? TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Full Name',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your full name';
                                        }
                                        return null;
                                      },
                                    )
                                  : Text(
                                      'Name: ${_name ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                              const SizedBox(height: 10),
                              Text(
                                'Email: ${_email ?? 'N/A'}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              _isEditing
                                  ? TextFormField(
                                      controller: _teacherIdController,
                                      decoration: const InputDecoration(
                                        labelText: 'Teacher ID',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.badge),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your teacher ID';
                                        }
                                        return null;
                                      },
                                    )
                                  : Text(
                                      'Teacher ID: ${_teacherId ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                              const SizedBox(height: 10),
                              _isEditing
                                  ? TextFormField(
                                      controller: _departmentController,
                                      decoration: const InputDecoration(
                                        labelText: 'Department',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.school),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your department';
                                        }
                                        return null;
                                      },
                                    )
                                  : Text(
                                      'Department: ${_department ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                              const SizedBox(height: 20),
                              if (_isEditing)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = false;
                                          _nameController.text = _name ?? '';
                                          _teacherIdController.text = _teacherId ?? '';
                                          _departmentController.text = _department ?? '';
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(150, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        backgroundColor: Colors.grey,
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _updateProfile,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(150, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        backgroundColor: Colors.blue,
                                      ),
                                      child: _isLoading
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text(
                                              'Save',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                    ),
                                  ],
                                )
                              else
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text(
                                    'Edit Profile',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              const SizedBox(height: 16),
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
                  ),
      ),
    );
  }
}
