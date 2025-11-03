
/*import 'dart:async';
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
import 'package:sensors_plus/sensors_plus.dart';
import '../models/match_services.dart';
import '../provider/vehicleMatchProvider.dart';
import '../pucc_validator.dart';
import '../services/geofence_Service.dart';
import '../video_player.dart';

class StolenVehicleDetectedPage extends StatefulWidget {
  const StolenVehicleDetectedPage({super.key});

  @override
  State<StolenVehicleDetectedPage> createState() => _StolenVehicleDetectedPageState();
}

// previous code
// class _StolenVehicleDetectedPageState extends State<StolenVehicleDetectedPage>
//     with WidgetsBindingObserver {
//   CameraController? _cameraController;
//   List<CameraDescription>? _cameras;
//   bool _isCameraInitializing = true;
//   bool _isStreaming = false;
//   bool _isProcessingFrame = false;
//   int _currentCameraIndex = 0;
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   late final TextRecognizer _textRecognizer;
//   bool _isCapturing = false;
//   Timer? _captureTimer;
//
//   // Plate overlay state (kept same)
//   List<Rect> _plateRects = [];
//   String? _lastPlateText;
//   DateTime? _lastOcrTime;
//
//   // streaming throttle (ms)
//   final int _streamThrottleMs = 500;
//   DateTime? _lastStreamProcess;
//
//   // grid configuration (2 x 5)
//   final int _rows = 2;
//   final int _cols = 5;
//   String _statusMessage = 'Processing...';
//
//   // concurrency limiter - how many zone OCRs run at once
//   final int _maxConcurrentOcr = 4;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     // Initialize only text recognizer (no face detector)
//     _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
//     _initEverything();
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _cameraController?.dispose();
//     _audioPlayer.dispose();
//     _textRecognizer.close();
//     super.dispose();
//   }
//
//   Future<void> _initEverything() async {
//     await _initCamera(index: 0);
//     if (!mounted) return;
//     Provider.of<VehicleMatchProvider>(context, listen: false).init();
//   }
//
//   Future<void> _initCamera({int index = 0}) async {
//     try {
//       _cameras = await availableCameras();
//       if (_cameras == null || _cameras!.isEmpty) {
//         if (mounted) setState(() => _isCameraInitializing = false);
//         return;
//       }
//
//       _currentCameraIndex = index.clamp(0, _cameras!.length - 1);
//       final cam = _cameras![_currentCameraIndex];
//
//       _cameraController = CameraController(
//         cam,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420,
//       );
//
//       await _cameraController!.initialize();
//       if (mounted) setState(() => _isCameraInitializing = false);
//     } catch (e) {
//       if (mounted) setState(() => _isCameraInitializing = false);
//       debugPrint('Camera init error: $e');
//     }
//   }
//
//   Future<void> _switchCamera() async {
//     if (_cameras == null || _cameras!.length < 2) return;
//     _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
//     if (mounted) setState(() => _isCameraInitializing = true);
//     await _cameraController?.dispose();
//     await _initCamera(index: _currentCameraIndex);
//   }
//
//   // ---------------- single-capture flow ----------------
//   Future<void> _takePicture() async {
//     if (_cameraController == null || !_cameraController!.value.isInitialized) return;
//
//     try {
//       if (_isStreaming) {
//         await _stopVideoStream();
//       }
//
//       setState(() => _isCapturing = true);
//
//       final xfile = await _cameraController!.takePicture();
//       final bytes = await xfile.readAsBytes();
//
//       final provider = Provider.of<VehicleMatchProvider>(context, listen: false);
//
//       // Run OCR for vehicle number
//       final recognized = await _runOcrOnBytes(bytes);
//       final plateInfo = _findPlateFromRecognized(recognized);
//       final String? detectedVehicleNumber = plateInfo?.text;
//       final Rect? plateBox = plateInfo?.box;
//
//       if (detectedVehicleNumber != null && detectedVehicleNumber.isNotEmpty) {
//         debugPrint("✅ Detected vehicle number (raw): $detectedVehicleNumber");
//
//         // Normalize before showing and matching
//         final String normalized = _normalizeForMatch(detectedVehicleNumber);
//
//         // Try match with normalized value
//         var vehicleMatch = await provider.matchVehicleNumber(normalized);
//         debugPrint("🔍 Provider match result for [$normalized] -> $vehicleMatch");
//
//         // Fallback: try other normalized variants
//         if (vehicleMatch == null) {
//           final alt = _alternateNormalizationVariants(normalized);
//           for (final v in alt) {
//             vehicleMatch = await provider.matchVehicleNumber(v);
//             debugPrint("🔍 Fallback try [$v] -> $vehicleMatch");
//             if (vehicleMatch != null) break;
//           }
//         }
//
//         // Show overlay with detected plate
//         _showPlateOverlay(plateBox, normalized);
//
//         if (vehicleMatch != null) {
//           // ✅ MATCHED - Show success dialog
//           final matchRes = MatchResult(
//             matched: true,
//             suspectId: vehicleMatch['id'],
//             score: 0.0,
//           );
//           await _handleMatchFound(matchRes, isVehicle: true, vehicleNumber: normalized);
//         } else {
//           // ❌ NOT MATCHED - Show "detected but not in database" dialog
//           await _showVehicleDetectedDialog(
//             normalized,
//             matched: false,
//             matchedRecord: null,
//           );
//         }
//       } else {
//         // No plate detected at all
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("❌ No vehicle registration detected"),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ Take picture error: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("⚠️ Error: ${e.toString()}"),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => _isCapturing = false);
//     }
//   }
//
//   Future<void> _handleMatchFound(MatchResult result,
//       {required bool isVehicle, String? vehicleNumber}) async {
//     if (!mounted) return;
//
//     // play different tone depending on type (we keep same asset names)
//     try {
//       if (isVehicle) {
//         await _audioPlayer.play(AssetSource("vehicleTone.mp3"));
//       } else {
//         await _audioPlayer.play(AssetSource("alert.mp3"));
//       }
//     } catch (e) {
//       debugPrint("Audio play error: $e");
//     }
//
//     await _showMatchDialog(
//         result, isVehicle: isVehicle, vehicleNumber: vehicleNumber);
//   }
//
//   // kept your dialog (same look)
//   Future<void> _showVehicleDetectedDialog(
//       String vehicleNo, {
//         required bool matched,
//         Map<String, dynamic>? matchedRecord,
//       }) async {
//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//         backgroundColor: Colors.white,
//         contentPadding: EdgeInsets.zero,
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header with gradient
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: matched
//                       ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
//                       : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
//                 ),
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(24),
//                   topRight: Radius.circular(24),
//                 ),
//               ),
//               child: Column(
//                 children: [
//                   Icon(
//                     matched ? Icons.warning_amber_rounded : Icons.check_circle_outline,
//                     color: Colors.white,
//                     size: 60,
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     matched ? 'VEHICLE MATCHED' : 'Vehicle Detected',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 20,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             // Content
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: matched
//                           ? Colors.red.withOpacity(0.1)
//                           : Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           Icons.confirmation_number,
//                           color: matched ? Colors.red : Colors.green,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'Vehicle Number',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                               Text(
//                                 vehicleNo,
//                                 style: TextStyle(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                   color: matched ? Colors.red : Colors.green,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     matched
//                         ? 'This vehicle is registered in the stolen database. Please take appropriate action.'
//                         : 'Vehicle detected successfully but not found in the stolen records.',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey[700],
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: matched ? Colors.grey[400] : const Color(0xFF4CAF50),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       child: const Text(
//                         'Dismiss',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ---------------- OCR helpers ----------------
//   Future<RecognizedText> _runOcrOnBytes(Uint8List bytes) async {
//     try {
//       // Try OCR on original first
//       final tmp = await _writeTempImage(bytes);
//       final inputImage = InputImage.fromFilePath(tmp.path);
//       final recognized = await _textRecognizer.processImage(inputImage);
//
//       if (recognized.text.trim().isNotEmpty) {
//         debugPrint("✅ Raw OCR text: ${recognized.text}");
//         return recognized;
//       } else {
//         debugPrint("❌ No plate detected, trying enhancement...");
//       }
//
//       // Try enhanced image
//       final enhanced = await _enhanceForOcr(bytes);
//       if (enhanced != null) {
//         final tmp2 = await _writeTempImage(enhanced);
//         final inputImage2 = InputImage.fromFilePath(tmp2.path);
//         final recognized2 = await _textRecognizer.processImage(inputImage2);
//
//         if (recognized2.text.trim().isNotEmpty) {
//           debugPrint("✅ Enhanced OCR text: ${recognized2.text}");
//           return recognized2;
//         } else {
//           debugPrint("❌ Still no plate detected after enhancement");
//         }
//
//         return recognized2;
//       }
//
//       return recognized;
//     } catch (e) {
//       debugPrint("⚠️ OCR error: $e");
//       rethrow;
//     }
//   }
//
//   Future<Uint8List?> _enhanceForOcr(Uint8List bytes) async {
//     try {
//       final decoded = img.decodeImage(bytes);
//       if (decoded == null) return null;
//
//       // Convert to grayscale
//       img.Image gray = img.grayscale(decoded);
//
//       // Increase contrast & brightness slightly using adjustColor
//       gray = img.adjustColor(gray, contrast: 1.2, brightness: 0.05);
//
//       // Simple threshold (manual)
//       for (int y = 0; y < gray.height; y++) {
//         for (int x = 0; x < gray.width; x++) {
//           final pixel = gray.getPixel(x, y);
//           final luma = img.getLuminance(pixel);
//           if (luma < 90) {
//             gray.setPixelRgba(x, y, 0, 0, 0, 255);
//           } else {
//             gray.setPixelRgba(x, y, 255, 255, 255, 255);
//           }
//         }
//       }
//
//       final out = img.encodeJpg(gray, quality: 85);
//       return Uint8List.fromList(out);
//     } catch (e) {
//       debugPrint("Enhance error: $e");
//       return null;
//     }
//   }
//
//   Future<io.File> _writeTempImage(Uint8List bytes) async {
//     final dir = await io.Directory.systemTemp.createTemp();
//     final file = io.File(p.join(dir.path, 'temp_${DateTime
//         .now()
//         .microsecondsSinceEpoch}.jpg'));
//     await file.writeAsBytes(bytes);
//     return file;
//   }
//
//   // ---------------- normalize helpers ----------------
//
//   /// Normalize OCR text to reduce common OCR mistakes:
//   /// - remove non-alphanumeric
//   /// - map O <-> 0, I <-> 1, B <-> 8, S <-> 5 (common confusions)
//   String normalizeOcrText(String text) {
//     String s = text.toUpperCase();
//     // remove spaces and unwanted chars first
//     s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
//     // Now apply replacements that reduce false negatives
//     // We prefer mapping letters that are often misread to digits and vice-versa.
//     // We'll use a canonical normalization that converts common letters to their
//     // more likely plate representation (0,1,8,5).
//     s = s
//         .replaceAll('O', '0')
//         .replaceAll('Q', '0') // sometimes Q ~ 0
//         .replaceAll('I', '1')
//         .replaceAll('L', '1') // L sometimes as 1
//         .replaceAll('Z', '2') // optional
//         .replaceAll('B', '8')
//         .replaceAll('S', '5');
//     return s;
//   }
//
//   /// Returns one or two alternate variants to try when a direct match fails.
//   /// e.g. if we converted O->0 in normalization and still no match, try O instead.
//   List<String> _alternateNormalizationVariants(String normalized) {
//     final List<String> variants = [];
//     // variant: swap 0 back to O
//     variants.add(normalized.replaceAll('0', 'O'));
//     // variant: swap 1 back to I
//     variants.add(normalized.replaceAll('1', 'I'));
//     // variant: swap 8 back to B
//     variants.add(normalized.replaceAll('8', 'B'));
//     // unique
//     return variants.toSet().toList();
//   }
//
//   _PlateInfo? _findPlateFromRecognized(RecognizedText recognized) {
//     final blocks = recognized.blocks;
//     for (var block in blocks) {
//       final bText = block.text ?? "";
//       final normalized = normalizeOcrText(bText);
//       final plate = _matchPlateRegex(normalized);
//       if (plate != null) {
//         final rect = block.boundingBox;
//         return _PlateInfo(text: plate, box: rect);
//       }
//       for (var line in block.lines) {
//         final lText = line.text ?? "";
//         final normalizedLine = normalizeOcrText(lText);
//         final plateLine = _matchPlateRegex(normalizedLine);
//         if (plateLine != null) {
//           final rect = line.boundingBox ?? block.boundingBox;
//           return _PlateInfo(text: plateLine, box: rect);
//         }
//       }
//     }
//
//     final whole = recognized.text ?? "";
//     final normalizedWhole = normalizeOcrText(whole);
//     final plateWhole = _matchPlateRegex(normalizedWhole);
//     if (plateWhole != null) {
//       return _PlateInfo(text: plateWhole, box: null);
//     }
//
//     return null;
//   }
//
//   // String? _matchPlateRegex(String normalized) {
//   //   // Indian style simplified: 2 letters + 1-2 digits + 1-2 letters + 3-4 digits
//   //   // Note: normalized text already has digits/letters mapped; match against pattern
//   //   final reg = RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{3,4}', caseSensitive: false);
//   //   final m = reg.firstMatch(normalized);
//   //   return m?.group(0);
//   // }
//
//
//   String? _matchPlateRegex(String normalized) {
//     normalized = normalized
//         .replaceAll(RegExp(r'[\n\r\s]+'), '')
//         .replaceAll(RegExp(r'[^A-Z0-9]'), '')
//         .toUpperCase();
//
//     // ✅ Smart OCR correction rules
//     normalized = normalized
//         .replaceAll(RegExp(r'(?<=D)1'), 'L') // D1 → DL
//         .replaceAll(RegExp(r'(?<=D)I'), 'L')
//         .replaceAllMapped(RegExp(r'(?<=\d)O(?=\d)'), (m) => '0')
//         .replaceAllMapped(RegExp(r'(?<=\d)O(?=$)'), (m) => '0')
//         .replaceAllMapped(RegExp(r'(?<=\d)O(?=[A-Z])'), (m) => '0')
//         .replaceAllMapped(
//         RegExp(r'(?<=[A-Z])5(?=[A-Z])'), (m) => 'S') // A5B → ASB
//         .replaceAllMapped(
//         RegExp(r'(?<=[A-Z])8(?=[A-Z])'), (m) => 'B'); // A8B → ABB
//
//     // ✅ Flexible regex for Indian plates
//     final reg = RegExp(
//       r'[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{3,4}',
//       caseSensitive: false,
//     );
//
//     final m = reg.firstMatch(normalized);
//
//     debugPrint("🧩 Cleaned OCR text: $normalized");
//
//     if (m != null) {
//       debugPrint("✅ Regex Matched Plate: ${m.group(0)}");
//       return m.group(0);
//     } else {
//       debugPrint("❌ No plate match found");
//       return null;
//     }
//   }
//
//   String _normalizeForMatch(String text) {
//     String normalized = text.toUpperCase();
//
//
//     normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
//
//     // Common OCR corrections
//     normalized = normalized
//         .replaceAll(RegExp(r'\bD1\b'), 'DL')
//         .replaceAll(RegExp(r'\bDI\b'), 'DL')
//         .replaceAll(RegExp(r'(?<=D)1'), 'L')
//         .replaceAll(RegExp(r'(?<=D)I'), 'L')
//
//         .replaceAll('8', 'B');
//
//
//     debugPrint("🧩 Corrected OCR text: $normalized");
//     return normalized;
//   }
//
//
//   void _showPlateOverlay(Rect? box, String plateText) {
//     if (!mounted) return;
//
//     setState(() {
//       _lastPlateText = plateText;
//       if (box != null) {
//         _plateRects = [box];
//       } else {
//         _plateRects = [];
//       }
//       _lastOcrTime = DateTime.now();
//     });
//
//     // Auto-hide after 3 seconds
//     Future.delayed(const Duration(seconds: 3), () {
//       if (mounted && _lastOcrTime != null) {
//         final elapsed = DateTime.now().difference(_lastOcrTime!);
//         if (elapsed.inSeconds >= 3) {
//           setState(() {
//             _plateRects = [];
//             _lastPlateText = null;
//           });
//         }
//       }
//     });
//   }
//
//
//   Future<void> _startVideoStream() async {
//     if (_cameraController == null || _cameraController!.value.isStreamingImages)
//       return;
//
//     if (mounted) setState(() => _isStreaming = true);
//
//     await _cameraController!.startImageStream((CameraImage image) async {
//       if (!_isStreaming || _isCapturing) return;
//
//       // Optional: handle frame throttling if needed
//     });
//
//     _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
//       if (!_isStreaming || _isCapturing) return;
//
//       _isCapturing = true;
//       await _takeVideosPicture();
//       _isCapturing = false;
//     });
//   }
//
//   Future<void> _stopVideoStream() async {
//     _captureTimer?.cancel();
//     _captureTimer = null;
//
//     if (_cameraController != null &&
//         _cameraController!.value.isStreamingImages) {
//       await _cameraController!.stopImageStream();
//     }
//
//     if (mounted) setState(() => _isStreaming = false);
//   }
//
//   Future<void> _takeVideosPicture() async {
//     if (_cameraController == null || !_cameraController!.value.isInitialized) return;
//
//     try {
//       final xfile = await _cameraController!.takePicture();
//       final bytes = await xfile.readAsBytes();
//
//       final provider = Provider.of<VehicleMatchProvider>(context, listen: false);
//
//       final recognized = await _runOcrOnBytes(bytes);
//       final plateInfo = _findPlateFromRecognized(recognized);
//       final String? detectedVehicleNumber = plateInfo?.text;
//       final Rect? plateBox = plateInfo?.box;
//
//       if (detectedVehicleNumber != null && detectedVehicleNumber.isNotEmpty) {
//         debugPrint("✅ Live scan detected: $detectedVehicleNumber");
//
//         // Normalize for matching
//         final String normalized = _normalizeForMatch(detectedVehicleNumber);
//         debugPrint("🧩 Normalized: $normalized");
//
//         // Show overlay with detected plate (this fixes the border issue)
//         if (plateBox != null) {
//           _showPlateOverlay(plateBox, normalized);
//         }
//
//         // Try matching with database
//         var vehicleMatch = await provider.matchVehicleNumber(normalized);
//         debugPrint("🔍 Provider match result for [$normalized] -> $vehicleMatch");
//
//         // Fallback tries
//         if (vehicleMatch == null) {
//           final alt = _alternateNormalizationVariants(normalized);
//           for (final v in alt) {
//             vehicleMatch = await provider.matchVehicleNumber(v);
//             debugPrint("🔍 Fallback try [$v] -> $vehicleMatch");
//             if (vehicleMatch != null) break;
//           }
//         }
//
//         // If match found, stop scanning and show dialog
//         if (vehicleMatch != null) {
//           await _stopVideoStream();
//           final matchRes = MatchResult(
//             matched: true,
//             suspectId: vehicleMatch['id'],
//             score: 0.0,
//           );
//           await _handleMatchFound(matchRes, isVehicle: true, vehicleNumber: normalized);
//         } else {
//           // Show temporary overlay but continue scanning
//           debugPrint("ℹ️ No match found for $normalized, continuing scan...");
//         }
//       } else {
//         debugPrint("⚠️ No plate detected in this frame");
//       }
//     } catch (e) {
//       debugPrint("❌ Live scan error: $e");
//     }
//   }
//
//   /// Convert CameraImage (YUV420) to package:image Image (rgb)
//   // imgLib.Image? _convertYUV420ToImage(CameraImage image) {
//   //   try {
//   //     final int width = image.width;
//   //     final int height = image.height;
//   //     final imgLib.Image imgOut = imgLib.Image(width: width, height: height);
//   //
//   //     final Plane planeY = image.planes[0];
//   //     final Plane planeU = image.planes[1];
//   //     final Plane planeV = image.planes[2];
//   //
//   //     final Uint8List yBuf = planeY.bytes;
//   //     final Uint8List uBuf = planeU.bytes;
//   //     final Uint8List vBuf = planeV.bytes;
//   //
//   //     final int strideY = planeY.bytesPerRow;
//   //     final int strideU = planeU.bytesPerRow;
//   //     final int strideV = planeV.bytesPerRow;
//   //
//   //     for (int y = 0; y < height; y++) {
//   //       for (int x = 0; x < width; x++) {
//   //         final int yIndex = y * strideY + x;
//   //         final int uvIndex = (y >> 1) * strideU + (x >> 1);
//   //
//   //         final int Y = yBuf[yIndex] & 0xff;
//   //         final int U = uBuf[uvIndex] & 0xff;
//   //         final int V = vBuf[uvIndex] & 0xff;
//   //
//   //         // YUV to RGB conversion
//   //         int r = (Y + (1.370705 * (V - 128))).round();
//   //         int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).round();
//   //         int b = (Y + (1.732446 * (U - 128))).round();
//   //
//   //         r = r.clamp(0, 255);
//   //         g = g.clamp(0, 255);
//   //         b = b.clamp(0, 255);
//   //
//   //         imgOut.setPixelRgba(x, y, r, g, b, 255);
//   //       }
//   //     }
//   //     return imgOut;
//   //   } catch (e) {
//   //     debugPrint("YUV->RGB conversion failed: $e");
//   //     return null;
//   //   }
//   // }
//   //
//   // Future<void> _processZonesAndDetect(imgLib.Image fullRgbImage) async {
//   //   // Determine grid crop sizes
//   //   final int zoneW = (fullRgbImage.width / _cols).floor();
//   //   final int zoneH = (fullRgbImage.height / _rows).floor();
//   //
//   //   // Prepare temp dir for zone images
//   //   final dir = await io.Directory.systemTemp.createTemp('zones_${DateTime
//   //       .now()
//   //       .microsecondsSinceEpoch}');
//   //
//   //   final provider = Provider.of<VehicleMatchProvider>(context, listen: false);
//   //
//   //   // We'll process zones in small batches to limit concurrency
//   //   final List<Future<void>> zoneFutures = [];
//   //   final sem = _AsyncSemaphore(_maxConcurrentOcr);
//   //
//   //   bool foundAndMatched = false;
//   //
//   //   for (int r = 0; r < _rows; r++) {
//   //     for (int c = 0; c < _cols; c++) {
//   //       if (foundAndMatched) break;
//   //
//   //       final int left = c * zoneW;
//   //       final int top = r * zoneH;
//   //       final int w = (c == _cols - 1) ? (fullRgbImage.width - left) : zoneW;
//   //       final int h = (r == _rows - 1) ? (fullRgbImage.height - top) : zoneH;
//   //
//   //       // Create crop
//   //       final imgLib.Image? crop = imgLib.copyCrop(
//   //         fullRgbImage,
//   //         x: left,
//   //         y: top,
//   //         width: w,
//   //         height: h,
//   //       );
//   //
//   //       if (crop == null) {
//   //         debugPrint("Crop failed for zone $r,$c");
//   //         continue;
//   //       }
//   //
//   //       // Encode crop to jpg bytes
//   //       final Uint8List jpgBytes = Uint8List.fromList(
//   //           imgLib.encodeJpg(crop, quality: 75));
//   //
//   //       // Write to file
//   //       final file = io.File(p.join(dir.path, 'zone_${r}_$c.jpg'));
//   //       await file.writeAsBytes(jpgBytes);
//   //
//   //       // enqueue OCR for this zone using semaphore
//   //       final fut = () async {
//   //         await sem.acquire();
//   //         try {
//   //           if (foundAndMatched) return;
//   //
//   //           final inputImage = InputImage.fromFilePath(file.path);
//   //           final recognized = await _textRecognizer.processImage(inputImage);
//   //           final plateInfo = _findPlateFromRecognized(recognized);
//   //           if (plateInfo != null && plateInfo.text.isNotEmpty) {
//   //             final detectedNumberRaw = plateInfo.text;
//   //             final detectedNumber = _normalizeForMatch(detectedNumberRaw);
//   //             debugPrint(
//   //                 "Zone Detected (raw): $detectedNumberRaw at r:$r c:$c");
//   //             debugPrint(
//   //                 "Zone Detected (normalized): $detectedNumber at r:$r c:$c");
//   //
//   //             // map small crop bbox to full image coordinates (if line bbox exists)
//   //             Rect? mappedRect;
//   //             if (plateInfo.box != null) {
//   //               final Rect small = plateInfo.box!;
//   //               // small is relative to the crop image; map to full image
//   //               mappedRect = Rect.fromLTWH(
//   //                 left + small.left,
//   //                 top + small.top,
//   //                 small.width,
//   //                 small.height,
//   //               );
//   //             }
//   //
//   //             // show overlay mapped to MLKit preview later
//   //             _showPlateOverlay(mappedRect, detectedNumber);
//   //
//   //             // match with provider (normalized)
//   //             var vehicleMatch = await provider.matchVehicleNumber(
//   //                 detectedNumber);
//   //             debugPrint(
//   //                 "🔍 Provider match for [$detectedNumber] -> $vehicleMatch");
//   //
//   //             if (vehicleMatch == null) {
//   //               // fallback try a few alternate forms
//   //               final alt = _alternateNormalizationVariants(detectedNumber);
//   //               for (final v in alt) {
//   //                 vehicleMatch = await provider.matchVehicleNumber(v);
//   //                 debugPrint("🔍 Fallback try [$v] -> $vehicleMatch");
//   //                 if (vehicleMatch != null) break;
//   //               }
//   //             }
//   //
//   //             if (vehicleMatch != null) {
//   //               foundAndMatched = true;
//   //               final matchRes = MatchResult(
//   //                   matched: true, suspectId: vehicleMatch['id'], score: 0.0);
//   //               await _handleMatchFound(
//   //                   matchRes, isVehicle: true, vehicleNumber: detectedNumber);
//   //               // Stop stream after a match (you can change this behavior)
//   //               await _stopVideoStream();
//   //             } else {
//   //               debugPrint("✖ No DB match for detected plate: $detectedNumber");
//   //             }
//   //           }
//   //         } catch (e) {
//   //           debugPrint("Zone OCR error: $e");
//   //         } finally {
//   //           sem.release();
//   //         }
//   //       }();
//   //       zoneFutures.add(fut);
//   //     }
//   //     if (foundAndMatched) break;
//   //   }
//   //
//   //   // Wait for all zones to finish (or at least started)
//   //   await Future.wait(zoneFutures);
//   //
//   //   // cleanup temp dir
//   //   try {
//   //     if (await dir.exists()) {
//   //       await dir.delete(recursive: true);
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Temp dir cleanup error: $e");
//   //   }
//   // }
//   //
//   // Future<void> _takeVideoPicture() async {
//   //   if (_cameraController == null || !_cameraController!.value.isInitialized)
//   //     return;
//   //   if (_isCapturing) return;
//   //   _isCapturing = true;
//   //
//   //   try {
//   //     // Capture still frame
//   //     final xfile = await _cameraController!.takePicture();
//   //     final bytes = await xfile.readAsBytes();
//   //     final imgLib.Image? original = imgLib.decodeImage(bytes);
//   //     if (original == null) return;
//   //
//   //     // 🔹 Step 1: Preprocess image
//   //     final imgLib.Image preprocessed = imgLib.adjustColor(
//   //       imgLib.copyResize(original, width: 640, height: 640),
//   //       brightness: 0.1,
//   //       contrast: 1.5,
//   //     );
//   //
//   //     // Convert back to bytes for OCR
//   //     final processedBytes = Uint8List.fromList(imgLib.encodeJpg(preprocessed));
//   //
//   //     // 🔹 Step 2: Try OCR multiple times (retry logic)
//   //     String? detectedText;
//   //     int retry = 0;
//   //     while (retry < 3 && (detectedText == null || detectedText.isEmpty)) {
//   //       final recognized = await _runOcrOnBytes(processedBytes);
//   //       final plateInfo = _findPlateFromRecognized(recognized);
//   //       detectedText = plateInfo?.text.trim();
//   //       retry++;
//   //       if (detectedText == null || detectedText.isEmpty) {
//   //         await Future.delayed(const Duration(milliseconds: 300));
//   //       }
//   //     }
//   //
//   //     if (detectedText != null && detectedText.isNotEmpty) {
//   //       final normalized = _normalizeForMatch(detectedText);
//   //       _showPlateOverlay(null, normalized);
//   //
//   //       final provider = Provider.of<VehicleMatchProvider>(
//   //           context, listen: false);
//   //       var vehicleMatch = await provider.matchVehicleNumber(normalized);
//   //       debugPrint(
//   //           "🔍 Provider match for (capture) [$normalized] -> $vehicleMatch");
//   //
//   //       if (vehicleMatch == null) {
//   //         final alt = _alternateNormalizationVariants(normalized);
//   //         for (final v in alt) {
//   //           vehicleMatch = await provider.matchVehicleNumber(v);
//   //           debugPrint("🔍 Fallback try (capture) [$v] -> $vehicleMatch");
//   //           if (vehicleMatch != null) break;
//   //         }
//   //       }
//   //
//   //       if (vehicleMatch != null) {
//   //         await _stopVideoStream();
//   //         await _handleMatchFound(
//   //           MatchResult(
//   //               matched: true, suspectId: vehicleMatch['id'], score: 0.0),
//   //           isVehicle: true,
//   //           vehicleNumber: normalized,
//   //         );
//   //       } else {
//   //         await _showVehicleDetectedDialog(
//   //             normalized, matched: false, matchedRecord: null);
//   //       }
//   //     } else {
//   //       debugPrint("⚠️ No number detected even after retries.");
//   //     }
//   //   } catch (e) {
//   //     debugPrint("❌ Take video-picture error: $e");
//   //   } finally {
//   //     _isCapturing = false;
//   //   }
//   // }
//   //
//   // // Future<void> _stopVideoStream() async {
//   // //   if (_cameraController == null) return;
//   // //   if (!_cameraController!.value.isStreamingImages) return;
//   // //   await _cameraController!.stopImageStream();
//   // //   if (mounted) setState(() {
//   // //     _isStreaming = false;
//   // //     _plateRects = [];
//   // //     _lastPlateText = null;
//   // //   });
//   // // }
//   //
//   // InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
//   //   try {
//   //     final int width = image.width;
//   //     final int height = image.height;
//   //
//   //     final yPlane = image.planes[0].bytes;
//   //     final uPlane = image.planes[1].bytes;
//   //     final vPlane = image.planes[2].bytes;
//   //
//   //     final nv21 = Uint8List(width * height * 3 ~/ 2);
//   //     int offset = 0;
//   //
//   //     for (int i = 0; i < height; i++) {
//   //       nv21.setRange(
//   //           offset, offset + width, yPlane, i * image.planes[0].bytesPerRow);
//   //       offset += width;
//   //     }
//   //
//   //     for (int i = 0; i < height ~/ 2; i++) {
//   //       for (int j = 0; j < width ~/ 2; j++) {
//   //         nv21[offset++] = vPlane[i * image.planes[2].bytesPerRow + j];
//   //         nv21[offset++] = uPlane[i * image.planes[1].bytesPerRow + j];
//   //       }
//   //     }
//   //
//   //     final rotation = _rotationIntToImageRotation(camera.sensorOrientation);
//   //
//   //     final metadata = InputImageMetadata(
//   //       size: Size(width.toDouble(), height.toDouble()),
//   //       rotation: rotation,
//   //       format: InputImageFormat.nv21,
//   //       bytesPerRow: image.planes[0].bytesPerRow,
//   //     );
//   //
//   //     return InputImage.fromBytes(bytes: nv21, metadata: metadata);
//   //   } catch (e) {
//   //     debugPrint("Conversion failed: $e");
//   //     return null;
//   //   }
//   // }
//   //
//   // InputImageRotation _rotationIntToImageRotation(int rotation) {
//   //   switch (rotation) {
//   //     case 0:
//   //       return InputImageRotation.rotation0deg;
//   //     case 90:
//   //       return InputImageRotation.rotation90deg;
//   //     case 180:
//   //       return InputImageRotation.rotation180deg;
//   //     case 270:
//   //       return InputImageRotation.rotation270deg;
//   //     default:
//   //       return InputImageRotation.rotation0deg;
//   //   }
//   // }
//
//   Future<void> _showMatchDialog(MatchResult result,
//       {required bool isVehicle, String? vehicleNumber}) async {
//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) =>
//           AlertDialog(
//             shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20)),
//             backgroundColor: result.matched ? Colors.red[100] : Colors
//                 .green[100],
//             contentPadding: const EdgeInsets.all(16),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   result.matched ? Icons.warning_amber_rounded : Icons
//                       .check_circle_outline,
//                   color: result.matched ? Colors.red : Colors.green,
//                   size: 50,
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   result.matched ? "DANGER! Suspect Found" : "No Match Found",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: result.matched ? Colors.red[800] : Colors.green[800],
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   result.matched
//                       ? (isVehicle
//                       ? "Vehicle Detected: ${vehicleNumber ??
//                       'Unknown'}\nMatched ID: ${result.suspectId ?? 'Unknown'}"
//                       : "Matched ID: ${result.suspectId ??
//                       'Unknown'}\nScore: ${result.score?.toStringAsFixed(2) ??
//                       '0.00'}")
//                       : "No matching suspect detected locally.",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: result.matched ? Colors.red[700] : Colors.green[700],
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         icon: const Icon(Icons.close, color: Colors.white),
//                         label: const Text("Dismiss", style: TextStyle(
//                             color: Colors.white, fontWeight: FontWeight.bold)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: result.matched
//                               ? Colors.grey[500]
//                               : Colors.green,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12)),
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         onPressed: () async {
//                           Navigator.of(context).pop(); // close dialog first
//                           setState(() {
//                             _isCapturing = true;
//                             _statusMessage = 'Processing...';
//                           });
//
//                           // simulate short processing delay (like saving or updating)
//                           await Future.delayed(const Duration(seconds: 2));
//
//                           setState(() {
//                             _statusMessage = '✅ Successful';
//                           });
//
//                           // hide after short delay
//                           await Future.delayed(const Duration(seconds: 1));
//                           setState(() {
//                             _isCapturing = false;
//                           });
//                         },
//                       ),
//                     ),
//                     if (result.matched) const SizedBox(width: 10),
//                     if (result.matched)
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           icon: const Icon(
//                               Icons.warning_amber_rounded, color: Colors.white),
//                           label: const Text("Escalate", style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold)),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.red,
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           onPressed: () async {
//                             final confirm = await showDialog<bool>(
//                               context: context,
//                               builder: (context) =>
//                                   AlertDialog(
//                                     title: const Text("Confirm Escalation"),
//                                     content: const Text(
//                                         "Are you sure to ESCALATE?"),
//                                     shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(
//                                             15)),
//                                     actions: [
//                                       TextButton(onPressed: () =>
//                                           Navigator.of(context).pop(false),
//                                           child: const Text("No")),
//                                       ElevatedButton(onPressed: () =>
//                                           Navigator.of(context).pop(true),
//                                           style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.red),
//                                           child: const Text("Yes")),
//                                     ],
//                                   ),
//                             );
//                             Navigator.of(context).pop();
//                             if (confirm == true) {
//                               setState(() {
//                                 _isCapturing = true;
//                                 _statusMessage = 'Processing...';
//                               });
//
//                               // Simulate escalation process
//                               await Future.delayed(const Duration(seconds: 2));
//
//                               setState(() {
//                                 _statusMessage = '✅ Successful';
//                               });
//
//                               await Future.delayed(const Duration(seconds: 1));
//                               setState(() {
//                                 _isCapturing = false;
//                               });
//                             }
//
//                           },
//                         ),
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//     );
//   }
//
//   void showAnimatedToast(BuildContext context, String message) {
//     final overlay = Overlay.of(context);
//     if (overlay == null) return;
//     final overlayEntry = OverlayEntry(
//       builder: (context) =>
//           Positioned(
//             bottom: 100,
//             left: 20,
//             right: 20,
//             child: Material(
//               color: Colors.transparent,
//               child: _AnimatedToast(message: message),
//             ),
//           ),
//     );
//     overlay.insert(overlayEntry);
//     Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isCameraInitializing) {
//       return Scaffold(
//         body: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//           child: const Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircularProgressIndicator(color: Colors.white),
//                 SizedBox(height: 16),
//                 Text(
//                   'Initializing Camera...',
//                   style: TextStyle(color: Colors.white, fontSize: 16),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }
//
//     final controller = _cameraController;
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: controller == null || !controller.value.isInitialized
//           ? const Center(
//         child: Text(
//           'Camera not available',
//           style: TextStyle(color: Colors.white, fontSize: 18),
//         ),
//       )
//           : Stack(
//         children: [
//           // Camera Preview
//           Positioned.fill(
//             child: FittedBox(
//               fit: BoxFit.cover,
//               child: SizedBox(
//                 width: controller.value.previewSize?.height,
//                 height: controller.value.previewSize?.width,
//                 child: CameraPreview(controller),
//               ),
//             ),
//           ),
//
//           // Dark overlay for better visibility
//           if (_isStreaming)
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.3),
//                       Colors.transparent,
//                       Colors.transparent,
//                       Colors.black.withOpacity(0.5),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//
//           // Plate overlay
//           if (_plateRects.isNotEmpty)
//             Positioned.fill(
//               child: CustomPaint(
//                 painter: PlatePainter(
//                   _plateRects,
//                   controller.value.previewSize!,
//                   _currentCameraIndex == 1,
//                   label: _lastPlateText,
//                 ),
//               ),
//             ),
//
//           // Top Bar with Back Button and Status
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: SafeArea(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 12),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.7),
//                       Colors.transparent,
//                     ],
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     // Back Button
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: IconButton(
//                         icon: const Icon(
//                             Icons.arrow_back_ios_new, color: Colors.white),
//                         onPressed: () => Navigator.pop(context),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//
//                     // Title
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Vehicle Scanner',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           if (_isStreaming)
//                             const Text(
//                               'Scanning for plates...',
//                               style: TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 12,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//
//                     // Live Status Indicator
//                     if (_isStreaming) _buildLiveIndicator(),
//
//                     const SizedBox(width: 12),
//
//                     // Camera Switch Button
//                     if (_cameras != null && _cameras!.length > 1)
//                       Container(
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: IconButton(
//                           icon: const Icon(Icons.flip_camera_ios, color: Colors
//                               .white),
//                           onPressed: _switchCamera,
//                           tooltip: 'Switch Camera',
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           // Scanning Animation Overlay
//           if (_isStreaming) _buildScanningOverlay(),
//
//           // Bottom Control Bar
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: SafeArea(
//               child: Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.bottomCenter,
//                     end: Alignment.topCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.8),
//                       Colors.transparent,
//                     ],
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Capture Button
//                     _buildCaptureButton(),
//                     const SizedBox(width: 20),
//                     // Live Scan Toggle Button
//                     Expanded(child: _buildLiveScanButton()),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           if (_isCapturing && !_isStreaming)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(0.5),
//                 child: Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (_statusMessage == 'Processing...')
//                         const CircularProgressIndicator(color: Colors.white),
//                       const SizedBox(height: 16),
//                       Text(
//                         _statusMessage,
//                         style: const TextStyle(color: Colors.white, fontSize: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
// // Live Status Indicator Widget
//   Widget _buildLiveIndicator() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.red.withOpacity(0.9),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.red.withOpacity(0.5),
//             blurRadius: 8,
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: const Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _BlinkingDot(),
//           SizedBox(width: 6),
//           Text(
//             'LIVE',
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//               letterSpacing: 1,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
// // Scanning Animation Overlay
//   Widget _buildScanningOverlay() {
//     return Positioned.fill(
//       child: CustomPaint(
//         painter: ScanningLinePainter(
//           animation: _isStreaming,
//         ),
//       ),
//     );
//   }
//
//
// // Capture Button
//   Widget _buildCaptureButton() {
//     return GestureDetector(
//       onTap: _isStreaming ? null : _takePicture,
//       child: Container(
//         width: 70,
//         height: 70,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: _isStreaming
//               ? Colors.grey.withOpacity(0.5)
//               : Colors.white,
//           border: Border.all(
//             color: Colors.white,
//             width: 4,
//           ),
//           boxShadow: _isStreaming
//               ? []
//               : [
//             BoxShadow(
//               color: Colors.white.withOpacity(0.5),
//               blurRadius: 20,
//               spreadRadius: 5,
//             ),
//           ],
//         ),
//         child: Center(
//           child: Icon(
//             Icons.camera_alt,
//             color: _isStreaming ? Colors.white : const Color(0xFF1A237E),
//             size: 32,
//           ),
//         ),
//       ),
//     );
//   }
//
// // Live Scan Toggle Button
//   Widget _buildLiveScanButton() {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 300),
//       child: ElevatedButton.icon(
//         onPressed: _isStreaming ? _stopVideoStream : _startVideoStream,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _isStreaming
//               ? Colors.red.withOpacity(0.9)
//               : const Color(0xFF4CAF50),
//           foregroundColor: Colors.white,
//           padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           elevation: _isStreaming ? 8 : 4,
//           shadowColor: _isStreaming
//               ? Colors.red.withOpacity(0.5)
//               : Colors.green.withOpacity(0.5),
//         ),
//         icon: AnimatedSwitcher(
//           duration: const Duration(milliseconds: 300),
//           child: Icon(
//             _isStreaming ? Icons.stop_circle_outlined : Icons
//                 .play_circle_outline,
//             key: ValueKey(_isStreaming),
//             size: 24,
//           ),
//         ),
//         label: Text(
//           _isStreaming ? 'Stop Live Scan' : 'Start Live Scan',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             letterSpacing: 0.5,
//           ),
//         ),
//       ),
//     );
//   }
//
// }

// Scanning Line Painter for visual feedback

class _StolenVehicleDetectedPageState extends State<StolenVehicleDetectedPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitializing = true;
  int _currentCameraIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final TextRecognizer _textRecognizer;

  // PUCC Workflow state
  bool _isPUCCWorkflowActive = false;
  int _puccStep = 0; // 0=idle, 1=photo1, 2=photo2, 3=video
  bool _isStationaryDetected = false;
  Timer? _stationaryTimer;
  Timer? _captureTimer;

  // Detected numbers from each capture
  String? _detectedNumber1;
  String? _detectedNumber2;
  String? _detectedNumberVideo;
  String? _videoPath;

  // Stationary detection
  List<double> _accelerometerHistory = [];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initEverything();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _audioPlayer.dispose();
    _textRecognizer.close();
    _stationaryTimer?.cancel();
    _captureTimer?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initEverything() async {
    await _initCamera(index: 0);
    if (!mounted) return;
    Provider.of<VehicleMatchProvider>(context, listen: false).init();
    _startStationaryDetection();
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
        ResolutionPreset.high,
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

  // ============ STATIONARY DETECTION ============
  void _startStationaryDetection() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _accelerometerHistory.add(magnitude);

      // Keep last 50 readings (1 sec @ 50Hz)
      if (_accelerometerHistory.length > 50) {
        _accelerometerHistory.removeAt(0);
      }

      // Check if device is stationary (low variance)
      if (_accelerometerHistory.length == 50) {
        final mean = _accelerometerHistory.reduce((a, b) => a + b) / 50;
        final variance = _accelerometerHistory
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) / 50;

        // If variance < threshold, device is still
        if (variance < 0.05 && !_isStationaryDetected && !_isPUCCWorkflowActive) {
          _onDeviceStationary();
        } else if (variance >= 0.05 && _isStationaryDetected) {
          _resetStationaryDetection();
        }
      }
    });
  }

  void _onDeviceStationary() {
    if (_isStationaryDetected) return;

    setState(() => _isStationaryDetected = true);
    debugPrint("📱 Device is stationary, starting 5-second countdown...");

    _stationaryTimer = Timer(const Duration(seconds: 5), () {
      if (_isStationaryDetected && !_isPUCCWorkflowActive) {
        _startPUCCWorkflow();
      }
    });
  }

  void _resetStationaryDetection() {
    setState(() => _isStationaryDetected = false);
    _stationaryTimer?.cancel();
    debugPrint("📱 Movement detected, resetting stationary timer");
  }

  // ============ PUCC WORKFLOW ============
  Future<void> _startPUCCWorkflow() async {
    if (_isPUCCWorkflowActive) return;

    setState(() {
      _isPUCCWorkflowActive = true;
      _puccStep = 0;
      _detectedNumber1 = null;
      _detectedNumber2 = null;
      _detectedNumberVideo = null;
    });

    debugPrint("🚀 Starting PUCC Workflow");

    // 🔊 Step 1
    await _playBeep();
    await Future.delayed(const Duration(milliseconds: 400));
    await _capturePhoto1();

    // 🕐 Wait
    await Future.delayed(const Duration(seconds: 5));

    // 🔊 Step 2
    await _playBeep();
    await Future.delayed(const Duration(milliseconds: 400));
    await _capturePhoto2();

    // 🕐 Wait again
    await Future.delayed(const Duration(seconds: 5));

    // 🔊 Step 3
    await _playBeep();
    await Future.delayed(const Duration(milliseconds: 400));
    await _captureVideo();

    // ✅ Show all results
    _showPUCCResults();
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.play(AssetSource("vehicleTone.mp3"));
    } catch (e) {
      debugPrint("Beep error: $e");
    }
  }

  // ============ CAPTURE METHODS ============
  Future<void> _capturePhoto1() async {
    setState(() => _puccStep = 1);
    debugPrint("📸 Capturing Photo 1...");

    try {
      // 1️⃣ GPS validation (you can bypass for testing)
      bool withinGeofence = true; // ✅ set false to re-enable strict mode
      // bool withinGeofence = await GeofencingService.isInsideAnyGeofence();
      if (!withinGeofence) {
        _showValidationError("GPS out of bounds - must be at testing site");
        return;
      }

      // 2️⃣ Capture image
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      // 3️⃣ Anti-spoof checks (works properly with balanced threshold)
      final antiSpoofResults = await AntiSpoofEngine.runAntiSpoofChecks(bytes);
      debugPrint("🔍 Anti-spoof results: $antiSpoofResults");

      if (antiSpoofResults['is_spoofed'] == true &&
          (antiSpoofResults['printed_texture'] == true ||
              antiSpoofResults['pixel_grid'] == true)) {
        _showValidationError("⚠️ Spoof detected — please capture real vehicle number plate.");
        await ComplianceLogger.logValidationFailure(
          reason: "Anti-spoof failed",
          operatorId: "OPERATOR_001",
        );
        return;
      }

      // 4️⃣ Verify surroundings
      final surroundingsResults = await SurroundingsDetector.verifySurroundings(bytes);
      if (!surroundingsResults['context_valid']) {
        _showValidationError("Invalid surroundings — vehicle base not detected.");
        return;
      }

      // 5️⃣ OCR extraction
      final recognized = await _runOcrOnBytes(bytes);
      final plateInfo = _findPlateFromRecognized(recognized);
      _detectedNumber1 = plateInfo?.text;

      // 6️⃣ GPS metadata
      final gpsMetadata = await PUCCValidator.getGPSMetadata();

      // 7️⃣ Log compliance
      await ComplianceLogger.logPUCCSession(
        operatorId: "OPERATOR_001",
        vehicleNumber: _detectedNumber1 ?? "Unknown",
        captureResults: [_detectedNumber1 ?? "None"],
        gpsMetadata: gpsMetadata,
        antiSpoofResults: antiSpoofResults,
        surroundingsResults: surroundingsResults,
        finalStatus: "in_progress",
      );

      debugPrint("✅ Photo 1 captured. Detected: ${_detectedNumber1 ?? 'None'}");
    } catch (e) {
      debugPrint("❌ Photo 1 error: $e");
    }
  }


  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("❌ Validation Failed"),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPUCCWorkflow();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto2() async {
    setState(() => _puccStep = 2);
    debugPrint("📸 Capturing Photo 2...");

    try {
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      final recognized = await _runOcrOnBytes(bytes);
      final plateInfo = _findPlateFromRecognized(recognized);
      _detectedNumber2 = plateInfo?.text;

      debugPrint("✅ Photo 2 captured. Detected: ${_detectedNumber2 ?? 'None'}");
    } catch (e) {
      debugPrint("❌ Photo 2 error: $e");
    }
  }

  Future<void> _captureVideo() async {
    setState(() => _puccStep = 3);
    debugPrint("🎥 Capturing Video...");

    try {
      await _cameraController!.startVideoRecording();
      await Future.delayed(const Duration(seconds: 3)); // 3-second video
      final recordedFile = await _cameraController!.stopVideoRecording();

      _videoPath = recordedFile.path; // ✅ Save video path
      debugPrint("✅ Video captured at: $_videoPath");

      _detectedNumberVideo = "Video captured - frame extraction needed";
    } catch (e) {
      debugPrint("❌ Video error: $e");
    }
  }


  // ============ RESULTS DIALOG ============
  void _showPUCCResults() {
    final finalNumber = _detectedNumber1 ?? _detectedNumber2 ?? _detectedNumberVideo ?? "Not detected";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('PUCC Workflow'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('Photo 1:', _detectedNumber1 ?? 'Not detected'),
              const SizedBox(height: 8),
              _buildResultRow('Photo 2:', _detectedNumber2 ?? 'Not detected'),
              const SizedBox(height: 8),
              _buildResultRow('Video:', _detectedNumberVideo ?? 'Not detected'),
              const Divider(height: 24),
              Text(
                'Final Registration: $finalNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 16),

              // 👇 Video preview section
              if (_videoPath != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Captured Video Preview:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(videoPath: _videoPath!),
                    ),
                  ],
                ),
            ],
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPUCCWorkflow();
            },
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Save to PUCC database
              _resetPUCCWorkflow();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save Certificate'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: value == 'Not detected' ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _resetPUCCWorkflow() {
    setState(() {
      _isPUCCWorkflowActive = false;
      _puccStep = 0;
      _isStationaryDetected = false;
      _detectedNumber1 = null;
      _detectedNumber2 = null;
      _detectedNumberVideo = null;
    });
    _accelerometerHistory.clear();
  }

  // ============ REUSE SONU'S OCR LOGIC ============
  Future<RecognizedText> _runOcrOnBytes(Uint8List bytes) async {
    try {
      final tmp = await _writeTempImage(bytes);
      final inputImage = InputImage.fromFilePath(tmp.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      if (recognized.text.trim().isNotEmpty) {
        debugPrint("✅ Raw OCR text: ${recognized.text}");
        return recognized;
      }

      // Try enhanced image
      final enhanced = await _enhanceForOcr(bytes);
      if (enhanced != null) {
        final tmp2 = await _writeTempImage(enhanced);
        final inputImage2 = InputImage.fromFilePath(tmp2.path);
        final recognized2 = await _textRecognizer.processImage(inputImage2);
        if (recognized2.text.trim().isNotEmpty) {
          debugPrint("✅ Enhanced OCR text: ${recognized2.text}");
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

      img.Image gray = img.grayscale(decoded);
      gray = img.adjustColor(gray, contrast: 1.2, brightness: 0.05);

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

  _PlateInfo? _findPlateFromRecognized(RecognizedText recognized) {
    final blocks = recognized.blocks;
    for (var block in blocks) {
      final bText = block.text ?? "";
      final normalized = _normalizeOcrText(bText);
      final plate = _matchPlateRegex(normalized);
      if (plate != null) {
        return _PlateInfo(text: plate, box: block.boundingBox);
      }
    }
    return null;
  }

  String _normalizeOcrText(String text) {
    String s = text.toUpperCase();
    s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    s = s
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('B', '8')
        .replaceAll('S', '5');
    return s;
  }

  String? _matchPlateRegex(String normalized) {
    final reg = RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{3,4}', caseSensitive: false);
    final m = reg.firstMatch(normalized);
    return m?.group(0);
  }

  // ============ UI BUILD ============
  @override
  Widget build(BuildContext context) {
    if (_isCameraInitializing) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: Text('Camera not available', style: TextStyle(color: Colors.white)))
          : Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // Status Overlay
          // Start Button
          if (!_isPUCCWorkflowActive)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _startPUCCWorkflow();
                  },
                  icon: const Icon(Icons.play_circle_fill, size: 28, color: Colors.white),
                  label: const Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),


          // Stationary Indicator
          if (_isStationaryDetected && !_isPUCCWorkflowActive)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✅ Device Stationary - Starting in 5s...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // Back Button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  String _getPUCCStepMessage() {
    switch (_puccStep) {
      case 1:
        return '📸 Capturing Photo 1...';
      case 2:
        return '📸 Capturing Photo 2...';
      case 3:
        return '🎥 Recording Video...';
      default:
        return 'Processing...';
    }
  }
}

class _PlateInfo {
  final String text;
  final Rect? box;
  _PlateInfo({required this.text, this.box});
}

class ScanningLinePainter extends CustomPainter {
  final bool animation;

  ScanningLinePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    if (!animation) return;

    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Draw scanning grid
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanWidth = size.width * 0.7;
    final scanHeight = size.height * 0.4;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanWidth,
      height: scanHeight,
    );

    // Draw shadow
    canvas.drawRect(rect, shadowPaint);

    // Draw main rect
    canvas.drawRect(rect, paint);

    // Draw corner indicators
    final cornerLength = 30.0;
    final corners = [
      // Top-left
      [Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top)],
      [Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength)],
      // Top-right
      [Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top)],
      [Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength)],
      // Bottom-left
      [Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom)],
      [Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength)],
      // Bottom-right
      [Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom)],
      [Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength)],
    ];

    final cornerPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
    }

    // Center text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'SCANNING FOR PLATES',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        rect.bottom + 20,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ScanningLinePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
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
    if (plates.isEmpty) return;

    // Border paint with glow effect
    final borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final glowPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final fillPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    for (final box in plates) {
      // Convert MLKit coordinates to screen coordinates
      // MLKit returns coordinates in image space (width x height)
      // We need to map to preview space (considering rotation)

      double scaleX = size.width / imageSize.height;
      double scaleY = size.height / imageSize.width;

      final rect = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );

      // Handle front camera mirror
      final drawRect = isFrontCamera
          ? Rect.fromLTRB(
        size.width - rect.right,
        rect.top,
        size.width - rect.left,
        rect.bottom,
      )
          : rect;

      // Draw glow
      canvas.drawRect(drawRect, glowPaint);

      // Draw fill
      canvas.drawRect(drawRect, fillPaint);

      // Draw border
      canvas.drawRect(drawRect, borderPaint);

      // Draw corner brackets
      _drawCornerBrackets(canvas, drawRect);

      // Draw label if provided
      if (label != null && label!.isNotEmpty) {
        _drawLabel(canvas, drawRect, label!);
      }
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const cornerSize = 25.0;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerSize, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerSize), paint);

    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerSize, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerSize), paint);

    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerSize, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerSize), paint);

    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerSize, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerSize), paint);
  }

  void _drawLabel(Canvas canvas, Rect rect, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Position label above the box
    final labelY = rect.top - textPainter.height - 12;
    final labelX = rect.left + (rect.width - textPainter.width) / 2;

    final bgRect = Rect.fromLTWH(
      labelX - 8,
      labelY - 4,
      textPainter.width + 16,
      textPainter.height + 8,
    );

    // Draw background
    final bgPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      bgPaint,
    );

    // Draw text
    textPainter.paint(canvas, Offset(labelX, labelY));
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
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
*/


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
import 'package:sensors_plus/sensors_plus.dart';
import '../models/match_services.dart';
import '../provider/vehicleMatchProvider.dart';
import '../pucc_validator.dart';
import '../services/geofence_Service.dart';
import '../video_player.dart';

