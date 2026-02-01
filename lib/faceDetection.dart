// OPTIMIZED Fast Face Liveness Detection Code with Image Capture
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:id_verification_app/upload_service.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade400, Colors.blue.shade800]
          ),
        ),
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face_retouching_natural, size: 100, color: Colors.white),
                SizedBox(height: 30),
                Text(
                    'Fast Face Liveness Detection',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                SizedBox(height: 20),
                Text(
                    'Quick identity verification with face detection',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center
                ),
                SizedBox(height: 50),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FaceDetectionScreen(cameras: cameras)
                        )
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade800,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                      'Start Quick Scan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ]
          ),
        ),
      ),
    );
  }
}

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  int _currentCameraIndex = 0;

  // Simplified liveness detection states
  bool _faceDetected = false;
  bool _faceFittedInFrame = false;
  int _blinkCount = 0;
  bool _livenessVerified = false;
  String _instructionText = "Position your face in the frame";

  // Simplified face detection variables
  List<Face> _faces = [];
  bool _previousEyesOpen = true;

  // Optimized processing control
  bool _isProcessing = false;
  int _frameSkipCounter = 0;
  static const int FRAME_SKIP = 3; // Process every 3rd frame for speed

  // ONLY NEW ADDITION: Image capture variables
  XFile? _capturedImage;
  bool _isCapturingImage = false;

  @override
  void initState() {
    super.initState();
    _currentCameraIndex = _getFrontCameraIndex();
    _initializeFaceDetector();
    _initializeCamera();
  }

  // OPTIMIZED: Simplified face detector with fast mode
  void _initializeFaceDetector() {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableClassification: true, // Only for eye detection
          enableLandmarks: false,     // Disabled for speed
          enableTracking: false,      // Disabled for speed
          minFaceSize: 0.2,          // Larger minimum for faster detection
          performanceMode: FaceDetectorMode.fast, // FAST mode
        ),
      );
      debugPrint("✅ Fast face detector initialized");
    } catch (e) {
      debugPrint('❌ Face detector init error: $e');
    }
  }

  int _getFrontCameraIndex() {
    for (int i = 0; i < widget.cameras.length; i++) {
      if (widget.cameras[i].lensDirection == CameraLensDirection.front) return i;
    }
    return 0;
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _instructionText = "Camera permission required";
      });
      return;
    }

    // OPTIMIZED: Use only the best format for speed
    try {
      _cameraController = CameraController(
          widget.cameras[_currentCameraIndex],
          ResolutionPreset.low, // Lower resolution for speed
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        // OPTIMIZED: Start immediately without delays
        _startImageStream();
      }
    } catch (e) {
      debugPrint('❌ Camera init failed: $e');
      if (mounted) {
        setState(() => _instructionText = "Failed to initialize camera");
      }
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((CameraImage image) {
      // OPTIMIZED: Skip frames for better performance
      _frameSkipCounter++;
      if (_frameSkipCounter < FRAME_SKIP) return;
      _frameSkipCounter = 0;

      if (_isProcessing || _livenessVerified || !mounted) return;

      _isProcessing = true;

      // OPTIMIZED: No Future.delayed, process immediately
      _detectFaces(image).then((_) {
        _isProcessing = false;
      }).catchError((e) {
        debugPrint('Detection error: $e');
        _isProcessing = false;
      });
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      final detectedFaces = await _faceDetector!.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faces = detectedFaces;
        });
        _processFaceDetection(detectedFaces);
      }
    } catch (e) {
      debugPrint('❌ Face detection error: $e');
    }
  }

  // OPTIMIZED: Much more lenient face fitting conditions
  void _processFaceDetection(List<Face> detectedFaces) {
    if (detectedFaces.isEmpty) {
      setState(() {
        _faceDetected = false;
        _faceFittedInFrame = false;
        _instructionText = "Position your face in the frame";
      });
      return;
    }

    final face = detectedFaces.first;
    setState(() {
      _faceDetected = true;
    });

    final faceRect = face.boundingBox;

    if (_isFaceInFrame(faceRect)) {
      if (!_faceFittedInFrame) {
        setState(() {
          _faceFittedInFrame = true;
          _instructionText = "Great! Now blink 3 times"; // Updated instruction
        });
      }

      if (_faceFittedInFrame && !_livenessVerified) {
        // Update instruction based on blink progress
        if (_blinkCount == 0) {
          setState(() {
            _instructionText = "Blink now (0/3)";
          });
        } else if (_blinkCount < 3) {
          setState(() {
            _instructionText = "Keep blinking ($_blinkCount/3)";
          });
        }

        _detectBlinking(face);
      }
    } else {
      setState(() {
        _faceFittedInFrame = false;
        _instructionText = "Move face closer to center";
      });
    }
  }

  // OPTIMIZED: Much more lenient face frame check
  bool _isFaceInFrame(Rect faceRect) {
    final w = faceRect.width;
    final h = faceRect.height;
    final cx = faceRect.center.dx;
    final cy = faceRect.center.dy;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // OPTIMIZED: Much more lenient conditions
    bool inFrame = w > 30 && h > 30 &&  // Smaller minimum size
        cx > 0 && cx < screenWidth &&     // Just needs to be on screen
        cy > 50 && cy < (screenHeight - 80); // Generous margins

    return inFrame;
  }

  // OPTIMIZED: Simplified blink detection for 1 blink only
  void _detectBlinking(Face face) {
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;

    if (leftProb == null || rightProb == null) return;

    const double openThreshold = 0.4; // Slightly higher threshold for reliability
    final eyesOpen = (leftProb > openThreshold) && (rightProb > openThreshold);

    // FIXED: Proper blink detection with increment
    if (_previousEyesOpen && !eyesOpen) {
      // Eyes closed - no action needed, just waiting
      debugPrint("👁️ Eyes closed detected");
    } else if (!_previousEyesOpen && eyesOpen) {
      // Eyes opened after being closed - BLINK DETECTED!
      setState(() {
        _blinkCount++; // INCREMENT by 1, don't set to 3
      });

      debugPrint("✅ BLINK detected! Count: $_blinkCount");

      // Complete verification after 3 blinks
      if (mounted && _blinkCount >= 3) {
        _completeVerification();
      }
    }

    _previousEyesOpen = eyesOpen;
  }

  // ONLY NEW ADDITION: Capture image method
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturingImage) {
      return;
    }

    try {
      setState(() {
        _isCapturingImage = true;
      });

      // Stop image stream temporarily for capture
      //await _cameraController!.stopImageStream();

      // Capture the image
      final XFile image = await _cameraController!.takePicture();

      setState(() {
        _capturedImage = image;
        _isCapturingImage = false;
      });

      debugPrint("✅ Image captured successfully: ${image.path}");

    } catch (e) {
      debugPrint('❌ Error capturing image: $e');
      setState(() {
        _isCapturingImage = false;
      });
    }
  }

  void _completeVerification() async {
    setState(() {
      _livenessVerified = true;
      _instructionText = "Verification Complete!";
    });

    try {
      _cameraController?.stopImageStream();
    } catch (_) {}

    // Capture image
    await _captureImage();

    if (_capturedImage != null) {
      // ✅ Upload captured image
      final success = await UploadService.uploadImage(
        File(_capturedImage!.path),
        "user123", // you can replace with actual logged in userId
      );

      if (success) {
        print("✅ Image uploaded successfully");
      } else {
        print("❌ Image upload failed");
      }
    }

    Timer(Duration(milliseconds: 500), () => _showSuccessDialog());
  }


  void _showSuccessDialog() {
    debugPrint("🔵 Showing success dialog. _capturedImage is ${_capturedImage != null ? 'NOT NULL' : 'NULL'}");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text('Success!')
            ]
        ),
        content: Text('Face liveness verified quickly!'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // ONLY NEW ADDITION: Show captured image screen
                if (_capturedImage != null) {
                  debugPrint("✅ Navigating to captured image screen: ${_capturedImage!.path}");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CapturedImageScreen(
                        imagePath: _capturedImage!.path,
                      ),
                    ),
                  );
                } else {
                  debugPrint("❌ No captured image found, going back to home screen");
                  Navigator.of(context).pop();
                }
              },
              child: Text('OK')
          )
        ],
      ),
    );
  }

  // OPTIMIZED: Simplified conversion for speed
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = widget.cameras[_currentCameraIndex];

      // OPTIMIZED: Simple rotation handling
      InputImageRotation rotation = InputImageRotation.rotation0deg;
      if (camera.sensorOrientation == 90) rotation = InputImageRotation.rotation90deg;
      else if (camera.sensorOrientation == 180) rotation = InputImageRotation.rotation180deg;
      else if (camera.sensorOrientation == 270) rotation = InputImageRotation.rotation270deg;

      InputImageFormat? format;
      Uint8List bytes;

      if (Platform.isAndroid) {
        format = InputImageFormat.nv21;
        // OPTIMIZED: Direct bytes copy for NV21
        if (image.planes.length >= 2) {
          final yPlane = image.planes[0];
          final uvPlane = image.planes[1];
          bytes = Uint8List(yPlane.bytes.length + uvPlane.bytes.length);
          bytes.setRange(0, yPlane.bytes.length, yPlane.bytes);
          bytes.setRange(yPlane.bytes.length, bytes.length, uvPlane.bytes);
        } else {
          return null;
        }
      } else {
        format = InputImageFormat.bgra8888;
        bytes = Uint8List.fromList(image.planes[0].bytes);
      }

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);

    } catch (e) {
      debugPrint('❌ Conversion error: $e');
      return null;
    }
  }

  void _switchCamera() {
    if (widget.cameras.length > 1) {
      _currentCameraIndex = _currentCameraIndex == 0 ? 1 : 0;

      try {
        _cameraController?.dispose();
      } catch (_) {}

      _initializeCamera();

      setState(() {
        _faceDetected = false;
        _faceFittedInFrame = false;
        _blinkCount = 0;
        _livenessVerified = false;
        _instructionText = "Position your face in the frame";
        _previousEyesOpen = true;
        // ONLY NEW ADDITION: Reset captured image
        _capturedImage = null;
      });
    }
  }

  @override
  void dispose() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: Text('Fast Face Detection'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
                icon: Icon(Icons.switch_camera),
                onPressed: _switchCamera
            ),
          ]
      ),
      body: _isCameraInitialized
          ? Stack(
          children: [
            CameraPreview(_cameraController!),

            // OPTIMIZED: Simplified face overlay
            CustomPaint(
              painter: SimpleFaceDetectionPainter(
                faces: _faces,
                imageSize: Size(
                    _cameraController!.value.previewSize?.width ?? 1,
                    _cameraController!.value.previewSize?.height ?? 1
                ),
              ),
              size: Size.infinite,
            ),

            // OPTIMIZED: Larger, more generous frame guide
            Center(
              child: Container(
                width: 280,
                height: 350,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _faceFittedInFrame ? Colors.green : Colors.white,
                      width: 3
                  ),
                  borderRadius: BorderRadius.circular(140),
                ),
                child: _faceFittedInFrame
                    ? Container(
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(140)
                    )
                )
                    : null,
              ),
            ),

            Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: _buildInstructionBox()
            ),

            Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: _buildStatusRow()
            ),

            // ONLY NEW ADDITION: Show capturing indicator
            if (_isCapturingImage)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'Capturing Image...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ]
      )
          : Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                    'Initializing Fast Camera...',
                    style: TextStyle(color: Colors.white, fontSize: 16)
                )
              ]
          )
      ),
    );
  }

  Widget _buildInstructionBox() => Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10)
      ),
      child: Text(
          _instructionText,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold
          )
      )
  );

  Widget _buildStatusRow() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatusIndicator(label: "Face", isCompleted: _faceDetected),
        _StatusIndicator(label: "Fitted", isCompleted: _faceFittedInFrame),
        _StatusIndicator(label: "Blink: $_blinkCount/3", isCompleted: _blinkCount >= 3),
      ]
  );
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool isCompleted;
  const _StatusIndicator({required this.label, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: isCompleted ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(20)
      ),
      child: Text(
          label,
          style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold
          )
      ),
    );
  }
}

// OPTIMIZED: Simplified painter for better performance
class SimpleFaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  SimpleFaceDetectionPainter({
    required this.faces,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final Paint facePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double scaleX = imageSize.width > 0 ? size.width / imageSize.width : 1.0;
    final double scaleY = imageSize.height > 0 ? size.height / imageSize.height : 1.0;

    // OPTIMIZED: Only draw bounding box, no landmarks
    for (final face in faces) {
      final Rect rect = Rect.fromLTRB(
          face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY
      );
      canvas.drawRect(rect, facePaint);
    }
  }

  @override
  bool shouldRepaint(SimpleFaceDetectionPainter oldDelegate) =>
      oldDelegate.faces != faces;
}

// ONLY NEW ADDITION: Captured Image Display Screen
class CapturedImageScreen extends StatelessWidget {
  final String imagePath;

  const CapturedImageScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Captured Image'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();// Go back to home screen
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.6,
                ),
              ),
            ),
            SizedBox(height: 30),
            Text(
              'Face Verification Successful!',
              style: TextStyle(
                color: Colors.green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Image captured and stored successfully',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();// Go back to home screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}