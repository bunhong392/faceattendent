/// Stores the facial "signature" captured during enrollment.
/// In this reference implementation, we store a lightweight geometric
/// descriptor derived from ML Kit face landmarks/contours instead of a raw
/// image, so verification does not depend on a heavy on-device embedding
/// model. It's swappable: replace [descriptor] + [FaceMatcher] with a real
/// FaceNet/ArcFace TFLite embedding for production-grade accuracy.
class FaceProfile {
  final String id;
  final String userId;
  final List<double> descriptor; // normalized geometric feature vector
  final String sampleImagePath; // local path to a reference thumbnail
  final DateTime registeredAt;
  final int sampleCount; // number of angles captured (front/left/right)

  FaceProfile({
    required this.id,
    required this.userId,
    required this.descriptor,
    required this.sampleImagePath,
    required this.registeredAt,
    required this.sampleCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'descriptor': descriptor,
        'sampleImagePath': sampleImagePath,
        'registeredAt': registeredAt.toIso8601String(),
        'sampleCount': sampleCount,
      };

  factory FaceProfile.fromJson(Map<String, dynamic> json) => FaceProfile(
        id: json['id'],
        userId: json['userId'],
        descriptor: (json['descriptor'] as List).map((e) => (e as num).toDouble()).toList(),
        sampleImagePath: json['sampleImagePath'],
        registeredAt: DateTime.parse(json['registeredAt']),
        sampleCount: json['sampleCount'],
      );
}
