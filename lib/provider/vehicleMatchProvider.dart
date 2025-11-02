import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../database/stolen_vehicle_database.dart';
import '../models/match_services.dart';
import '../services/vehicle_match_services.dart';

class VehicleMatchProvider extends ChangeNotifier {
  final VehicleMatchService _matchService = VehicleMatchService();
  MatchResult? _lastResult;
  bool _initialized = false;

  MatchResult? get lastResult => _lastResult;
  bool get isInitialized => _initialized;
  VehicleMatchService get matchService => _matchService;

  Future<void> init() async {
    await _matchService.init();
    _initialized = true;
    notifyListeners();
  }

  /// Store new suspect image + optional vehicle info
  Future<void> storeDummyOnce(
      Uint8List bytes,
      String name,
      String imagePath, {
        String? vehicleNumber,
        String? vehicleType, // 🔹 Added parameter
      }) async {
    if (!_initialized) throw Exception("Service not initialized");
    final embedding = await _matchService.generateEmbedding(bytes);

    await VehicleDb.insertDummyOnce(
      name, // id
      name, // name
      embedding,
      imagePath,
      vehicleNumber: vehicleNumber ?? '',
      vehicleType: vehicleType ?? '', // 🔹 Added to DB insert
    );
  }

  /// Match face + optionally vehicle number
  Future<MatchResult> matchImageBytes(
      Uint8List bytes, {
        bool checkVehicle = false,
      }) async {
    if (!_initialized) throw Exception("Service not initialized");

    // 1️⃣ Face match
    _lastResult = await _matchService.runMatch(bytes);

    // 2️⃣ Vehicle match (optional)
    Map<String, dynamic>? vehicleMatch;
    if (checkVehicle) {
      final detectedNumber = await _matchService.detectVehicleNumber(bytes);
      if (detectedNumber != null) {
        vehicleMatch = await matchVehicleNumber(detectedNumber);
      }
    }

    if (vehicleMatch != null) {
      debugPrint(
          "🚨 Vehicle matched: ${vehicleMatch['vehicle_number']} (${vehicleMatch['vehicle_type'] ?? 'N/A'}) with ${vehicleMatch['name']}");
      _lastResult = MatchResult(
        matched: true,
        suspectId: vehicleMatch['id'],
        score: _lastResult?.score ?? 0.0,
      );
    }

    notifyListeners();
    return _lastResult!;
  }

  /// Get all saved evidence
  Future<List<Map<String, dynamic>>> getAllSavedEvidence() async {
    return await VehicleDb.getAll();
  }

  /// Match vehicle number locally
  Future<Map<String, dynamic>?> matchVehicleNumber(String detectedNumber) async {
    if (detectedNumber.isEmpty) return null;

    final allData = await VehicleDb.getAll();
    for (var record in allData) {
      final dbNumber =
      (record['vehicle_number'] ?? '').replaceAll(' ', '').toUpperCase();
      final inputNumber = detectedNumber.replaceAll(' ', '').toUpperCase();

      if (dbNumber == inputNumber) {
        debugPrint(
            "🚨 Vehicle Alert: $inputNumber matched with ${record['name']} (${record['vehicle_type'] ?? 'Unknown Type'})");
        notifyListeners();
        return record;
      }
    }
    return null;
  }
}
