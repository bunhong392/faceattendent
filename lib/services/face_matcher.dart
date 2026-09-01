import 'dart:math';

/// Compares two facial descriptors and returns a similarity score in
/// [0.0, 1.0]. This uses cosine similarity over a geometric feature vector
/// (relative distances/angles between eyes, nose, mouth, and face contour
/// points extracted via ML Kit). It is a stand-in for a proper learned
/// embedding model (FaceNet/ArcFace/MobileFaceNet via TFLite) — swap
/// [FaceMatcher.similarity] for a real embedding distance in production,
/// where cosine similarity or L2 distance over a 128/512-d embedding is used.
class FaceMatcher {
  static const double matchThreshold = 0.85;

  static double similarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    final cos = dot / (sqrt(normA) * sqrt(normB));
    // Map cosine similarity [-1,1] to a friendlier [0,1] confidence score.
    return ((cos + 1) / 2).clamp(0.0, 1.0);
  }

  static bool isMatch(List<double> a, List<double> b) {
    return similarity(a, b) >= matchThreshold;
  }

  /// Finds the best-matching descriptor among a set of candidates.
  /// Returns (userId, confidence) of the best match, or null if none clears
  /// the threshold.
  static MapEntry<String, double>? bestMatch(
    List<double> probe,
    Map<String, List<double>> candidates,
  ) {
    String? bestId;
    double bestScore = 0;
    candidates.forEach((userId, descriptor) {
      final score = similarity(probe, descriptor);
      if (score > bestScore) {
        bestScore = score;
        bestId = userId;
      }
    });
    if (bestId != null && bestScore >= matchThreshold) {
      return MapEntry(bestId!, bestScore);
    }
    return null;
  }
}
