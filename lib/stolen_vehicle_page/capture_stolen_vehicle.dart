import 'dart:async';
import 'dart:collection';
import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;


import 'package:image/image.dart' as imgLib;

import '../models/match_services.dart';
import '../provider/vehicleMatchProvider.dart';

class StolenVehicleDetectedPage extends StatefulWidget {
  const StolenVehicleDetectedPage({super.key});

  @override
  State<StolenVehicleDetectedPage> createState() => _StolenVehicleDetectedPageState();
}

class _StolenVehicleDetectedPageState extends State<StolenVehicleDetectedPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitializing = true;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  int _currentCameraIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final TextRecognizer _textRecognizer;
  bool _isCapturing = false;
  Timer? _captureTimer;
  // Plate overlay state (kept same)
  List<Rect> _plateRects = [];
  String? _lastPlateText;
  DateTime? _lastOcrTime;

  // streaming throttle (ms)
  final int _streamThrottleMs = 500;
  DateTime? _lastStreamProcess;

  // grid configuration (2 x 5)
  final int _rows = 2;
  final int _cols = 5;

  // concurrency limiter - how many zone OCRs run at once
  final int _maxConcurrentOcr = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize only text recognizer (no face detector)
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initEverything();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _audioPlayer.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initEverything() async {
    await _initCamera(index: 0);
    if (!mounted) return;
    Provider.of<VehicleMatchProvider>(context, listen: false).init();
  }

  Future<void> _initCamera({int index = 0}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _isCameraInitializing = false);
        return;
      }

      _currentCameraIndex = index.clamp(0, _cameras!.length - 1);
      final cam = _cameras![_currentCameraIndex];

      _cameraController = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitializing = false);
    } catch (e) {
      if (mounted) setState(() => _isCameraInitializing = false);
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    if (mounted) setState(() => _isCameraInitializing = true);
    await _cameraController?.dispose();
    await _initCamera(index: _currentCameraIndex);
  }

  // ---------------- single-capture flow ----------------
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      if (_isStreaming) {
        await _stopVideoStream();
      }

      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      final provider = Provider.of<VehicleMatchProvider>(context, listen: false);

      // Removed face match logic: now directly OCR for vehicle number
      final recognized = await _runOcrOnBytes(bytes);
      final plateInfo = _findPlateFromRecognized(recognized);
      final String? detectedVehicleNumber = plateInfo?.text;
      final Rect? plateBox = plateInfo?.box;

      if (detectedVehicleNumber != null && detectedVehicleNumber.isNotEmpty) {
        debugPrint("Detected vehicle number (raw): $detectedVehicleNumber");

        // normalize before showing and matching
        final String normalized = _normalizeForMatch(detectedVehicleNumber);
        _showPlateOverlay(plateBox, normalized);

        // Try match with normalized value
        var vehicleMatch = await provider.matchVehicleNumber(normalized);
        debugPrint("🔍 Provider match result for [$normalized] -> $vehicleMatch");

        // fallback: try other normalized variants (swap O<->0 etc)
        if (vehicleMatch == null) {
          final alt = _alternateNormalizationVariants(normalized);
          for (final v in alt) {
            vehicleMatch = await provider.matchVehicleNumber(v);
            debugPrint("🔍 Fallback try [$v] -> $vehicleMatch");
            if (vehicleMatch != null) break;
          }
        }

        if (vehicleMatch != null) {
          final matchRes = MatchResult(matched: true, suspectId: vehicleMatch['id'], score: 0.0);
          await _handleMatchFound(matchRes, isVehicle: true, vehicleNumber: normalized);
          return;
        } else {
          await _showVehicleDetectedDialog(normalized, matched: false, matchedRecord: null);
          return;
        }
      }

      // Nothing found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("?? No vehicle registration detected")),
      );
    } catch (e) {
      debugPrint("Take picture error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("?? Error: ${e.toString()}"),
        backgroundColor: Colors.red,
      ));
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _handleMatchFound(MatchResult result, {required bool isVehicle, String? vehicleNumber}) async {
    if (!mounted) return;

    // play different tone depending on type (we keep same asset names)
    try {
      if (isVehicle) {
        await _audioPlayer.play(AssetSource("vehicleTone.mp3"));
      } else {
        await _audioPlayer.play(AssetSource("alert.mp3"));
      }
    } catch (e) {
      debugPrint("Audio play error: $e");
    }

    await _showMatchDialog(result, isVehicle: isVehicle, vehicleNumber: vehicleNumber);
  }

  // kept your dialog (same look)
  Future<void> _showVehicleDetectedDialog(
      String vehicleNo, {
        required bool matched,
        Map<String, dynamic>? matchedRecord,
      }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: matched ? Colors.red[100] : Colors.green[100],
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                matched
                    ? Icons.warning_amber_rounded
                    : Icons.directions_car_filled,
                color: matched ? Colors.red : Colors.green,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                matched ? "?? Vehicle MATCHED" : "?? Vehicle Not Matched",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: matched ? Colors.red[800] : Colors.green[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                matched
                    ? "Vehicle record found in database.\nNumber: $vehicleNo"
                    : "Vehicle detected successfully but not found in the records.\nNumber: $vehicleNo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: matched ? Colors.red[700] : Colors.green[700],
                ),
              ),
              const SizedBox(height: 20),

              // ? Dismiss button (same design as before)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text(
                        "Dismiss",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        matched ? Colors.grey[500] : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- OCR helpers ----------------
  Future<RecognizedText> _runOcrOnBytes(Uint8List bytes) async {
    try {
      // Try OCR on original first
      final tmp = await _writeTempImage(bytes);
      final inputImage = InputImage.fromFilePath(tmp.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      // ✅ Console output for detection status (raw)
      if (recognized.text.trim().isNotEmpty) {
        debugPrint("✅ Raw OCR text: ${recognized.text}");
      } else {
        debugPrint("❌ No plate detected in original image");
      }

      // quick heuristic: if recognized text is empty or very short, try enhanced image
      if ((recognized.text).trim().length < 3) {
        final enhanced = await _enhanceForOcr(bytes);
        if (enhanced != null) {
          final tmp2 = await _writeTempImage(enhanced);
          final inputImage2 = InputImage.fromFilePath(tmp2.path);
          final recognized2 = await _textRecognizer.processImage(inputImage2);

          // ✅ Again check for detection
          if (recognized2.text.trim().isNotEmpty) {
            debugPrint("✅ Enhanced OCR text: ${recognized2.text}");
          } else {
            debugPrint("❌ Still no plate detected even after enhancement");
          }

          return recognized2;
        }
      }

      return recognized;
    } catch (e) {
      debugPrint("⚠️ OCR error: $e");
      rethrow;
    }
  }

  Future<Uint8List?> _enhanceForOcr(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Convert to grayscale
      img.Image gray = img.grayscale(decoded);

      // Increase contrast & brightness slightly using adjustColor
      gray = img.adjustColor(gray, contrast: 1.2, brightness: 0.05);

      // Simple threshold (manual)
      for (int y = 0; y < gray.height; y++) {
        for (int x = 0; x < gray.width; x++) {
          final pixel = gray.getPixel(x, y);
          final luma = img.getLuminance(pixel);
          if (luma < 90) {
            gray.setPixelRgba(x, y, 0, 0, 0, 255);
          } else {
            gray.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }
      }

      final out = img.encodeJpg(gray, quality: 85);
      return Uint8List.fromList(out);
    } catch (e) {
      debugPrint("Enhance error: $e");
      return null;
    }
  }

  Future<io.File> _writeTempImage(Uint8List bytes) async {
    final dir = await io.Directory.systemTemp.createTemp();
    final file = io.File(p.join(dir.path, 'temp_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(bytes);
    return file;
  }

  // ---------------- normalize helpers ----------------

  /// Normalize OCR text to reduce common OCR mistakes:
  /// - remove non-alphanumeric
  /// - map O <-> 0, I <-> 1, B <-> 8, S <-> 5 (common confusions)
  String normalizeOcrText(String text) {
    String s = text.toUpperCase();
    // remove spaces and unwanted chars first
    s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Now apply replacements that reduce false negatives
    // We prefer mapping letters that are often misread to digits and vice-versa.
    // We'll use a canonical normalization that converts common letters to their
    // more likely plate representation (0,1,8,5).
    s = s
        .replaceAll('O', '0')
        .replaceAll('Q', '0') // sometimes Q ~ 0
        .replaceAll('I', '1')
        .replaceAll('L', '1') // L sometimes as 1
        .replaceAll('Z', '2') // optional
        .replaceAll('B', '8')
        .replaceAll('S', '5');
    return s;
  }

  /// Returns one or two alternate variants to try when a direct match fails.
  /// e.g. if we converted O->0 in normalization and still no match, try O instead.
  List<String> _alternateNormalizationVariants(String normalized) {
    final List<String> variants = [];
    // variant: swap 0 back to O
    variants.add(normalized.replaceAll('0', 'O'));
    // variant: swap 1 back to I
    variants.add(normalized.replaceAll('1', 'I'));
    // variant: swap 8 back to B
    variants.add(normalized.replaceAll('8', 'B'));
    // unique
    return variants.toSet().toList();
  }

  _PlateInfo? _findPlateFromRecognized(RecognizedText recognized) {
    final blocks = recognized.blocks;
    for (var block in blocks) {
      final bText = block.text ?? "";
      final normalized = normalizeOcrText(bText);
      final plate = _matchPlateRegex(normalized);
      if (plate != null) {
        final rect = block.boundingBox;
        return _PlateInfo(text: plate, box: rect);
      }
      for (var line in block.lines) {
        final lText = line.text ?? "";
        final normalizedLine = normalizeOcrText(lText);
        final plateLine = _matchPlateRegex(normalizedLine);
        if (plateLine != null) {
          final rect = line.boundingBox ?? block.boundingBox;
          return _PlateInfo(text: plateLine, box: rect);
        }
      }
    }

    final whole = recognized.text ?? "";
    final normalizedWhole = normalizeOcrText(whole);
    final plateWhole = _matchPlateRegex(normalizedWhole);
    if (plateWhole != null) {
      return _PlateInfo(text: plateWhole, box: null);
    }

    return null;
  }

  // String? _matchPlateRegex(String normalized) {
  //   // Indian style simplified: 2 letters + 1-2 digits + 1-2 letters + 3-4 digits
  //   // Note: normalized text already has digits/letters mapped; match against pattern
  //   final reg = RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{3,4}', caseSensitive: false);
  //   final m = reg.firstMatch(normalized);
  //   return m?.group(0);
  // }


  String? _matchPlateRegex(String normalized) {
    normalized = normalized
        .replaceAll(RegExp(r'[\n\r\s]+'), '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .toUpperCase();

    // ✅ Smart OCR correction rules
    normalized = normalized
        .replaceAll(RegExp(r'(?<=D)1'), 'L') // D1 → DL
        .replaceAll(RegExp(r'(?<=D)I'), 'L')
        .replaceAllMapped(RegExp(r'(?<=\d)O(?=\d)'), (m) => '0')
        .replaceAllMapped(RegExp(r'(?<=\d)O(?=$)'), (m) => '0')
        .replaceAllMapped(RegExp(r'(?<=\d)O(?=[A-Z])'), (m) => '0')
        .replaceAllMapped(RegExp(r'(?<=[A-Z])5(?=[A-Z])'), (m) => 'S') // A5B → ASB
        .replaceAllMapped(RegExp(r'(?<=[A-Z])8(?=[A-Z])'), (m) => 'B'); // A8B → ABB

    // ✅ Flexible regex for Indian plates
    final reg = RegExp(
      r'[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{3,4}',
      caseSensitive: false,
    );

    final m = reg.firstMatch(normalized);

    debugPrint("🧩 Cleaned OCR text: $normalized");

    if (m != null) {
      debugPrint("✅ Regex Matched Plate: ${m.group(0)}");
      return m.group(0);
    } else {
      debugPrint("❌ No plate match found");
      return null;
    }
  }

  String _normalizeForMatch(String text) {
    String normalized = text.toUpperCase();


    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Common OCR corrections
    normalized = normalized
        .replaceAll(RegExp(r'\bD1\b'), 'DL')
        .replaceAll(RegExp(r'\bDI\b'), 'DL')
        .replaceAll(RegExp(r'(?<=D)1'), 'L')
        .replaceAll(RegExp(r'(?<=D)I'), 'L')

        .replaceAll('8', 'B');


    debugPrint("🧩 Corrected OCR text: $normalized");
    return normalized;
  }




  void _showPlateOverlay(Rect? box, String plateText) {
    if (!mounted) return;
    if (box == null) {
      setState(() {
        _lastPlateText = plateText;
        _plateRects = [];
      });
    } else {
      setState(() {
        _lastPlateText = plateText;
        _plateRects = [box];
      });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _plateRects = [];
          _lastPlateText = null;
        });
      }
    });
  }


  Future<void> _startVideoStream() async {
    if (_cameraController == null || _cameraController!.value.isStreamingImages) return;

    if (mounted) setState(() => _isStreaming = true);

    await _cameraController!.startImageStream((CameraImage image) async {
      if (!_isStreaming || _isCapturing) return;

      // Optional: handle frame throttling if needed
    });

    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isStreaming || _isCapturing) return;

      _isCapturing = true;
      await _takeVideosPicture();
      _isCapturing = false;
    });
  }

  Future<void> _stopVideoStream() async {
    _captureTimer?.cancel();
    _captureTimer = null;

    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    if (mounted) setState(() => _isStreaming = false);
  }

  Future<void> _takeVideosPicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      final provider = Provider.of<VehicleMatchProvider>(context, listen: false);

      final recognized = await _runOcrOnBytes(bytes);
      final plateInfo = _findPlateFromRecognized(recognized);
      final String? detectedVehicleNumber = plateInfo?.text;
      final Rect? plateBox = plateInfo?.box;

      if (detectedVehicleNumber != null && detectedVehicleNumber.isNotEmpty) {
        debugPrint("✅ Raw OCR text: $detectedVehicleNumber");

        // 🧩 Step 1: OCR correction logic
        String correctedText = detectedVehicleNumber
            .replaceAll(RegExp(r'\bD1\b', caseSensitive: false), 'DL')
            .replaceAll(RegExp(r'\bDI\b', caseSensitive: false), 'DL')
            .replaceAll(RegExp(r'(?<=\bD)1', caseSensitive: false), 'L')
            .replaceAll(RegExp(r'(?<=\bD)I', caseSensitive: false), 'L')
        // .replaceAll('0', 'O')
        // .replaceAll('1', 'I')
            .replaceAll('8', 'B')
            .replaceAll('5', 'S');

        debugPrint("🧩 Corrected OCR text: $correctedText");

        // 🧩 Step 2: Normalize for matching
        final String normalized = _normalizeForMatch(correctedText);
        debugPrint("🧩 Cleaned OCR text: $normalized");

        _showPlateOverlay(plateBox, normalized);

        // 🧩 Step 3: Try matching with database
        var vehicleMatch = await provider.matchVehicleNumber(normalized);
        debugPrint("🔍 Provider match result for [$normalized] -> $vehicleMatch");

        // 🧩 Step 4: Fallback tries
        if (vehicleMatch == null) {
          final alt = _alternateNormalizationVariants(normalized);
          for (final v in alt) {
            vehicleMatch = await provider.matchVehicleNumber(v);
            debugPrint("🔍 Fallback try [$v] -> $vehicleMatch");
            if (vehicleMatch != null) break;
          }
        }

        // 🧩 Step 5: If match found
        if (vehicleMatch != null) {
          await _stopVideoStream(); // stop stream & timer
          final matchRes = MatchResult(matched: true, suspectId: vehicleMatch['id'], score: 0.0);
          await _handleMatchFound(matchRes, isVehicle: true, vehicleNumber: normalized);
          return;
        } else {
          debugPrint("❌ No match found for $normalized");
        }
      } else {
        debugPrint("❌ No plate detected in this frame");
      }
    } catch (e) {
      debugPrint("⚠️ Take picture error: $e");
    } finally {
      _isCapturing = false;
    }
  }



  /// Convert CameraImage (YUV420) to package:image Image (rgb)
  imgLib.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final imgLib.Image imgOut = imgLib.Image(width: width, height: height);

      final Plane planeY = image.planes[0];
      final Plane planeU = image.planes[1];
      final Plane planeV = image.planes[2];

      final Uint8List yBuf = planeY.bytes;
      final Uint8List uBuf = planeU.bytes;
      final Uint8List vBuf = planeV.bytes;

      final int strideY = planeY.bytesPerRow;
      final int strideU = planeU.bytesPerRow;
      final int strideV = planeV.bytesPerRow;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * strideY + x;
          final int uvIndex = (y >> 1) * strideU + (x >> 1);

          final int Y = yBuf[yIndex] & 0xff;
          final int U = uBuf[uvIndex] & 0xff;
          final int V = vBuf[uvIndex] & 0xff;

          // YUV to RGB conversion
          int r = (Y + (1.370705 * (V - 128))).round();
          int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).round();
          int b = (Y + (1.732446 * (U - 128))).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          imgOut.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      return imgOut;
    } catch (e) {
      debugPrint("YUV->RGB conversion failed: $e");
      return null;
    }
  }

  Future<void> _processZonesAndDetect(imgLib.Image fullRgbImage) async {
    // Determine grid crop sizes
    final int zoneW = (fullRgbImage.width / _cols).floor();
    final int zoneH = (fullRgbImage.height / _rows).floor();

    // Prepare temp dir for zone images
    final dir = await io.Directory.systemTemp.createTemp('zones_${DateTime.now().microsecondsSinceEpoch}');

    final provider = Provider.of<VehicleMatchProvider>(context, listen: false);

    // We'll process zones in small batches to limit concurrency
    final List<Future<void>> zoneFutures = [];
    final sem = _AsyncSemaphore(_maxConcurrentOcr);

    bool foundAndMatched = false;

    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (foundAndMatched) break;

        final int left = c * zoneW;
        final int top = r * zoneH;
        final int w = (c == _cols - 1) ? (fullRgbImage.width - left) : zoneW;
        final int h = (r == _rows - 1) ? (fullRgbImage.height - top) : zoneH;

        // Create crop
        final imgLib.Image? crop = imgLib.copyCrop(
          fullRgbImage,
          x: left,
          y: top,
          width: w,
          height: h,
        );

        if (crop == null) {
          debugPrint("Crop failed for zone $r,$c");
          continue;
        }

        // Encode crop to jpg bytes
        final Uint8List jpgBytes = Uint8List.fromList(imgLib.encodeJpg(crop, quality: 75));

        // Write to file
        final file = io.File(p.join(dir.path, 'zone_${r}_$c.jpg'));
        await file.writeAsBytes(jpgBytes);

        // enqueue OCR for this zone using semaphore
        final fut = () async {
          await sem.acquire();
          try {
            if (foundAndMatched) return;

            final inputImage = InputImage.fromFilePath(file.path);
            final recognized = await _textRecognizer.processImage(inputImage);
            final plateInfo = _findPlateFromRecognized(recognized);
            if (plateInfo != null && plateInfo.text.isNotEmpty) {
              final detectedNumberRaw = plateInfo.text;
              final detectedNumber = _normalizeForMatch(detectedNumberRaw);
              debugPrint("Zone Detected (raw): $detectedNumberRaw at r:$r c:$c");
              debugPrint("Zone Detected (normalized): $detectedNumber at r:$r c:$c");

              // map small crop bbox to full image coordinates (if line bbox exists)
              Rect? mappedRect;
              if (plateInfo.box != null) {
                final Rect small = plateInfo.box!;
                // small is relative to the crop image; map to full image
                mappedRect = Rect.fromLTWH(
                  left + small.left,
                  top + small.top,
                  small.width,
                  small.height,
                );
              }

              // show overlay mapped to MLKit preview later
              _showPlateOverlay(mappedRect, detectedNumber);

              // match with provider (normalized)
              var vehicleMatch = await provider.matchVehicleNumber(detectedNumber);
              debugPrint("🔍 Provider match for [$detectedNumber] -> $vehicleMatch");

              if (vehicleMatch == null) {
                // fallback try a few alternate forms
                final alt = _alternateNormalizationVariants(detectedNumber);
                for (final v in alt) {
                  vehicleMatch = await provider.matchVehicleNumber(v);
                  debugPrint("🔍 Fallback try [$v] -> $vehicleMatch");
                  if (vehicleMatch != null) break;
                }
              }

              if (vehicleMatch != null) {
                foundAndMatched = true;
                final matchRes = MatchResult(matched: true, suspectId: vehicleMatch['id'], score: 0.0);
                await _handleMatchFound(matchRes, isVehicle: true, vehicleNumber: detectedNumber);
                // Stop stream after a match (you can change this behavior)
                await _stopVideoStream();
              } else {
                debugPrint("✖ No DB match for detected plate: $detectedNumber");
              }
            }
          } catch (e) {
            debugPrint("Zone OCR error: $e");
          } finally {
            sem.release();
          }
        }();
        zoneFutures.add(fut);
      }
      if (foundAndMatched) break;
    }

    // Wait for all zones to finish (or at least started)
    await Future.wait(zoneFutures);

    // cleanup temp dir
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint("Temp dir cleanup error: $e");
    }
  }

  Future<void> _takeVideoPicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      // Capture still frame
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();
      final imgLib.Image? original = imgLib.decodeImage(bytes);
      if (original == null) return;

      // 🔹 Step 1: Preprocess image
      final imgLib.Image preprocessed = imgLib.adjustColor(
        imgLib.copyResize(original, width: 640, height: 640),
        brightness: 0.1,
        contrast: 1.5,
      );

      // Convert back to bytes for OCR
      final processedBytes = Uint8List.fromList(imgLib.encodeJpg(preprocessed));

      // 🔹 Step 2: Try OCR multiple times (retry logic)
      String? detectedText;
      int retry = 0;
      while (retry < 3 && (detectedText == null || detectedText.isEmpty)) {
        final recognized = await _runOcrOnBytes(processedBytes);
        final plateInfo = _findPlateFromRecognized(recognized);
        detectedText = plateInfo?.text.trim();
        retry++;
        if (detectedText == null || detectedText.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (detectedText != null && detectedText.isNotEmpty) {
        final normalized = _normalizeForMatch(detectedText);
        _showPlateOverlay(null, normalized);

        final provider = Provider.of<VehicleMatchProvider>(context, listen: false);
        var vehicleMatch = await provider.matchVehicleNumber(normalized);
        debugPrint("🔍 Provider match for (capture) [$normalized] -> $vehicleMatch");

        if (vehicleMatch == null) {
          final alt = _alternateNormalizationVariants(normalized);
          for (final v in alt) {
            vehicleMatch = await provider.matchVehicleNumber(v);
            debugPrint("🔍 Fallback try (capture) [$v] -> $vehicleMatch");
            if (vehicleMatch != null) break;
          }
        }

        if (vehicleMatch != null) {
          await _stopVideoStream();
          await _handleMatchFound(
            MatchResult(matched: true, suspectId: vehicleMatch['id'], score: 0.0),
            isVehicle: true,
            vehicleNumber: normalized,
          );
        } else {
          await _showVehicleDetectedDialog(normalized, matched: false, matchedRecord: null);
        }
      } else {
        debugPrint("⚠️ No number detected even after retries.");
      }
    } catch (e) {
      debugPrint("❌ Take video-picture error: $e");
    } finally {
      _isCapturing = false;
    }
  }

  // Future<void> _stopVideoStream() async {
  //   if (_cameraController == null) return;
  //   if (!_cameraController!.value.isStreamingImages) return;
  //   await _cameraController!.stopImageStream();
  //   if (mounted) setState(() {
  //     _isStreaming = false;
  //     _plateRects = [];
  //     _lastPlateText = null;
  //   });
  // }

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final int width = image.width;
      final int height = image.height;

      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final nv21 = Uint8List(width * height * 3 ~/ 2);
      int offset = 0;

      for (int i = 0; i < height; i++) {
        nv21.setRange(offset, offset + width, yPlane, i * image.planes[0].bytesPerRow);
        offset += width;
      }

      for (int i = 0; i < height ~/ 2; i++) {
        for (int j = 0; j < width ~/ 2; j++) {
          nv21[offset++] = vPlane[i * image.planes[2].bytesPerRow + j];
          nv21[offset++] = uPlane[i * image.planes[1].bytesPerRow + j];
        }
      }

      final rotation = _rotationIntToImageRotation(camera.sensorOrientation);

      final metadata = InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: nv21, metadata: metadata);
    } catch (e) {
      debugPrint("Conversion failed: $e");
      return null;
    }
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _showMatchDialog(MatchResult result, {required bool isVehicle, String? vehicleNumber}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: result.matched ? Colors.red[100] : Colors.green[100],
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result.matched ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: result.matched ? Colors.red : Colors.green,
              size: 50,
            ),
            const SizedBox(height: 12),
            Text(
              result.matched ? "DANGER! Suspect Found" : "No Match Found",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: result.matched ? Colors.red[800] : Colors.green[800],
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.matched
                  ? (isVehicle
                  ? "Vehicle Detected: ${vehicleNumber ?? 'Unknown'}\nMatched ID: ${result.suspectId ?? 'Unknown'}"
                  : "Matched ID: ${result.suspectId ?? 'Unknown'}\nScore: ${result.score?.toStringAsFixed(2) ?? '0.00'}")
                  : "No matching suspect detected locally.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: result.matched ? Colors.red[700] : Colors.green[700],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text("Dismiss", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: result.matched ? Colors.grey[500] : Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                if (result.matched) const SizedBox(width: 10),
                if (result.matched)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      label: const Text("Escalate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Confirm Escalation"),
                            content: const Text("Are you sure to ESCALATE?"),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("No")),
                              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Yes")),
                            ],
                          ),
                        );
                        Navigator.of(context).pop();
                        if (confirm == true) {
                          // handle escalation
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void showAnimatedToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: _AnimatedToast(message: message),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Capture Criminal Vehicle", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: controller == null || !controller.value.isInitialized
          ? const Center(child: Text('Camera not available', style: TextStyle(color: Colors.white)))
          : Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize?.height,
                height: controller.value.previewSize?.width,
                child: CameraPreview(controller),
              ),
            ),
          ),

          // Plate overlay (draw rectangles from OCR blocks)
          if (_plateRects.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: PlatePainter(_plateRects, controller!.value.previewSize!, _currentCameraIndex == 1, label: _lastPlateText),
              ),
            ),

          if (_isStreaming)
            const Positioned(
              top: 20,
              left: 20,
              child: Row(
                children: [
                  _BlinkingDot(),
                  SizedBox(width: 6),
                  Text("LIVE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Card(
                color: Colors.black45,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  icon: const Icon(Icons.switch_camera_outlined, color: Colors.white),
                  onPressed: _switchCamera,
                  tooltip: 'Switch Camera',
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _takePicture,
                      style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(18), backgroundColor: Colors.redAccent, elevation: 6),
                      child: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isStreaming ? _stopVideoStream : _startVideoStream,
                        icon: Icon(_isStreaming ? Icons.stop : Icons.videocam, color: Colors.white, size: 20),
                        label: Text(_isStreaming ? "Stop Live Detection" : "Start Live Scan", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black54, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper data class
class _PlateInfo {
  final String text;
  final Rect? box;
  _PlateInfo({required this.text, required this.box});
}

// Plate painter (draw plate rectangles + optional label)
class PlatePainter extends CustomPainter {
  final List<Rect> plates;
  final Size imageSize;
  final bool isFrontCamera;
  final String? label;
  PlatePainter(this.plates, this.imageSize, this.isFrontCamera, {this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final box in plates) {
      // ML Kit rect is in image coordinates width x height — map same as face painter
      final rect = Rect.fromLTRB(
        box.left * size.width / imageSize.height,
        box.top * size.height / imageSize.width,
        box.right * size.width / imageSize.height,
        box.bottom * size.height / imageSize.width,
      );

      final drawRect = isFrontCamera
          ? Rect.fromLTRB(size.width - rect.right, rect.top, size.width - rect.left, rect.bottom)
          : rect;

      canvas.drawRect(drawRect, fillPaint);
      canvas.drawRect(drawRect, borderPaint);

      if (label != null) {
        textPainter.text = TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold));
        textPainter.layout(maxWidth: drawRect.width);
        final offset = Offset(drawRect.left + 4, drawRect.top - textPainter.height - 4);
        final bgRect = Rect.fromLTWH(offset.dx - 6, offset.dy - 2, textPainter.width + 12, textPainter.height + 6);
        canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), Paint()..color = Colors.black54);
        textPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PlatePainter oldDelegate) {
    return oldDelegate.plates != plates || oldDelegate.label != label;
  }
}

// Blinking dot same as before
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({super.key});
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)])));
  }
}

class _AnimatedToast extends StatefulWidget {
  final String message;
  const _AnimatedToast({required this.message});
  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black87,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12), child: Text(widget.message, style: const TextStyle(color: Colors.white)))),
      ),
    );
  }
}

/// Simple async semaphore to limit concurrent OCR tasks
class _AsyncSemaphore {
  final int _max;
  int _current = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  _AsyncSemaphore(this._max);

  Future<void> acquire() {
    if (_current < _max) {
      _current++;
      return Future.value();
    } else {
      final completer = Completer<void>();
      _waiters.add(completer);
      return completer.future;
    }
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final w = _waiters.removeFirst();
      w.complete();
    } else {
      _current = max(0, _current - 1);
    }
  }
}
