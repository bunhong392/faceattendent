enum ActivityAction {
  faceRegistered,
  userCreated,
  userUpdated,
  userDeleted,
  attendanceRecorded,
  attendanceEdited,
  attendanceDeleted,
  login,
  logout,
  scheduleCreated,
  scheduleUpdated,
  leaveRequested,
  leaveReplied,
}

/// Audit trail entry for security & accountability.
class ActivityLog {
  final String id;
  final String actorUserId;
  final String actorName;
  final ActivityAction action;
  final String description;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    required this.action,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actorUserId': actorUserId,
        'actorName': actorName,
        'action': action.name,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'],
        actorUserId: json['actorUserId'],
        actorName: json['actorName'],
        action: ActivityAction.values.firstWhere((a) => a.name == json['action']),
        description: json['description'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
