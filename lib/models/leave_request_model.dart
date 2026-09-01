enum LeaveStatus { pending, approved, rejected }

/// An employee/student's self-reported absence or leave request, with an
/// optional admin reply — lets admins see who was absent and why, and
/// respond back to the employee (e.g. "Approved, feel better").
class LeaveRequest {
  final String id;
  final String userId;
  final String userName;
  final DateTime date; // the day the person will be / was absent
  final String reason;
  final LeaveStatus status;
  final DateTime submittedAt;
  final String? adminReply;
  final String? repliedByName;
  final DateTime? repliedAt;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    required this.reason,
    this.status = LeaveStatus.pending,
    required this.submittedAt,
    this.adminReply,
    this.repliedByName,
    this.repliedAt,
  });

  LeaveRequest copyWith({
    LeaveStatus? status,
    String? adminReply,
    String? repliedByName,
    DateTime? repliedAt,
  }) {
    return LeaveRequest(
      id: id,
      userId: userId,
      userName: userName,
      date: date,
      reason: reason,
      status: status ?? this.status,
      submittedAt: submittedAt,
      adminReply: adminReply ?? this.adminReply,
      repliedByName: repliedByName ?? this.repliedByName,
      repliedAt: repliedAt ?? this.repliedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'date': date.toIso8601String(),
        'reason': reason,
        'status': status.name,
        'submittedAt': submittedAt.toIso8601String(),
        'adminReply': adminReply,
        'repliedByName': repliedByName,
        'repliedAt': repliedAt?.toIso8601String(),
      };

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: json['id'],
        userId: json['userId'],
        userName: json['userName'],
        date: DateTime.parse(json['date']),
        reason: json['reason'],
        status: LeaveStatus.values.firstWhere((s) => s.name == json['status']),
        submittedAt: DateTime.parse(json['submittedAt']),
        adminReply: json['adminReply'],
        repliedByName: json['repliedByName'],
        repliedAt: json['repliedAt'] != null ? DateTime.parse(json['repliedAt']) : null,
      );
}
