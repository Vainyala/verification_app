
class MatchResult {
  final bool matched;
  final String? suspectId;
  final double? score;
  final bool isVehicleMatch; // new field for vehicle match

  MatchResult({
    required this.matched,
    this.suspectId,
    this.score,
    this.isVehicleMatch = false,
  });

  /// ✅ copyWith method   sqflite_sqlcipher
  MatchResult copyWith({
    bool? matched,
    String? suspectId,
    double? score,
    bool? isVehicleMatch,
  }) {
    return MatchResult(
      matched: matched ?? this.matched,
      suspectId: suspectId ?? this.suspectId,
      score: score ?? this.score,
      isVehicleMatch: isVehicleMatch ?? this.isVehicleMatch,
    );
  }
}
