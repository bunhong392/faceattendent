import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Turns an ML Kit [Face] detection result into a normalized geometric
/// feature vector suitable for comparison by [FaceMatcher].
///
/// It uses relative distances between landmarks (eyes, nose, mouth, ears)
/// normalized by inter-ocular distance so the descriptor is roughly
/// invariant to the subject's distance from the camera. This is a simple,
/// dependency-light stand-in for a learned face-embedding network.
class FaceDescriptorExtractor {
  static List<double>? extract(Face face) {
    final landmarks = face.landmarks;
    final leftEye = landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = landmarks[FaceLandmarkType.noseBase]?.position;
    final mouthLeft = landmarks[FaceLandmarkType.leftMouth]?.position;
    final mouthRight = landmarks[FaceLandmarkType.rightMouth]?.position;
    final leftEar = landmarks[FaceLandmarkType.leftEar]?.position;
    final rightEar = landmarks[FaceLandmarkType.rightEar]?.position;

    if (leftEye == null || rightEye == null || nose == null) {
      return null; // not enough landmarks to build a reliable descriptor
    }

    final interOcular = _dist(leftEye.x.toDouble(), leftEye.y.toDouble(),
        rightEye.x.toDouble(), rightEye.y.toDouble());
    if (interOcular == 0) return null;

    double norm(double d) => d / interOcular;

    final points = <double>[];

    void addDist(double? x1, double? y1, double? x2, double? y2) {
      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        points.add(0);
      } else {
        points.add(norm(_dist(x1, y1, x2, y2)));
      }
    }

    addDist(nose.x.toDouble(), nose.y.toDouble(), leftEye.x.toDouble(), leftEye.y.toDouble());
    addDist(nose.x.toDouble(), nose.y.toDouble(), rightEye.x.toDouble(), rightEye.y.toDouble());
    addDist(mouthLeft?.x.toDouble(), mouthLeft?.y.toDouble(), mouthRight?.x.toDouble(), mouthRight?.y.toDouble());
    addDist(nose.x.toDouble(), nose.y.toDouble(), mouthLeft?.x.toDouble(), mouthLeft?.y.toDouble());
    addDist(nose.x.toDouble(), nose.y.toDouble(), mouthRight?.x.toDouble(), mouthRight?.y.toDouble());
    addDist(leftEar?.x.toDouble(), leftEar?.y.toDouble(), leftEye.x.toDouble(), leftEye.y.toDouble());
    addDist(rightEar?.x.toDouble(), rightEar?.y.toDouble(), rightEye.x.toDouble(), rightEye.y.toDouble());

    // Head pose angles add a bit more discriminative signal.
    points.add((face.headEulerAngleY ?? 0) / 90.0);
    points.add((face.headEulerAngleZ ?? 0) / 90.0);

    return points;
  }

  static double _dist(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return (dx * dx + dy * dy);
  }
}
