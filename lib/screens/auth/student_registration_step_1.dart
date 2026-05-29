import 'package:flutter/material.dart';
import 'student_registration_step_2.dart';

class StudentRegistrationStep1Screen extends StatefulWidget {
  const StudentRegistrationStep1Screen({super.key});

  @override
  State<StudentRegistrationStep1Screen> createState() => _StudentRegistrationStep1ScreenState();
}

class _StudentRegistrationStep1ScreenState extends State<StudentRegistrationStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _uniController = TextEditingController();
  final _deptController = TextEditingController();
  String? _selectedYear;

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentRegistrationStep2Screen(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            university: _uniController.text.trim(),
            department: _deptController.text.trim(),
            yearOfStudy: _selectedYear!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'University Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _uniController,
                  decoration: const InputDecoration(labelText: 'University', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deptController,
                  decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Year of Study', border: OutlineInputBorder()),
                  value: _selectedYear,
                  items: const [
                    DropdownMenuItem(value: '1st', child: Text('1st Year')),
                    DropdownMenuItem(value: '2nd', child: Text('2nd Year')),
                    DropdownMenuItem(value: '3rd', child: Text('3rd Year')),
                    DropdownMenuItem(value: '4th', child: Text('4th Year')),
                    DropdownMenuItem(value: 'Graduated', child: Text('Graduated')),
                  ],
                  onChanged: (v) => setState(() => _selectedYear = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _onNext,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