class StolenVehicleDetectedPage extends StatefulWidget {
  const StolenVehicleDetectedPage({super.key});

  @override
  State<StolenVehicleDetectedPage> createState() => _StolenVehicleDetectedPageState();
}

class _StolenVehicleDetectedPageState extends State<StolenVehicleDetectedPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitializing = true;
  int _currentCameraIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final TextRecognizer _textRecognizer;

  // Animation controllers
  late AnimationController _scanAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  // PUCC Workflow state
  bool _isPUCCWorkflowActive = false;
  int _puccStep = 0;
  bool _isStationaryDetected = false;
  Timer? _stationaryTimer;
  Timer? _captureTimer;
  int _countdownSeconds = 5;

  // Detected numbers and plate boxes
  String? _detectedNumber1;
  String? _detectedNumber2;
  String? _detectedNumberVideo;
  String? _videoPath;
  List<Rect> _currentPlateBoxes = [];
  String? _currentPlateText;

  // Stationary detection
  List<double> _accelerometerHistory = [];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    // Initialize animations
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initEverything();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _audioPlayer.dispose();
    _textRecognizer.close();
    _stationaryTimer?.cancel();
    _captureTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _scanAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initEverything() async {
    await _initCamera(index: 0);
    if (!mounted) return;
    Provider.of<VehicleMatchProvider>(context, listen: false).init();
    _startStationaryDetection();
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
        ResolutionPreset.high,
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

  // ============ STATIONARY DETECTION ============
  void _startStationaryDetection() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _accelerometerHistory.add(magnitude);

      if (_accelerometerHistory.length > 50) {
        _accelerometerHistory.removeAt(0);
      }

      if (_accelerometerHistory.length == 50) {
        final mean = _accelerometerHistory.reduce((a, b) => a + b) / 50;
        final variance = _accelerometerHistory
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) / 50;

        if (variance < 0.05 && !_isStationaryDetected && !_isPUCCWorkflowActive) {
          _onDeviceStationary();
        } else if (variance >= 0.05 && _isStationaryDetected) {
          _resetStationaryDetection();
        }
      }
    });
  }

  void _onDeviceStationary() {
    if (_isStationaryDetected) return;

    setState(() {
      _isStationaryDetected = true;
      _countdownSeconds = 5;
    });

    // Start countdown timer
    _stationaryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _countdownSeconds--);

      if (_countdownSeconds <= 0) {
        timer.cancel();
        if (_isStationaryDetected && !_isPUCCWorkflowActive) {
          _startPUCCWorkflow();
        }
      }
    });
  }

  void _resetStationaryDetection() {
    setState(() {
      _isStationaryDetected = false;
      _countdownSeconds = 5;
    });
    _stationaryTimer?.cancel();
  }

  // ============ PUCC WORKFLOW ============
  Future<void> _startPUCCWorkflow() async {
    if (_isPUCCWorkflowActive) return;

    setState(() {
      _isPUCCWorkflowActive = true;
      _puccStep = 0;
      _detectedNumber1 = null;
      _detectedNumber2 = null;
      _detectedNumberVideo = null;
      _currentPlateBoxes = [];
      _currentPlateText = null;
    });

    debugPrint("🚀 Starting PUCC Workflow");

    await _playBeep();
    await Future.delayed(const Duration(milliseconds: 400));
    await _capturePhoto1();

    await Future.delayed(const Duration(seconds: 5));

    await _playBeep();
    await Future.delayed(const Duration(milliseconds: 400));
    await _capturePhoto2();

    await Future.delayed(const Duration(seconds: 5));

    await _playBeep();
    await Future.delayed(const Duration(milliseconds: 400));
    await _captureVideo();

    _showPUCCResults();
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.play(AssetSource("vehicleTone.mp3"));
    } catch (e) {
      debugPrint("Beep error: $e");
    }
  }

  // ============ CAPTURE METHODS ============
  Future<void> _capturePhoto1() async {
    setState(() => _puccStep = 1);
    debugPrint("📸 Capturing Photo 1...");

    try {
      bool withinGeofence = true;
      if (!withinGeofence) {
        _showValidationError("GPS out of bounds - must be at testing site");
        return;
      }

      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      final antiSpoofResults = await AntiSpoofEngine.runAntiSpoofChecks(bytes);
      debugPrint("🔍 Anti-spoof results: $antiSpoofResults");

      if (antiSpoofResults['is_spoofed'] == true &&
          (antiSpoofResults['printed_texture'] == true ||
              antiSpoofResults['pixel_grid'] == true)) {
        _showValidationError("⚠️ Spoof detected — please capture real vehicle number plate.");
        await ComplianceLogger.logValidationFailure(
          reason: "Anti-spoof failed",
          operatorId: "OPERATOR_001",
        );
        return;
      }

      final surroundingsResults = await SurroundingsDetector.verifySurroundings(bytes);
      if (!surroundingsResults['context_valid']) {
        _showValidationError("Invalid surroundings — vehicle base not detected.");
        return;
      }

      final recognized = await _runOcrOnBytes(bytes);
      final plateInfo = _findPlateFromRecognized(recognized);
      _detectedNumber1 = plateInfo?.text;

      // Update UI with detected plate
      if (plateInfo != null && plateInfo.box != null) {
        setState(() {
          _currentPlateBoxes = [plateInfo.box!];
          _currentPlateText = plateInfo.text;
        });
      }

      final gpsMetadata = await PUCCValidator.getGPSMetadata();

      await ComplianceLogger.logPUCCSession(
        operatorId: "OPERATOR_001",
        vehicleNumber: _detectedNumber1 ?? "Unknown",
        captureResults: [_detectedNumber1 ?? "None"],
        gpsMetadata: gpsMetadata,
        antiSpoofResults: antiSpoofResults,
        surroundingsResults: surroundingsResults,
        finalStatus: "in_progress",
      );

      debugPrint("✅ Photo 1 captured. Detected: ${_detectedNumber1 ?? 'None'}");
    } catch (e) {
      debugPrint("❌ Photo 1 error: $e");
    }
  }

  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text("Validation Failed"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPUCCWorkflow();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto2() async {
    setState(() {
      _puccStep = 2;
      _currentPlateBoxes = [];
      _currentPlateText = null;
    });
    debugPrint("📸 Capturing Photo 2...");

    try {
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      final recognized = await _runOcrOnBytes(bytes);
      final plateInfo = _findPlateFromRecognized(recognized);
      _detectedNumber2 = plateInfo?.text;

      if (plateInfo != null && plateInfo.box != null) {
        setState(() {
          _currentPlateBoxes = [plateInfo.box!];
          _currentPlateText = plateInfo.text;
        });
      }

      debugPrint("✅ Photo 2 captured. Detected: ${_detectedNumber2 ?? 'None'}");
    } catch (e) {
      debugPrint("❌ Photo 2 error: $e");
    }
  }

  Future<void> _captureVideo() async {
    setState(() {
      _puccStep = 3;
      _currentPlateBoxes = [];
      _currentPlateText = null;
    });
    debugPrint("🎥 Capturing Video...");

    try {
      await _cameraController!.startVideoRecording();
      await Future.delayed(const Duration(seconds: 3));
      final recordedFile = await _cameraController!.stopVideoRecording();

      _videoPath = recordedFile.path;
      debugPrint("✅ Video captured at: $_videoPath");

      _detectedNumberVideo = "Video captured - frame extraction needed";
    } catch (e) {
      debugPrint("❌ Video error: $e");
    }
  }

  // ============ RESULTS DIALOG ============
  void _showPUCCResults() {
    final finalNumber = _detectedNumber1 ?? _detectedNumber2 ?? _detectedNumberVideo ?? "Not detected";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('PUCC Workflow'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultCard('Photo 1', _detectedNumber1 ?? 'Not detected', Icons.camera_alt),
              const SizedBox(height: 12),
              _buildResultCard('Photo 2', _detectedNumber2 ?? 'Not detected', Icons.camera),
              const SizedBox(height: 12),
              _buildResultCard('Video', _detectedNumberVideo ?? 'Not detected', Icons.videocam),
              const Divider(height: 32, thickness: 2),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Final Registration Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      finalNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              if (_videoPath != null) ...[
                const SizedBox(height: 20),
                const Text(
                  "Captured Video Preview:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoPlayerWidget(videoPath: _videoPath!),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPUCCWorkflow();
            },
            child: const Text('Dismiss', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _resetPUCCWorkflow();
            },
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save Certificate', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String label, String value, IconData icon) {
    final isDetected = value != 'Not detected';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDetected ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDetected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDetected ? Colors.green : Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isDetected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resetPUCCWorkflow() {
    setState(() {
      _isPUCCWorkflowActive = false;
      _puccStep = 0;
      _isStationaryDetected = false;
      _detectedNumber1 = null;
      _detectedNumber2 = null;
      _detectedNumberVideo = null;
      _currentPlateBoxes = [];
      _currentPlateText = null;
      _countdownSeconds = 5;
    });
    _accelerometerHistory.clear();
  }

  // ============ OCR LOGIC ============
  Future<RecognizedText> _runOcrOnBytes(Uint8List bytes) async {
    try {
      final tmp = await _writeTempImage(bytes);
      final inputImage = InputImage.fromFilePath(tmp.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      if (recognized.text.trim().isNotEmpty) {
        return recognized;
      }

      final enhanced = await _enhanceForOcr(bytes);
      if (enhanced != null) {
        final tmp2 = await _writeTempImage(enhanced);
        final inputImage2 = InputImage.fromFilePath(tmp2.path);
        final recognized2 = await _textRecognizer.processImage(inputImage2);
        if (recognized2.text.trim().isNotEmpty) {
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

      img.Image gray = img.grayscale(decoded);
      gray = img.adjustColor(gray, contrast: 1.2, brightness: 0.05);

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
      return null;
    }
  }

  Future<io.File> _writeTempImage(Uint8List bytes) async {
    final dir = await io.Directory.systemTemp.createTemp();
    final file = io.File(p.join(dir.path, 'temp_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(bytes);
    return file;
  }

  _PlateInfo? _findPlateFromRecognized(RecognizedText recognized) {
    final blocks = recognized.blocks;
    for (var block in blocks) {
      final bText = block.text ?? "";
      final normalized = _normalizeOcrText(bText);
      final plate = _matchPlateRegex(normalized);
      if (plate != null) {
        return _PlateInfo(text: plate, box: block.boundingBox);
      }
    }
    return null;
  }

  String _normalizeOcrText(String text) {
    String s = text.toUpperCase();
    s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    s = s
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('B', '8')
        .replaceAll('S', '5');
    return s;
  }

  String? _matchPlateRegex(String normalized) {
    final reg = RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{3,4}', caseSensitive: false);
    final m = reg.firstMatch(normalized);
    return m?.group(0);
  }

  // ============ UI BUILD ============
  @override
  Widget build(BuildContext context) {
    if (_isCameraInitializing) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  'Initializing Camera...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      )
          : Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // Scanning Overlay
          if (_isPUCCWorkflowActive || _isStationaryDetected)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ScanningOverlayPainter(
                      animation: _scanAnimation.value,
                      isActive: _isPUCCWorkflowActive,
                    ),
                  );
                },
              ),
            ),

          // Plate Detection Boxes
          if (_currentPlateBoxes.isNotEmpty && _cameraController != null)
            Positioned.fill(
              child: CustomPaint(
                painter: PlatePainter(
                  _currentPlateBoxes,
                  Size(
                    _cameraController!.value.previewSize?.height ?? 1,
                    _cameraController!.value.previewSize?.width ?? 1,
                  ),
                  _currentCameraIndex == 1,
                  label: _currentPlateText,
                ),
              ),
            ),

          // Top Status Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PUCC Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isPUCCWorkflowActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                          SizedBox(width: 6),
                          Text(
                            'RECORDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Stationary Countdown
          if (_isStationaryDetected && !_isPUCCWorkflowActive)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Device Stationary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Starting in $_countdownSeconds seconds...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Workflow Status
          if (_isPUCCWorkflowActive)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getPUCCStepMessage(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStepIndicators(),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Control Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.only(bottom: 40, top: 30, left: 20, right: 20),
              child: _buildControlButtons(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepDot(1, 'Photo 1'),
        _buildStepLine(),
        _buildStepDot(2, 'Photo 2'),
        _buildStepLine(),
        _buildStepDot(3, 'Video'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _puccStep == step;
    final isCompleted = _puccStep > step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green
                : isActive
                ? Colors.blue
                : Colors.grey.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildControlButtons() {
    if (_isPUCCWorkflowActive) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () {
            _resetPUCCWorkflow();
          },
          icon: const Icon(Icons.stop, size: 28, color: Colors.white),
          label: const Text(
            'Stop Workflow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
        ),
      );
    }

    return Center(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () async {
            await _startPUCCWorkflow();
          },
          icon: const Icon(Icons.play_circle_fill, size: 32, color: Colors.white),
          label: const Text(
            'Start PUCC Scan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  String _getPUCCStepMessage() {
    switch (_puccStep) {
      case 1:
        return '📸 Capturing Photo 1...';
      case 2:
        return '📸 Capturing Photo 2...';
      case 3:
        return '🎥 Recording Video...';
      default:
        return 'Processing...';
    }
  }
}

class _PlateInfo {
  final String text;
  final Rect? box;
  _PlateInfo({required this.text, this.box});
}

// ============ CUSTOM PAINTERS ============

class ScanningOverlayPainter extends CustomPainter {
  final double animation;
  final bool isActive;

  ScanningOverlayPainter({required this.animation, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    // Semi-transparent overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.3);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Scanning frame
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final frameWidth = size.width * 0.85;
    final frameHeight = size.height * 0.45;

    final scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: frameWidth,
      height: frameHeight,
    );

    // Clear center area
    final clearPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..blendMode = BlendMode.dstOut;
    canvas.drawRect(scanRect, clearPaint);

    // Animated scanning line
    final scanLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.greenAccent.withOpacity(0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, frameWidth, 3))
      ..strokeWidth = 3;

    final scanY = scanRect.top + (scanRect.height * animation);
    canvas.drawLine(
      Offset(scanRect.left, scanY),
      Offset(scanRect.right, scanY),
      scanLinePaint,
    );

    // Frame border with glow
    final framePaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final glowPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(12)),
      glowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(12)),
      framePaint,
    );

    // Corner indicators
    _drawCornerIndicators(canvas, scanRect);

    // Instruction text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'ALIGN VEHICLE NUMBER PLATE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          shadows: [
            Shadow(
              color: Colors.black,
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        scanRect.top - 40,
      ),
    );
  }

  void _drawCornerIndicators(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    final corners = [
      [Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top)],
      [Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength)],
      [Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top)],
      [Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength)],
      [Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom)],
      [Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength)],
      [Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom)],
      [Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength)],
    ];

    for (var corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScanningOverlayPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.isActive != isActive;
  }
}

