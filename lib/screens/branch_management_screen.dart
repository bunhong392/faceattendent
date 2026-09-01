import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/app_state.dart';
import '../services/location_service.dart';
import '../models/branch_model.dart';

/// Admin-only: manages the company's physical locations. Each branch has its
/// own map location + allowed radius, since a company can have several
/// sites (e.g. "Head Office", "Warehouse 2") that each need their own
/// geofence for check-in.
class BranchManagementScreen extends StatelessWidget {
  const BranchManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final employeeCountByBranch = <String, int>{};
    for (final u in state.users) {
      if (u.branchId != null) {
        employeeCountByBranch[u.branchId!] = (employeeCountByBranch[u.branchId!] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Branches')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context),
        child: const Icon(Icons.add_location_alt),
      ),
      body: state.branches.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No branches yet. Add one to give this location its own map pin and check-in radius.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.branches.length,
              itemBuilder: (context, i) {
                final b = state.branches[i];
                final count = employeeCountByBranch[b.id] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.withValues(alpha: 0.12),
                        child: const Icon(Icons.store_mall_directory_outlined, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (b.address != null && b.address!.isNotEmpty)
                              Text(b.address!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text(
                              '${b.latitude.toStringAsFixed(5)}, ${b.longitude.toStringAsFixed(5)} • ±${b.radiusMeters.round()}m • $count employee${count == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showEditDialog(context, existing: b)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(context, b),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, Branch b) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete branch?'),
        content: Text('"${b.name}" will be removed. Employees assigned to it will keep their profile but lose the branch link.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AppState>().deleteBranch(b.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, {Branch? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final radiusCtrl = TextEditingController(text: (existing?.radiusMeters ?? 150).round().toString());
    double? lat = existing?.latitude;
    double? lng = existing?.longitude;
    bool locating = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Branch' : 'Edit Branch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Branch name')),
                const SizedBox(height: 10),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address (optional)')),
                const SizedBox(height: 10),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Allowed check-in radius (meters)'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lat != null ? 'Location set: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}' : 'No location captured yet',
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
                                  lat = pos.latitude;
                                  lng = pos.longitude;
                                }
                              });
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || lat == null) return;
                context.read<AppState>().upsertBranch(Branch(
                      id: existing?.id ?? const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      latitude: lat!,
                      longitude: lng!,
                      radiusMeters: double.tryParse(radiusCtrl.text) ?? 150,
                    ));
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
