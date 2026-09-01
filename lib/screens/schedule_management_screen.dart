import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/app_state.dart';
import '../services/location_service.dart';
import '../models/schedule_model.dart';
import '../models/user_model.dart';
import '../utils/status_utils.dart';

class ScheduleManagementScreen extends StatelessWidget {
  const ScheduleManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleDialog(context),
        child: const Icon(Icons.add),
      ),
      body: state.schedules.isEmpty
          ? Center(child: Text('No schedules yet. Tap + to add one.', style: TextStyle(color: Colors.grey.shade500)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.schedules.length,
              itemBuilder: (context, i) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final s = state.schedules[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '${StatusUtils.formatTimeString(s.startTime)} – ${StatusUtils.formatTimeString(s.endTime)} • ${s.weekdays.map((d) => weekdayNames[d - 1]).join(", ")}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (s.className != null || s.department != null || s.room != null)
                              Text(
                                [s.className, s.department, if (s.room != null) 'Room ${s.room}']
                                    .where((v) => v != null && v.isNotEmpty)
                                    .join(' • '),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 11, color: Colors.orange.shade700),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Late after ${s.lateThresholdMinutes}m grace period',
                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            if (s.assignedUserIds.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Assigned to ${s.assignedUserIds.length} employee${s.assignedUserIds.length == 1 ? '' : 's'}',
                                  style: TextStyle(fontSize: 11, color: Colors.purple.shade400),
                                ),
                              ),
                            if (s.latitude != null && s.longitude != null && s.radiusMeters != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on, size: 12, color: Colors.blue.shade400),
                                    const SizedBox(width: 2),
                                    Text('GPS-restricted (±${s.radiusMeters!.round()}m)',
                                        style: TextStyle(fontSize: 11, color: Colors.blue.shade400)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        tooltip: 'Edit schedule',
                        onPressed: () => _showScheduleDialog(context, existing: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => context.read<AppState>().deleteSchedule(s.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showScheduleDialog(BuildContext context, {ScheduleItem? existing}) {
    final isEditing = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final classCtrl = TextEditingController(text: existing?.className ?? '');
    final roomCtrl = TextEditingController(text: existing?.room ?? '');
    final startCtrl = TextEditingController(text: existing?.startTime ?? '08:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '09:00');
    final lateThresholdCtrl = TextEditingController(text: (existing?.lateThresholdMinutes ?? 10).toString());
    final radiusCtrl = TextEditingController(text: (existing?.radiusMeters ?? 100).round().toString());
    final selectedDays = <int>{...(existing?.weekdays ?? [1, 2, 3, 4, 5])};
    final selectedUserIds = <String>{...(existing?.assignedUserIds ?? const [])};
    bool gpsEnabled = existing?.latitude != null && existing?.longitude != null;
    double? capturedLat = existing?.latitude;
    double? capturedLng = existing?.longitude;
    bool locating = false;
    final employees = context.read<AppState>().users.where((u) => u.role == UserRole.member).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickTime(TextEditingController ctrl) async {
            final current = StatusUtils.parseTimeString(ctrl.text) ?? const TimeOfDay(hour: 8, minute: 0);
            final picked = await showTimePicker(context: dialogContext, initialTime: current);
            if (picked != null) {
              final h = picked.hour.toString().padLeft(2, '0');
              final m = picked.minute.toString().padLeft(2, '0');
              ctrl.text = '$h:$m';
              setDialogState(() {});
            }
          }

          return AlertDialog(
            title: Text(isEditing ? 'Edit Schedule' : 'New Schedule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 10),
                  TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class / Department')),
                  const SizedBox(height: 10),
                  TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room (optional)')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: InputDecoration(
                            labelText: 'Start (HH:mm)',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time, size: 20),
                              tooltip: 'Pick start time',
                              onPressed: () => pickTime(startCtrl),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: InputDecoration(
                            labelText: 'End (HH:mm)',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time, size: 20),
                              tooltip: 'Pick end time',
                              onPressed: () => pickTime(endCtrl),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lateThresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Late Threshold (Minutes after start)',
                      hintText: 'e.g. 10 (0 = any time after start is late)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return FilterChip(
                        label: Text(names[i]),
                        selected: selectedDays.contains(day),
                        onSelected: (sel) => setDialogState(() => sel ? selectedDays.add(day) : selectedDays.remove(day)),
                      );
                    }),
                  ),
                  const Divider(height: 24),
                  if (employees.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        selectedUserIds.isEmpty
                            ? 'Assign to specific employees (optional)'
                            : 'Assigned to ${selectedUserIds.length} employee${selectedUserIds.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text('Leave empty to match everyone in the class/department above', style: TextStyle(fontSize: 11)),
                      children: [
                        SizedBox(
                          height: 180,
                          child: ListView(
                            children: [
                              for (final emp in employees)
                                CheckboxListTile(
                                  dense: true,
                                  title: Text(emp.name),
                                  subtitle: Text(emp.className ?? emp.department ?? emp.identificationNumber, style: const TextStyle(fontSize: 11)),
                                  value: selectedUserIds.contains(emp.id),
                                  onChanged: (sel) => setDialogState(() => (sel ?? false) ? selectedUserIds.add(emp.id) : selectedUserIds.remove(emp.id)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Restrict check-in to a GPS location'),
                    value: gpsEnabled,
                    onChanged: (v) => setDialogState(() => gpsEnabled = v),
                  ),
                  if (gpsEnabled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            capturedLat != null
                                ? 'Location set: ${capturedLat!.toStringAsFixed(5)}, ${capturedLng!.toStringAsFixed(5)}'
                                : 'No location captured yet',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                        TextButton.icon(
                          icon: locating
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 16),
                          label: const Text('Use current'),
                          onPressed: locating
                              ? null
                              : () async {
                                  setDialogState(() => locating = true);
                                  final pos = await LocationService.getCurrentPosition();
                                  setDialogState(() {
                                    locating = false;
                                    if (pos != null) {
                                      capturedLat = pos.latitude;
                                      capturedLng = pos.longitude;
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                    TextField(
                      controller: radiusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Allowed radius (meters)'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.isEmpty) return;
                  if (gpsEnabled && capturedLat == null) return; // must capture a location first
                  final schedule = ScheduleItem(
                    id: existing?.id ?? const Uuid().v4(),
                    title: titleCtrl.text,
                    className: classCtrl.text.isEmpty ? null : classCtrl.text,
                    subject: existing?.subject,
                    department: existing?.department,
                    room: roomCtrl.text.isEmpty ? null : roomCtrl.text,
                    weekdays: selectedDays.toList()..sort(),
                    startTime: startCtrl.text,
                    endTime: endCtrl.text,
                    latitude: gpsEnabled ? capturedLat : null,
                    longitude: gpsEnabled ? capturedLng : null,
                    radiusMeters: gpsEnabled ? double.tryParse(radiusCtrl.text) ?? 100 : null,
                    lateThresholdMinutes: int.tryParse(lateThresholdCtrl.text) ?? (existing?.lateThresholdMinutes ?? 10),
                    assignedUserIds: selectedUserIds.toList(),
                  );
                  if (isEditing) {
                    context.read<AppState>().updateSchedule(schedule);
                  } else {
                    context.read<AppState>().addSchedule(schedule);
                  }
                  Navigator.pop(dialogContext);
                },
                child: Text(isEditing ? 'Save Changes' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
