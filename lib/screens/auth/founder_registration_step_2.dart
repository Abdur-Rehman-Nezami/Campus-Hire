import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/startup_model.dart';
import '../home/founder_shell.dart';

class FounderRegistrationStep2Screen extends StatefulWidget {
  final String name;
  final String email;
  final String password;
  final String university;

  const FounderRegistrationStep2Screen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.university,
  });

  @override
  State<FounderRegistrationStep2Screen> createState() => _FounderRegistrationStep2ScreenState();
}

class _FounderRegistrationStep2ScreenState extends State<FounderRegistrationStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _startupNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedSector;
  String? _selectedStage;
  bool _isLoading = false;

  final List<String> _sectors = [
    'EdTech', 'FinTech', 'HealthTech', 'E-commerce', 'AI/ML', 'Web3', 'SaaS', 'Other'
  ];

  final List<String> _stages = ['Idea', 'MVP', 'Revenue'];

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final userId = userCredential.user!.uid;
      final startupId = FirebaseFirestore.instance.collection('startups').doc().id;

      final startupModel = StartupModel(
        startupId: startupId,
        founderId: userId,
        name: _startupNameController.text.trim(),
        tagline: _taglineController.text.trim(),
        description: _descriptionController.text.trim(),
        sector: _selectedSector!,
        stage: _selectedStage!,
        university: widget.university,
        createdAt: DateTime.now(),
      );

      final userModel = UserModel(
        userId: userId,
        name: widget.name,
        email: widget.email,
        university: widget.university,
        skills: [], // Founders don't strictly need skills in this flow, but array exists
        role: 'founder',
        startupId: startupId,
        createdAt: DateTime.now(),
      );

      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('users').doc(userId), userModel.toMap());
      batch.set(FirebaseFirestore.instance.collection('startups').doc(startupId), startupModel.toMap());
      await batch.commit();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FounderShell()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Startup Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _startupNameController,
                  decoration: const InputDecoration(labelText: 'Startup Name', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taglineController,
                  decoration: const InputDecoration(labelText: 'Tagline (max 80 chars)', border: OutlineInputBorder()),
                  maxLength: 80,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Sector', border: OutlineInputBorder()),
                  value: _selectedSector,
                  items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedSector = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Stage', border: OutlineInputBorder()),
                  value: _selectedStage,
                  items: _stages.map((s) => DropdownMenuItem(value: s.toLowerCase(), child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedStage = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (max 500 chars)', border: OutlineInputBorder()),
                  maxLines: 5,
                  maxLength: 500,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
