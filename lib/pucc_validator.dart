// ============================================
// ADD THESE IMPORTS AT THE TOP
// ============================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================
// GPS GEOFENCE VALIDATION
// ============================================
class PUCCValidator {
  // Define testing site coordinates (example: Mumbai)
  static const double SITE_LATITUDE = 19.289991;
  static const double SITE_LONGITUDE = 73.058676;
  static const double GEOFENCE_RADIUS_METERS = 1000.0; // 100m radius

  static Future<bool> isWithinGeofence() async {
    try {
      // Check GPS permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("❌ GPS permission denied forever");
        return false;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate distance from testing site
      double distance = Geolocator.distanceBetween(
        SITE_LATITUDE,
        SITE_LONGITUDE,
        position.latitude,
        position.longitude,
      );

      debugPrint("📍 Distance from site: ${distance.toStringAsFixed(2)}m");

      if (distance <= GEOFENCE_RADIUS_METERS) {
        debugPrint("✅ Within geofence");
        return true;
      } else {
        debugPrint("❌ Outside geofence (${distance.toStringAsFixed(0)}m away)");
        return false;
      }
    } catch (e) {
      debugPrint("❌ GPS error: $e");
      return false;
    }
  }

  // Get current GPS coordinates with timestamp
  static Future<Map<String, dynamic>> getGPSMetadata() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
      };
    } catch (e) {
      debugPrint("❌ GPS metadata error: $e");
      return {};
    }
  }
}

// ============================================
// ANTI-SPOOF ENGINE
// ============================================
class AntiSpoofEngine {

