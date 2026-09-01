import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/leave_request_model.dart';

/// Member-facing: report an absence with a reason, and see admin replies to
/// past requests.
class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _reasonCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mine = state.currentUser == null ? <LeaveRequest>[] : state.leaveRequestsFor(state.currentUser!.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Absence / Leave')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New request', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(_date)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. Medical appointment'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('My requests', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No requests yet.', style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            ...mine.map((r) => _requestTile(r)),
        ],
      ),
    );
  }

  Widget _requestTile(LeaveRequest r) {
    final color = switch (r.status) {
      LeaveStatus.pending => Colors.orange,
      LeaveStatus.approved => Colors.green,
      LeaveStatus.rejected => Colors.red,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(DateFormat.yMMMd().format(r.date), style: const TextStyle(fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(r.status.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.reason, style: TextStyle(color: Colors.grey.shade700)),
          if (r.adminReply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reply from ${r.repliedByName ?? "Admin"}', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(r.adminReply!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await context.read<AppState>().submitLeaveRequest(date: _date, reason: _reasonCtrl.text.trim());
    if (!mounted) return;
    _reasonCtrl.clear();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted.')));
  }
}
