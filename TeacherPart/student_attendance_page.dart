import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? user?.email ?? 'unknown';
    try {
      // Load from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('student_attendance')
          .doc(userId)
          .collection('CSE2201')
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          students = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': doc.data()['name'] as String,
              'attendance': doc.data()['attendance'] as int,
            };
          }).toList();
        });
      } else {
        // Fallback to SharedPreferences or default data
        final prefs = await SharedPreferences.getInstance();
        final studentData = prefs.getStringList('students') ?? [];
        setState(() {
          students = studentData.map((data) {
            final parts = data.split(':');
            return {
              'id': null,
              'name': parts[0],
              'attendance': int.parse(parts[1]),
            };
          }).toList();
          if (students.isEmpty) {
            students = [
              {'id': null, 'name': 'Anisha Tabassum', 'attendance': 85},
              {'id': null, 'name': 'Atiya Fahmida', 'attendance': 60},
              {'id': null, 'name': 'Biplop Pal', 'attendance': 45},
              {'id': null, 'name': 'Sara Faria', 'attendance': 92},
            ];
            _saveStudents();
          }
        });
      }
    } catch (e) {
      print('Error loading students from Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final studentData = prefs.getStringList('students') ?? [];
      setState(() {
        students = studentData.map((data) {
          final parts = data.split(':');
          return {
            'id': null,
            'name': parts[0],
            'attendance': int.parse(parts[1]),
          };
        }).toList();
        if (students.isEmpty) {
          students = [
            {'id': null, 'name': 'Anisha Tabassum', 'attendance': 85},
            {'id': null, 'name': 'Atiya Fahmida', 'attendance': 60},
            {'id': null, 'name': 'Biplop Pal', 'attendance': 45},
            {'id': null, 'name': 'Sara Faria', 'attendance': 92},
          ];
          _saveStudents();
        }
      });
    }
  }

  Future<void> _saveStudents() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? user?.email ?? 'unknown';
    try {
      // Save to Firestore
      final batch = FirebaseFirestore.instance.batch();
      for (var student in students) {
        final docRef = FirebaseFirestore.instance
            .collection('student_attendance')
            .doc(userId)
            .collection('CSE2201')
            .doc(student['id'] ?? student['name'].replaceAll(' ', '_'));
        batch.set(docRef, {
          'name': student['name'],
          'attendance': student['attendance'],
        });
      }
      await batch.commit();

      // Save to SharedPreferences as a local cache
      final prefs = await SharedPreferences.getInstance();
      final studentData = students.map((student) => '${student['name']}:${student['attendance']}').toList();
      await prefs.setStringList('students', studentData);
    } catch (e) {
      print('Error saving students to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving students: $e')),
      );
    }
  }

  Future<void> _logAttendanceUpdate(String studentName, int newAttendance) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance.collection('attendance_logs').add({
        'email': user?.email ?? 'unknown',
        'student_name': studentName,
        'new_attendance': newAttendance,
        'timestamp': FieldValue.serverTimestamp(),
        'course': 'CSE2201',
      });
    } catch (e) {
      print('Error logging attendance update: $e');
    }
  }

  void updateAttendance(int index, bool increase) {
    setState(() {
      final student = students[index];
      final newAttendance = increase
          ? (student['attendance'] + 5).clamp(0, 100)
          : (student['attendance'] - 5).clamp(0, 100);
      students[index]['attendance'] = newAttendance;
      _saveStudents();
      _logAttendanceUpdate(student['name'], newAttendance);
    });
  }

  void addStudent(String name, int attendance) {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      students.add({'id': null, 'name': name, 'attendance': attendance});
      _saveStudents();
      _logAttendanceUpdate(name, attendance);
    });
  }

  void showAddStudentDialog() {
    String newName = '';
    String attendanceText = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Student Name'),
              onChanged: (value) => newName = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Attendance (%)'),
              keyboardType: TextInputType.number,
              onChanged: (value) => attendanceText = value,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newName.isNotEmpty && int.tryParse(attendanceText) != null) {
                final attendance = int.parse(attendanceText).clamp(0, 100);
                addStudent(newName, attendance);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid name and attendance')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Color getAttendanceColor(int percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset(
                    'assets/dulogo.png',
                    height: 150,
                    width: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100, color: Colors.white70),
                  ).animate().fadeIn(duration: 800.ms),
                  const SizedBox(height: 20),
                  const Text(
                    'University Of Dhaka',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Class Attendance - CSE 2201',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final name = student['name'] as String;
                          final attendance = student['attendance'] as int;
                          return ListTile(
                            leading: Text('${index + 1}', style: const TextStyle(fontSize: 18)),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$attendance%', style: TextStyle(fontSize: 16, color: getAttendanceColor(attendance))),
                                const SizedBox(width: 10),
                                IconButton(icon: const Icon(Icons.remove), onPressed: () => updateAttendance(index, false)),
                                IconButton(icon: const Icon(Icons.add), onPressed: () => updateAttendance(index, true)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5, end: 0),
                  const SizedBox(height: 20),
                  ElevatedButton(
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
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddStudentDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        tooltip: 'Add Student',
      ).animate().fadeIn(duration: 800.ms),
    );
  }
}
