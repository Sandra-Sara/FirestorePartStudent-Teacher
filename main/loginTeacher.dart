import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dashboard_page.dart';
import 'teacher_dashboard_page.dart';
import 'signup_teacher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _hashEmail(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final firestore = FirebaseFirestore.instance;
        final email = _emailController.text.trim().toLowerCase();
        final password = _passwordController.text;
        final userId = _hashEmail(email);

        // Check if user exists in Firestore
        final userDoc = await firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          if (userData['password'] == password && userData['role'] == _selectedRole) {
            // Store token and role in SharedPreferences for session
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', 'mock_token_$userId');
            await prefs.setString('user_role', _selectedRole);

            // Navigate based on role
            if (_selectedRole == 'student') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardPage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TeacherDashboardPage()),
              );
            }
          } else {
            setState(() {
              _errorMessage = 'Invalid email, password, or role';
            });
          }
        } else {
          // Create new user in Firestore
          await firestore.collection('users').doc(userId).set({
            'email': email,
            'password': password, // In production, hash the password
            'role': _selectedRole,
            'name': 'User_${email.split('@')[0]}', // Default name
            _selectedRole == 'student' ? 'reg' : 'teacherId': 'ID_$userId',
          });

          // Store token and role in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', 'mock_token_$userId');
          await prefs.setString('user_role', _selectedRole);

          // Navigate based on role
          if (_selectedRole == 'student') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TeacherDashboardPage()),
            );
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
        if (kDebugMode) {
          print('Login error: $e');
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
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
                  children: [
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text('Teacher'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Login'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpTeacherPage()),
                        );
                      },
                      child: const Text('New teacher? Sign Up'),
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