class PlatePainter extends CustomPainter {
  final List<Rect> plates;
  final Size imageSize;
  final bool isFrontCamera;
  final String? label;

  PlatePainter(this.plates, this.imageSize, this.isFrontCamera, {this.label});

  @override
  void paint(Canvas canvas, Size size) {
    if (plates.isEmpty) return;

    for (final box in plates) {
      double scaleX = size.width / imageSize.height;
      double scaleY = size.height / imageSize.width;

      final rect = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );

      final drawRect = isFrontCamera
          ? Rect.fromLTRB(
        size.width - rect.right,
        rect.top,
        size.width - rect.left,
        rect.bottom,
      )
          : rect;

      // Glow effect
      final glowPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(drawRect, const Radius.circular(8)),
        glowPaint,
      );

      // Fill
      final fillPaint = Paint()
        ..color = Colors.blue.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(drawRect, const Radius.circular(8)),
        fillPaint,
      );

      // Border
      final borderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(drawRect, const Radius.circular(8)),
        borderPaint,
      );

      // Corner brackets
      _drawCornerBrackets(canvas, drawRect);

      // Label
      if (label != null && label!.isNotEmpty) {
        _drawLabel(canvas, drawRect, label!);
      }
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const cornerSize = 25.0;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerSize, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerSize), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerSize, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerSize), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerSize, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerSize), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerSize, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerSize), paint);
  }

  void _drawLabel(Canvas canvas, Rect rect, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelY = rect.top - textPainter.height - 16;
    final labelX = rect.left + (rect.width - textPainter.width) / 2;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - 12,
        labelY - 6,
        textPainter.width + 24,
        textPainter.height + 12,
      ),
      const Radius.circular(8),
    );

    // Background with gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
      ).createShader(bgRect.outerRect);
    canvas.drawRRect(bgRect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(bgRect, borderPaint);

    textPainter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant PlatePainter oldDelegate) {
    return oldDelegate.plates != plates || oldDelegate.label != label;
  }
}

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