  /// Detects screen reflection/glare patterns
  static Future<bool> detectScreenGlare(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      int brightPixelCount = 0;
      int totalPixels = image.width * image.height;

      // Check for uniform bright spots (screen glare)
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;

          if (brightness > 240) { // Very bright pixels
            brightPixelCount++;
          }
        }
      }

      double glareRatio = brightPixelCount / totalPixels;

      if (glareRatio > 0.15) { // More than 15% bright pixels
        debugPrint("❌ Screen glare detected (${(glareRatio * 100).toStringAsFixed(1)}%)");
        return true; // Spoof detected
      }

      debugPrint("✅ No screen glare detected");
      return false;
    } catch (e) {
      debugPrint("⚠️ Glare detection error: $e");
      return false;
    }
  }

  /// Detects pixel grid artifacts (digital screen patterns)
  static Future<bool> detectPixelGrid(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      // Simple check: Look for repeating patterns in a small area
      // Real implementation would use FFT or edge detection
      int centerX = (image.width ~/ 2);
      int centerY = (image.height ~/ 2);

      List<int> horizontalPattern = [];
      for (int x = centerX - 50; x < centerX + 50; x++) {
        final pixel = image.getPixel(x.toInt(), centerY.toInt()); // force int
        horizontalPattern.add(pixel.r.toInt()); // also ensure int here
      }

      // Check for repeating pattern (simplified)
      bool hasPattern = _hasRepeatingPattern(horizontalPattern);

      if (hasPattern) {
        debugPrint("❌ Pixel grid pattern detected (screen display)");
        return true;
      }

      debugPrint("✅ No pixel grid detected");
      return false;
    } catch (e) {
      debugPrint("⚠️ Pixel grid detection error: $e");
      return false;
    }
  }


  static bool _hasRepeatingPattern(List<int> values) {
    // Simple pattern detection: check if values repeat every N pixels
    for (int period = 2; period <= 10; period++) {
      int matches = 0;
      for (int i = 0; i < values.length - period; i++) {
        if ((values[i] - values[i + period]).abs() < 5) {
          matches++;
        }
      }
      if (matches > values.length * 0.7) {
        return true; // Pattern detected
      }
    }
    return false;
  }

  /// Detects printed banner/poster texture
  static Future<bool> detectPrintedTexture(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      // Printed materials often have:
      // 1. Lower dynamic range
      // 2. Dot patterns (halftone printing)
      // 3. Less color variation

      int totalPixels = image.width * image.height;
      Set<int> uniqueColors = {};

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // Bucket colors to reduce noise
          int colorKey = ((pixel.r ~/ 10) << 16) |
          ((pixel.g ~/ 10) << 8) |
          (pixel.b ~/ 10);
          uniqueColors.add(colorKey);
        }
      }

      double colorVariety = uniqueColors.length / totalPixels;

      if (colorVariety < 0.05) { // Less than 5% color variety
        debugPrint("❌ Printed texture detected (low color variety)");
        return true;
      }

      debugPrint("✅ No printed texture detected");
      return false;
    } catch (e) {
      debugPrint("⚠️ Texture detection error: $e");
      return false;
    }
  }

  /// Master anti-spoof check
  static Future<Map<String, dynamic>> runAntiSpoofChecks(Uint8List imageBytes) async {
    bool screenGlare = await detectScreenGlare(imageBytes);
    bool pixelGrid = await detectPixelGrid(imageBytes);
    bool printedTexture = await detectPrintedTexture(imageBytes);

    bool isSpoofed = screenGlare || pixelGrid || printedTexture;

    return {
      'is_spoofed': isSpoofed,
      'screen_glare': screenGlare,
      'pixel_grid': pixelGrid,
      'printed_texture': printedTexture,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// ============================================
// SURROUNDINGS DETECTOR (ML-based)
// ============================================
class SurroundingsDetector {

  /// Check if tire/wheel is visible in image
  static Future<bool> detectTire(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      // Simplified: Look for dark circular shapes in bottom half
      // Real implementation would use YOLOv8 or MobileNet for object detection

      int darkCircularRegions = 0;
      int bottomHalfY = image.height ~/ 2;

      // Sample bottom half for dark regions
      for (int y = bottomHalfY; y < image.height; y += 10) {
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;

          if (brightness < 80) { // Dark pixel (potential tire)
            darkCircularRegions++;
          }
        }
      }

      // If more than 10% of bottom half is dark, assume tire present
      double darkRatio = darkCircularRegions / ((image.width ~/ 10) * (image.height ~/ 20));

      if (darkRatio > 0.1) {
        debugPrint("✅ Tire/wheel detected");
        return true;
      }

      debugPrint("❌ No tire detected");
      return false;
    } catch (e) {
      debugPrint("⚠️ Tire detection error: $e");
      return false;
    }
  }

  /// Check if ground surface is visible
  static Future<bool> detectGround(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      // Check bottom 20% of image for ground texture
      int bottomY = (image.height * 0.8).toInt();

      // Ground typically has: varied texture, not uniform color
      Set<int> colorVariety = {};

      for (int y = bottomY; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          int colorKey = ((pixel.r ~/ 20) << 16) |
          ((pixel.g ~/ 20) << 8) |
          (pixel.b ~/ 20);
          colorVariety.add(colorKey);
        }
      }

      if (colorVariety.length > 10) {
        debugPrint("✅ Ground surface detected");
        return true;
      }

      debugPrint("❌ No ground detected");
      return false;
    } catch (e) {
      debugPrint("⚠️ Ground detection error: $e");
      return false;
    }
  }

  /// Master surroundings check
  static Future<Map<String, dynamic>> verifySurroundings(Uint8List imageBytes) async {
    bool tireVisible = await detectTire(imageBytes);
    bool groundVisible = await detectGround(imageBytes);

    bool contextValid = tireVisible || groundVisible; // At least one required

    return {
      'context_valid': contextValid,
      'tire_visible': tireVisible,
      'ground_visible': groundVisible,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// ============================================
// COMPLIANCE LOGGER (Firebase)
// ============================================
class ComplianceLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logPUCCSession({
    required String operatorId,
    required String vehicleNumber,
    required List<String> captureResults,
    required Map<String, dynamic> gpsMetadata,
    required Map<String, dynamic> antiSpoofResults,
    required Map<String, dynamic> surroundingsResults,
    required String finalStatus, // "pass" or "fail"
  }) async {
    try {
      await _firestore.collection('pucc_sessions').add({
        'operator_id': operatorId,
        'vehicle_number': vehicleNumber,
        'capture_results': captureResults,
        'gps_metadata': gpsMetadata,
        'anti_spoof': antiSpoofResults,
        'surroundings': surroundingsResults,
        'final_status': finalStatus,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ PUCC session logged to Firebase");
    } catch (e) {
      debugPrint("❌ Logging error: $e");
    }
  }

  static Future<void> logValidationFailure({
    required String reason,
    required String operatorId,
  }) async {
    try {
      await _firestore.collection('validation_failures').add({
        'reason': reason,
        'operator_id': operatorId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint("⚠️ Validation failure logged");
    } catch (e) {
      debugPrint("❌ Failure logging error: $e");
    }
  }
}

// ============================================
// WEBSOCKET SYNC (Backend Token Validation)
// ============================================
class WebSocketSync {
  WebSocketChannel? _channel;
  String? _token;
  String? _expectedVehicleNumber;

  Future<bool> connect(String url) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      debugPrint("🔗 WebSocket connected");

      _channel!.stream.listen((message) {
        _handleMessage(message);
      });

      return true;
    } catch (e) {
      debugPrint("❌ WebSocket connection error: $e");
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      _token = data['certificate_token'];
      _expectedVehicleNumber = data['vehicle_registration'];
      debugPrint("✅ Received token: $_token");
      debugPrint("✅ Expected vehicle: $_expectedVehicleNumber");
    } catch (e) {
      debugPrint("❌ Message parse error: $e");
    }
  }

  bool validateToken(String token) {
    if (_token == null) return false;
    return _token == token;
  }

  bool matchesExpectedVehicle(String detectedNumber) {
    if (_expectedVehicleNumber == null) return false;
    return _expectedVehicleNumber!.replaceAll(' ', '').toUpperCase() ==
        detectedNumber.replaceAll(' ', '').toUpperCase();
  }

  void disconnect() {
    _channel?.sink.close();
    debugPrint("🔌 WebSocket disconnected");
  }
}