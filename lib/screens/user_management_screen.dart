import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_state.dart';
import '../models/user_model.dart';
import 'add_employee_screen.dart';

/// Admin-only screen for managing user profiles: search/filter, view details,
/// edit organizational fields (class/group/room/subject/department/position),
/// and remove a user's profile + face enrollment.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _query = '';
  String? _groupFilter; // combined class/department/group filter value

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Distinct set of class/group/department labels present among users,
    // used to build the filter chips.
    final groups = <String>{
      for (final u in state.users) ...[
        if (u.className != null && u.className!.isNotEmpty) u.className!,
        if (u.department != null && u.department!.isNotEmpty) u.department!,
        if (u.group != null && u.group!.isNotEmpty) u.group!,
      ],
    }.toList()
      ..sort();

    List<AppUser> users = state.users;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      users = users.where((u) =>
          u.name.toLowerCase().contains(q) ||
          u.identificationNumber.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q)).toList();
    }
    if (_groupFilter != null) {
      users = users
          .where((u) => u.className == _groupFilter || u.department == _groupFilter || u.group == _groupFilter)
          .toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEmployeeScreen())),
        tooltip: 'Add employee',
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search by name, ID, or email', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (groups.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('All', null),
                  for (final g in groups) _chip(g, g),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: users.isEmpty
                ? Center(child: Text('No users found.', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: u.role == UserRole.admin ? Colors.purple.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.12),
                              child: Icon(u.role == UserRole.admin ? Icons.admin_panel_settings : Icons.person,
                                  color: u.role == UserRole.admin ? Colors.purple : Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    [
                                      u.identificationNumber,
                                      u.className ?? u.department,
                                      if (u.room != null && u.room!.isNotEmpty) 'Room ${u.room}',
                                      if (u.branchId != null) state.branchById(u.branchId)?.name,
                                    ].where((v) => v != null && v.isNotEmpty).join(' • '),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            if (u.phoneNumber != null && u.phoneNumber!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.call_outlined, size: 20, color: Colors.green),
                                tooltip: 'Call ${u.phoneNumber}',
                                onPressed: () => launchUrl(Uri(scheme: 'tel', path: u.phoneNumber)),
                              ),
                            Icon(
                              u.hasFaceProfile ? Icons.verified_user : Icons.warning_amber_rounded,
                              color: u.hasFaceProfile ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit',
                              onPressed: () => _showEditDialog(context, u),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDelete(context, u),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _groupFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _groupFilter = value),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppUser u) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
            'This removes ${u.name}\'s profile and face enrollment from the app. Their sign-in account is not deleted — disable it from the Firebase console if needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AppState>().deleteUser(u.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppUser u) {
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController(text: u.name);
    final phoneCtrl = TextEditingController(text: u.phoneNumber ?? '');
    final classCtrl = TextEditingController(text: u.className ?? '');
    final groupCtrl = TextEditingController(text: u.group ?? '');
    final roomCtrl = TextEditingController(text: u.room ?? '');
    final subjectCtrl = TextEditingController(text: u.subject ?? '');
    final deptCtrl = TextEditingController(text: u.department ?? '');
    final positionCtrl = TextEditingController(text: u.position ?? '');
    String? branchId = u.branchId;
    final selectedScheduleIds = state.schedules.where((s) => s.assignedUserIds.contains(u.id)).map((s) => s.id).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Edit ${u.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const SizedBox(height: 10),
              TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class')),
              const SizedBox(height: 10),
              TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'Group')),
              const SizedBox(height: 10),
              TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room')),
              const SizedBox(height: 10),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department')),
              const SizedBox(height: 10),
              TextField(controller: positionCtrl, decoration: const InputDecoration(labelText: 'Position')),
              if (state.branches.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: branchId,
                  decoration: const InputDecoration(labelText: 'Branch / location'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No branch')),
                    for (final b in state.branches) DropdownMenuItem<String?>(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setDialogState(() => branchId = v),
                ),
              ],
              if (state.schedules.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Assigned Schedules (My Calendar)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                for (final s in state.schedules)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.startTime} - ${s.endTime}', style: const TextStyle(fontSize: 11)),
                    value: selectedScheduleIds.contains(s.id),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          selectedScheduleIds.add(s.id);
                        } else {
                          selectedScheduleIds.remove(s.id);
                        }
                      });
                    },
                  ),
              ],
              if (u.boundDeviceId != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Face check-in is bound to one device.', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<AppState>().resetBoundDevice(u.id);
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              // Built directly (not via copyWith) so a field can be cleared
              // back to null by leaving it blank.
              final updated = AppUser(
                id: u.id,
                identificationNumber: u.identificationNumber,
                name: nameCtrl.text.trim().isEmpty ? u.name : nameCtrl.text.trim(),
                gender: u.gender,
                role: u.role,
                phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                className: classCtrl.text.trim().isEmpty ? null : classCtrl.text.trim(),
                group: groupCtrl.text.trim().isEmpty ? null : groupCtrl.text.trim(),
                subject: subjectCtrl.text.trim().isEmpty ? null : subjectCtrl.text.trim(),
                room: roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
                department: deptCtrl.text.trim().isEmpty ? null : deptCtrl.text.trim(),
                position: positionCtrl.text.trim().isEmpty ? null : positionCtrl.text.trim(),
                branchId: branchId,
                faceProfileId: u.faceProfileId,
                boundDeviceId: u.boundDeviceId,
                photoUrl: u.photoUrl,
                email: u.email,
                createdAt: u.createdAt,
                createdByAdmin: u.createdByAdmin,
              );
              final appState = context.read<AppState>();
              await appState.updateUser(updated);
              await appState.updateScheduleAssignments(u.id, selectedScheduleIds);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
        ),
      ),
    );
  }
}
