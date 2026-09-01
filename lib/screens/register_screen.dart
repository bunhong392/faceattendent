import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/app_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  String _gender = 'Male';
  String _orgType = 'School'; // School or Workplace
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final err = await state.registerUser(
      identificationNumber: _idCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      gender: _gender,
      role: UserRole.member,
      className: _orgType == 'School' ? _classCtrl.text.trim() : null,
      room: _orgType == 'School' && _roomCtrl.text.trim().isNotEmpty ? _roomCtrl.text.trim() : null,
      department: _orgType == 'Workplace' ? _deptCtrl.text.trim() : null,
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Please sign in, then register your face profile.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'School', label: Text('School')),
                    ButtonSegment(value: 'Workplace', label: Text('Workplace')),
                  ],
                  selected: {_orgType},
                  onSelectionChanged: (s) => setState(() => _orgType = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _idCtrl,
                  decoration: InputDecoration(labelText: _orgType == 'School' ? 'Student ID' : 'Employee ID'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 12),
                if (_orgType == 'School') ...[
                  TextFormField(
                    controller: _classCtrl,
                    decoration: const InputDecoration(labelText: 'Class / Group (e.g. Grade 10-A)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _roomCtrl,
                    decoration: const InputDecoration(labelText: 'Room (optional)'),
                  ),
                ] else
                  TextFormField(
                    controller: _deptCtrl,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
