import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/leave_request_model.dart';

/// Admin-only: see who reported an absence and why, and reply back
/// (approve/reject with an optional message visible to the employee).
class LeaveRequestsAdminScreen extends StatefulWidget {
  const LeaveRequestsAdminScreen({super.key});

  @override
  State<LeaveRequestsAdminScreen> createState() => _LeaveRequestsAdminScreenState();
}

class _LeaveRequestsAdminScreenState extends State<LeaveRequestsAdminScreen> {
  LeaveStatus? _filter = LeaveStatus.pending;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final requests = _filter == null ? state.leaveRequests : state.leaveRequests.where((r) => r.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('All', null),
                  _chip('Pending', LeaveStatus.pending),
                  _chip('Approved', LeaveStatus.approved),
                  _chip('Rejected', LeaveStatus.rejected),
                ],
              ),
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text('No requests here.', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, i) => _requestCard(context, requests[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, LeaveStatus? value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => setState(() => _filter = value)),
    );
  }

  Widget _requestCard(BuildContext context, LeaveRequest r) {
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
              Expanded(
                child: Text('${r.userName} • ${DateFormat.yMMMd().format(r.date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(r.status.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.reason),
          if (r.adminReply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Text('Your reply: ${r.adminReply}', style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (r.status == LeaveStatus.pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reply(context, r, LeaveStatus.rejected),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _reply(context, r, LeaveStatus.approved),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _reply(BuildContext context, LeaveRequest r, LeaveStatus status) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == LeaveStatus.approved ? 'Approve request' : 'Reject request'),
        content: TextField(
          controller: replyCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reply to employee (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<AppState>().replyToLeaveRequest(
                    r.id,
                    status: status,
                    reply: replyCtrl.text.trim().isEmpty ? null : replyCtrl.text.trim(),
                  );
              Navigator.pop(dialogContext);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
