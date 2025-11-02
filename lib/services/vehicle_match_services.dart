
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../Database/stolen_vehicle_database.dart';
import '../models/match_services.dart';


class VehicleMatchService {
  late final FaceDetector _faceDetector;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> init() async {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
    );
    _faceDetector = FaceDetector(options: options);

    // Load FaceNet model
    // _interpreter = await Interpreter.fromAsset('assets/facenet.tflite');
    _isInitialized = true;
  }

  /// Generate 128D embedding manually
  Future<List<double>> generateEmbedding(Uint8List bytes) async {
    if (!_isInitialized) throw Exception("Service not initialized");

    final raw = img.decodeImage(bytes);
    if (raw == null) throw Exception("Cannot decode image");

    final tempFile = await _writeTempImage(bytes);
    final inputImage = InputImage.fromFilePath(tempFile.path);

    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) throw Exception("No face detected");

    final face = faces.first;
    final box = face.boundingBox;

    final cropX = box.left.clamp(0.0, raw.width - 1).toInt();
    final cropY = box.top.clamp(0.0, raw.height - 1).toInt();
    final cropW = box.width.clamp(1.0, raw.width - cropX).toInt();
    final cropH = box.height.clamp(1.0, raw.height - cropY).toInt();

    final cropped = img.copyCrop(raw, x: cropX, y: cropY, width: cropW, height: cropH);
    final resized = img.copyResizeCropSquare(cropped, size: 160);

    final input = Float32List(1 * 160 * 160 * 3);
    int index = 0;
    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final p = resized.getPixel(x, y);
        input[index++] = (p.r - 128) / 128.0;
        input[index++] = (p.g - 128) / 128.0;
        input[index++] = (p.b - 128) / 128.0;
      }
    }

    final output = List.filled(128, 0.0).reshape([1, 128]);
    _interpreter!.run(input.reshape([1, 160, 160, 3]), output);

    return _normalize(output[0]);
  }

  /// Run face match against DB
  Future<MatchResult> runMatch(Uint8List bytes) async {
    final embedding = await generateEmbedding(bytes);
    final suspects = await VehicleDb.getAll();

    double bestScore = -1;
    String? bestId;

    for (var s in suspects) {
      final dbVec = List<double>.from(s["vector"]);
      final score = _cosineSimilarity(embedding, dbVec);
      if (score > bestScore) {
        bestScore = score;
        bestId = s["id"];
      }
    }

    return MatchResult(
      matched: bestScore > 0.85,
      suspectId: bestId,
      score: bestScore,
    );
  }

  /// Detect vehicle number using ML Kit OCR
  Future<String?> detectVehicleNumber(Uint8List bytes) async {
    final tempFile = await _writeTempImage(bytes);
    final inputImage = InputImage.fromFilePath(tempFile.path);

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);

    textRecognizer.close();

    // Simple regex to detect vehicle-like patterns (India)
    final regExp = RegExp(r'[A-Z]{2}[0-9]{1,2}[A-Z]{0,2}[0-9]{4}');
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final match = regExp.firstMatch(line.text.replaceAll(' ', '').toUpperCase());
        if (match != null) return match.group(0);
      }
    }
    return null;
  }

  Future<File> _writeTempImage(Uint8List bytes) async {
    final dir = await Directory.systemTemp.createTemp();
    final file = File('${dir.path}/temp.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<double> _normalize(List<double> v) {
    final norm = math.sqrt(v.fold(0, (sum, x) => sum + x * x));
    return v.map((x) => x / norm).toList();
  }
}
