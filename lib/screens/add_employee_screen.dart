import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/schedule_model.dart';

/// Admin-only: creates a new employee/student profile directly (no
/// self-signup needed). Allows setting schedule/shift times related to My Calendar,
/// and system auto-generates a login email + temporary password.
class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();

  String _gender = 'Male';
  String _orgType = 'Workplace'; // 'School' or 'Workplace'
  String? _branchId;
  final List<String> _selectedScheduleIds = [];
  bool _saving = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _formatDays(List<int> weekdays) {
    if (weekdays.length == 7) return 'Everyday';
    if (weekdays.length == 5 && weekdays.contains(1) && weekdays.contains(5)) return 'Mon - Fri';
    return weekdays.map((d) => _dayNames[(d - 1).clamp(0, 6)]).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Basic Info
            Text('Basic info', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _idCtrl,
              decoration: const InputDecoration(labelText: 'ID / Employee number'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              onChanged: (v) => setState(() => _gender = v ?? 'Male'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', hintText: 'For admin to call directly'),
            ),
            const SizedBox(height: 24),

            // 2. Organization Context
            Text('Organization', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'School', label: Text('School')),
                ButtonSegment(value: 'Workplace', label: Text('Workplace')),
              ],
              selected: {_orgType},
              onSelectionChanged: (s) => setState(() => _orgType = s.first),
            ),
            const SizedBox(height: 12),
            if (_orgType == 'School') ...[
              TextFormField(controller: _classCtrl, decoration: const InputDecoration(labelText: 'Class')),
              const SizedBox(height: 12),
              TextFormField(controller: _groupCtrl, decoration: const InputDecoration(labelText: 'Group')),
              const SizedBox(height: 12),
              TextFormField(controller: _roomCtrl, decoration: const InputDecoration(labelText: 'Room')),
              const SizedBox(height: 12),
              TextFormField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
            ] else ...[
              TextFormField(controller: _deptCtrl, decoration: const InputDecoration(labelText: 'Department')),
              const SizedBox(height: 12),
              TextFormField(controller: _positionCtrl, decoration: const InputDecoration(labelText: 'Position')),
            ],
            if (state.branches.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _branchId,
                decoration: const InputDecoration(labelText: 'Branch / location'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No branch')),
                  for (final b in state.branches) DropdownMenuItem<String?>(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => _branchId = v),
              ),
            ],
            const SizedBox(height: 24),

            // 3. Schedule / Shift Time (My Calendar Relation)
            Row(
              children: [
                const Icon(Icons.event_note, size: 20, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(
                  'Set Time / Schedule (My Calendar)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4F46E5),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select schedule(s) from My Calendar (e.g. Morning Homeroom, Work Shifts) to assign to this person:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            if (state.schedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No schedules created yet in My Calendar. You can add schedules later from Dashboard -> Schedules.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < state.schedules.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildScheduleTile(state.schedules[i]),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // 4. Submit Button
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add),
              label: const Text('Create employee & generate login'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTile(ScheduleItem s) {
    final isSelected = _selectedScheduleIds.contains(s.id);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _selectedScheduleIds.add(s.id);
          } else {
            _selectedScheduleIds.remove(s.id);
          }
        });
      },
      title: Text(
        s.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${_formatDays(s.weekdays)} • ${s.startTime} - ${s.endTime}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
          if (s.className != null || s.department != null || s.room != null)
            Text(
              [
                if (s.className != null) s.className,
                if (s.department != null) s.department,
                if (s.room != null) 'Room ${s.room}',
              ].join(' • '),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
        ],
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.schedule,
          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final state = context.read<AppState>();
    final result = await state.createEmployeeByAdmin(
      identificationNumber: _idCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      gender: _gender,
      phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      className: _orgType == 'School' && _classCtrl.text.trim().isNotEmpty ? _classCtrl.text.trim() : null,
      group: _orgType == 'School' && _groupCtrl.text.trim().isNotEmpty ? _groupCtrl.text.trim() : null,
      room: _orgType == 'School' && _roomCtrl.text.trim().isNotEmpty ? _roomCtrl.text.trim() : null,
      subject: _orgType == 'School' && _subjectCtrl.text.trim().isNotEmpty ? _subjectCtrl.text.trim() : null,
      department: _orgType == 'Workplace' && _deptCtrl.text.trim().isNotEmpty ? _deptCtrl.text.trim() : null,
      position: _orgType == 'Workplace' && _positionCtrl.text.trim().isNotEmpty ? _positionCtrl.text.trim() : null,
      branchId: _branchId,
      assignedScheduleIds: _selectedScheduleIds,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the employee. Please try again.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Employee created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Give these login details to the employee — they won\'t be shown again:'),
            const SizedBox(height: 14),
            _credentialRow('Login email', result.loginEmail),
            const SizedBox(height: 8),
            _credentialRow('Temporary password', result.temporaryPassword),
            const SizedBox(height: 14),
            Text(
              'This is not a real mailbox — it\'s only used to sign in to this app. The employee should register their face after their first login.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
