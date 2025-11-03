// import 'dart:io';
// import 'dart:ui' as ui;
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:printing/printing.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
// import 'package:video_player/video_player.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';
//
//
// import 'dart:io';
// import 'dart:ui' as ui;
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:printing/printing.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
// import 'package:video_player/video_player.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';
//
// // Custom TextInputFormatter for vehicle number auto-spacing
// class VehicleNumberFormatter extends TextInputFormatter {
//   @override
//   TextEditingValue formatEditUpdate(
//       TextEditingValue oldValue,
//       TextEditingValue newValue,
//       ) {
//     final text = newValue.text.toUpperCase().replaceAll(' ', '');
//     String formatted = '';
//
//     for (int i = 0; i < text.length; i++) {
//       // Add space after first 2 characters (state code)
//       if (i == 2) {
//         formatted += ' ';
//       }
//       // Add space after district code (next 1-2 digits)
//       else if (i >= 3 && i <= 4 && _isDigit(text[i]) && i + 1 < text.length && _isLetter(text[i + 1])) {
//         formatted += text[i] + ' ';
//         continue;
//       }
//       // Add space after series letters (before final 4 digits)
//       else if (i >= 4 && _isLetter(text[i]) && i + 1 < text.length && _isDigit(text[i + 1])) {
//         formatted += text[i] + ' ';
//         continue;
//       }
//
//       formatted += text[i];
//     }
//
//     return TextEditingValue(
//       text: formatted,
//       selection: TextSelection.collapsed(offset: formatted.length),
//     );
//   }
//
//   bool _isDigit(String char) {
//     return RegExp(r'\d').hasMatch(char);
//   }
//
//   bool _isLetter(String char) {
//     return RegExp(r'[A-Z]').hasMatch(char);
//   }
// }
//
// class videoToText extends StatefulWidget {
//   @override
//   _videoToTextState createState() => _videoToTextState();
// }
//
// class _videoToTextState extends State<videoToText> {
//   String? _extractedText;
//   String _enteredNumber = '';
//   String? _result;
//   bool _isLoading = false;
//   File? _selectedImage;
//   File? _selectedVideo;
//   VideoPlayerController? _videoController;
//   List<File> _extractedFrames = [];
//   final TextEditingController _numberController = TextEditingController();
//
//   @override
//   void dispose() {
//     _numberController.dispose();
//     _videoController?.dispose();
//     super.dispose();
//   }
//
//   // Step 1: Extract Frames from Video (Following your reference pattern)
//   Future<void> extractFrames(String videoPath) async {
//     try {
//       final tempDir = await getTemporaryDirectory();
//       final framesDir = Directory('${tempDir.path}/frames');
//
//       // Clear previous frames
//       if (await framesDir.exists()) {
//         await framesDir.delete(recursive: true);
//       }
//       await framesDir.create(recursive: true);
//
//       // Get video duration to determine how many frames to extract
//       if (_videoController != null && _videoController!.value.isInitialized) {
//         final duration = _videoController!.value.duration;
//         final totalSeconds = duration.inSeconds;
//
//         print('Video duration: ${totalSeconds} seconds');
//
//         // Extract frames at 1 frame per second (following reference: fps=1)
//         List<File> extractedFrameFiles = [];
//
//         for (int i = 0; i < totalSeconds; i++) {
//           try {
//             final thumbnailPath = await VideoThumbnail.thumbnailFile(
//               video: videoPath,
//               thumbnailPath: '${framesDir.path}/frame_${i.toString().padLeft(4, '0')}.png',
//               imageFormat: ImageFormat.PNG,
//               timeMs: i * 1000, // Extract at each second
//               quality: 100,
//             );
//
//             if (thumbnailPath != null && await File(thumbnailPath).exists()) {
//               extractedFrameFiles.add(File(thumbnailPath));
//               print('Extracted frame: frame_${i.toString().padLeft(4, '0')}.png');
//             }
//           } catch (e) {
//             print('Error extracting frame at ${i}s: $e');
//           }
//         }
//
//         setState(() {
//           _extractedFrames = extractedFrameFiles;
//         });
//
//         print('Total frames extracted: ${extractedFrameFiles.length}');
//
//         // Step 2: Process each frame with OCR
//         await processExtractedFrames(extractedFrameFiles);
//       }
//     } catch (e) {
//       print('Error extracting frames: $e');
//       _showSnackBar('Error extracting frames: $e', Colors.red);
//     }
//   }
//
//   // Step 2: Apply OCR to Extract Text from each frame (Following your reference)
//   Future<String> extractTextFromImage(String imagePath) async {
//     try {
//       final inputImage = InputImage.fromFilePath(imagePath);
//       final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
//       final recognizedText = await textRecognizer.processImage(inputImage);
//
//       String extractedText = '';
//       for (TextBlock block in recognizedText.blocks) {
//         for (TextLine line in block.lines) {
//           extractedText += line.text + ' ';
//         }
//       }
//
//       await textRecognizer.close();
//       return extractedText.trim();
//     } catch (e) {
//       print('Error extracting text from $imagePath: $e');
//       return '';
//     }
//   }
//
//   // Step 3: Process all extracted frames
//   Future<void> processExtractedFrames(List<File> frames) async {
//     List<String> allExtractedTexts = [];
//
//     print('Processing ${frames.length} frames...');
//
//     for (int i = 0; i < frames.length; i++) {
//       File frame = frames[i];
//       try {
//         // Extract text from each frame
//         String frameText = await extractTextFromImage(frame.path) ?? '';
//
//         if (frameText.isNotEmpty) {
//           String cleanedText = _cleanOCRText(frameText);
//           if (cleanedText.isNotEmpty) {
//             allExtractedTexts.add(cleanedText);
//             print('Frame ${i + 1} text: $cleanedText');
//           }
//         }
//       } catch (e) {
//         print('Error processing frame ${frame.path}: $e');
//       }
//     }
//
//     // Step 4: Combine results from all frames
//     String combinedText = combineResults(allExtractedTexts);
//
//     setState(() {
//       _extractedText = combinedText;
//     });
//
//     print('Final combined text: $combinedText');
//   }
//
//   // Step 4: Filter Numbers and Combine Results (Following your reference)
//   String extractNumbers(String text) {
//     final regex = RegExp(r'\d+');
//     return regex.allMatches(text).map((match) => match.group(0)).join(', ');
//   }
//
//   // Enhanced combine results method
//   String combineResults(List<String> texts) {
//     if (texts.isEmpty) return '';
//
//     // Strategy 1: Find most frequent vehicle number patterns
//     Map<String, int> vehicleNumberFreq = {};
//
//     for (String text in texts) {
//       List<String> vehicleNumbers = _extractVehicleNumbers(text);
//       for (String number in vehicleNumbers) {
//         vehicleNumberFreq[number] = (vehicleNumberFreq[number] ?? 0) + 1;
//       }
//     }
//
//     // If we found consistent vehicle numbers, return the most frequent one
//     if (vehicleNumberFreq.isNotEmpty) {
//       var mostFrequentEntry = vehicleNumberFreq.entries
//           .reduce((a, b) => a.value > b.value ? a : b);
//
//       print('Most frequent vehicle number: ${mostFrequentEntry.key} (appeared ${mostFrequentEntry.value} times)');
//       return mostFrequentEntry.key;
//     }
//
//     // Strategy 2: Extract just numbers if no vehicle patterns found
//     Map<String, int> numberFreq = {};
//
//     for (String text in texts) {
//       String numbers = extractNumbers(text);
//       if (numbers.isNotEmpty) {
//         List<String> numberList = numbers.split(', ');
//         for (String num in numberList) {
//           if (num.length >= 2) { // Only consider numbers with 2+ digits
//             numberFreq[num] = (numberFreq[num] ?? 0) + 1;
//           }
//         }
//       }
//     }
//
//     if (numberFreq.isNotEmpty) {
//       var mostFrequentNumber = numberFreq.entries
//           .reduce((a, b) => a.value > b.value ? a : b);
//
//       print('Most frequent number: ${mostFrequentNumber.key} (appeared ${mostFrequentNumber.value} times)');
//       return mostFrequentNumber.key;
//     }
//
//     // Strategy 3: Return longest text if no patterns found
//     texts.sort((a, b) => b.length.compareTo(a.length));
//     return texts.isNotEmpty ? texts.first : '';
//   }
//
//   // Video selection methods
//   Future<void> _pickVideoFile() async {
//     setState(() {
//       _isLoading = true;
//       _result = null;
//       _extractedText = null;
//       _selectedImage = null;
//       _selectedVideo = null;
//       _extractedFrames.clear();
//     });
//
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['mp4', 'mov', 'avi', 'mkv'],
//       );
//
//       if (result != null && result.files.isNotEmpty) {
//         final file = File(result.files.single.path!);
//         setState(() {
//           _selectedVideo = file;
//         });
//
//         await _initializeVideoPlayer(file);
//         // Start frame extraction process
//         await extractFrames(file.path);
//       }
//     } catch (e) {
//       _showSnackBar('Error picking video: $e', Colors.red);
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   Future<void> _recordVideo() async {
//     setState(() {
//       _isLoading = true;
//       _result = null;
//       _extractedText = null;
//       _selectedImage = null;
//       _selectedVideo = null;
//       _extractedFrames.clear();
//     });
//
//     try {
//       final ImagePicker picker = ImagePicker();
//       final XFile? pickedFile = await picker.pickVideo(
//         source: ImageSource.camera,
//         maxDuration: Duration(seconds: 30),
//       );
//
//       if (pickedFile != null) {
//         final file = File(pickedFile.path);
//         setState(() {
//           _selectedVideo = file;
//         });
//
//         await _initializeVideoPlayer(file);
//         // Start frame extraction process
//         await extractFrames(file.path);
//       } else {
//         _showSnackBar('No video recorded', Colors.orange);
//       }
//     } catch (e) {
//       _showSnackBar('Error recording video: $e', Colors.red);
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   Future<void> _initializeVideoPlayer(File videoFile) async {
//     try {
//       _videoController?.dispose();
//       _videoController = VideoPlayerController.file(videoFile);
//       await _videoController!.initialize();
//       setState(() {});
//     } catch (e) {
//       print('Error initializing video player: $e');
//     }
//   }
//
//   // All your existing image processing methods remain the same
//   Future<void> _pickFile() async {
//     setState(() {
//       _isLoading = true;
//       _result = null;
//       _extractedText = null;
//       _selectedVideo = null;
//       _videoController?.dispose();
//       _videoController = null;
//     });
//
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
//       );
//
//       if (result != null && result.files.isNotEmpty) {
//         final file = File(result.files.single.path!);
//         final ext = p.extension(file.path).toLowerCase();
//
//         if (ext == '.pdf') {
//           try {
//             final pdfBytes = await file.readAsBytes();
//             final pages = Printing.raster(pdfBytes, pages: [0]);
//             final pageImage = await pages.first;
//             final image = await pageImage.toImage();
//             final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//             final imageBytes = byteData!.buffer.asUint8List();
//
//             final tempDir = await getTemporaryDirectory();
//             final imgPath = p.join(tempDir.path, 'page.png');
//             final imgFile = File(imgPath);
//             await imgFile.writeAsBytes(imageBytes);
//             await _performOCR(imgFile);
//             setState(() {
//               _selectedImage = imgFile;
//             });
//           } catch (e) {
//             _showSnackBar('Error processing PDF: $e', Colors.red);
//           }
//         } else {
//           await _performOCR(file);
//           setState(() {
//             _selectedImage = file;
//           });
//         }
//       }
//     } catch (e) {
//       _showSnackBar('Error picking file: $e', Colors.red);
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   Future<void> _pickImageFromCamera() async {
//     setState(() {
//       _isLoading = true;
//       _result = null;
//       _extractedText = null;
//       _selectedVideo = null;
//       _videoController?.dispose();
//       _videoController = null;
//     });
//
//     try {
//       final ImagePicker picker = ImagePicker();
//       final XFile? pickedFile = await picker.pickImage(
//         source: ImageSource.camera,
//         maxWidth: 1024,
//         maxHeight: 1024,
//         imageQuality: 85,
//       );
//
//       if (pickedFile != null) {
//         final file = File(pickedFile.path);
//         await _performOCR(file);
//         setState(() {
//           _selectedImage = file;
//         });
//       } else {
//         _showSnackBar('No image captured', Colors.orange);
//       }
//     } catch (e) {
//       _showSnackBar('Error capturing image: $e', Colors.red);
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   Future<void> _pickImageFromGallery() async {
//     setState(() {
//       _isLoading = true;
//       _result = null;
//       _extractedText = null;
//       _selectedVideo = null;
//       _videoController?.dispose();
//       _videoController = null;
//     });
//
//     try {
//       final ImagePicker picker = ImagePicker();
//       final XFile? pickedFile = await picker.pickImage(
//         source: ImageSource.gallery,
//         maxWidth: 1024,
//         maxHeight: 1024,
//         imageQuality: 85,
//       );
//
//       if (pickedFile != null) {
//         final file = File(pickedFile.path);
//         await _performOCR(file);
//         setState(() {
//           _selectedImage = file;
//         });
//       } else {
//         _showSnackBar('No image selected', Colors.orange);
//       }
//     } catch (e) {
//       _showSnackBar('Error selecting image: $e', Colors.red);
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   Future<void> _performOCR(File file) async {
//     try {
//       final inputImage = InputImage.fromFile(file);
//       final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
//       final result = await recognizer.processImage(inputImage);
//
//       String extractedText = result.text.isNotEmpty ? result.text : '';
//       String cleanedText = _cleanOCRText(extractedText);
//
//       setState(() {
//         _extractedText = cleanedText;
//       });
//
//       await recognizer.close();
//
//       print('Original Extracted Text: ${result.text}');
//       print('Cleaned Text: $cleanedText');
//
//     } catch (e) {
//       _showSnackBar('Error processing image: $e', Colors.red);
//       print('OCR Error: $e');
//     }
//   }
//
//   String _cleanOCRText(String text) {
//     if (text.isEmpty) return '';
//
//     Map<String, String> corrections = {
//       '@': 'A', '€': 'E', '£': 'E', '¢': 'C', '§': 'S',
//       'µ': 'U', '¤': 'O', '¥': 'Y', '©': 'C', '®': 'R', '&': '8',
//     };
//
//     String cleaned = text.toUpperCase();
//     for (String key in corrections.keys) {
//       cleaned = cleaned.replaceAll(key, corrections[key]!);
//     }
//
//     cleaned = cleaned
//         .replaceAll(RegExp(r'[^\w\s]'), ' ')
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .trim();
//
//     return cleaned;
//   }
//
//   String _applySmartCorrections(String text) {
//     String result = text;
//     List<String> words = result.split(' ');
//
//     for (int i = 0; i < words.length; i++) {
//       String word = words[i];
//       if (RegExp(r'^[A-Z0-9]+$').hasMatch(word)) {
//         if (RegExp(r'^[A-Z]{2}$').hasMatch(word)) {
//           continue;
//         } else if (RegExp(r'^[A-Z]+$').hasMatch(word) && word.length <= 3) {
//           word = word
//               .replaceAll('S', '5')
//               .replaceAll('O', '0')
//               .replaceAll('I', '1')
//               .replaceAll('l', '1');
//         } else if (RegExp(r'^[0-9A-Z]+$').hasMatch(word)) {
//           word = word
//               .replaceAll('S', '5')
//               .replaceAll('O', '0')
//               .replaceAll('I', '1')
//               .replaceAll('l', '1')
//               .replaceAll('Z', '2')
//               .replaceAll('G', '6')
//               .replaceAll('B', '8');
//         }
//         words[i] = word;
//       }
//     }
//     return words.join(' ');
//   }
//
//   List<String> _extractVehicleNumbers(String text) {
//     List<String> vehicleNumbers = [];
//     String cleanedText = _cleanOCRText(text);
//     String smartCorrectedText = _applySmartCorrections(cleanedText);
//
//     List<RegExp> patterns = [
//       RegExp(r'\b[A-Z]{2}\s*\d{1,2}\s*[A-Z]{1,3}\s*\d{1,4}\b'),
//       RegExp(r'\b[A-Z]{2}\s*\d{1,2}\s*[A-Z]{1,2}\s*\d{1,5}\b'),
//     ];
//
//     for (RegExp pattern in patterns) {
//       Iterable<Match> matches = pattern.allMatches(smartCorrectedText);
//       for (Match match in matches) {
//         String numberPlate = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
//         if (!vehicleNumbers.contains(numberPlate) && _isValidIndianPlateFormat(numberPlate)) {
//           vehicleNumbers.add(numberPlate);
//         }
//       }
//     }
//
//     if (vehicleNumbers.isEmpty) {
//       List<String> words = smartCorrectedText.split(RegExp(r'\s+'));
//       if (words.length >= 4) {
//         for (int i = 0; i <= words.length - 4; i++) {
//           String candidate = words[i] + words[i + 1] + words[i + 2] + words[i + 3];
//           if (_isValidIndianPlateFormat(candidate)) {
//             vehicleNumbers.add(candidate);
//           }
//         }
//       }
//     }
//
//     return vehicleNumbers;
//   }
//
//   bool _isValidIndianPlateFormat(String plate) {
//     plate = plate.replaceAll(' ', '').toUpperCase();
//     List<RegExp> validFormats = [
//       RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{1,4}$'),
//       RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,5}$'),
//     ];
//     return validFormats.any((pattern) => pattern.hasMatch(plate));
//   }
//
//   double _calculateSimilarity(String str1, String str2) {
//     if (str1 == str2) return 1.0;
//     int longer = str1.length > str2.length ? str1.length : str2.length;
//     if (longer == 0) return 1.0;
//     return (longer - _getLevenshteinDistance(str1, str2)) / longer.toDouble();
//   }
//
//   int _getLevenshteinDistance(String str1, String str2) {
//     List<List<int>> matrix = List.generate(
//       str1.length + 1, (i) => List.filled(str2.length + 1, 0),
//     );
//
//     for (int i = 0; i <= str1.length; i++) matrix[i][0] = i;
//     for (int j = 0; j <= str2.length; j++) matrix[0][j] = j;
//
//     for (int i = 1; i <= str1.length; i++) {
//       for (int j = 1; j <= str2.length; j++) {
//         int cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
//         matrix[i][j] = [
//           matrix[i - 1][j] + 1,
//           matrix[i][j - 1] + 1,
//           matrix[i - 1][j - 1] + cost,
//         ].reduce((a, b) => a < b ? a : b);
//       }
//     }
//     return matrix[str1.length][str2.length];
//   }
//
//   void _verifyNumber() {
//     if (_enteredNumber.isEmpty || _extractedText == null || _extractedText!.isEmpty) {
//       setState(() => _result = 'Please upload a document/video and enter the vehicle number');
//       return;
//     }
//
//     // Remove spaces from entered number for comparison
//     String cleanedEntered = _enteredNumber.replaceAll(' ', '').toUpperCase().trim();
//
//     if (!_isValidIndianPlateFormat(cleanedEntered)) {
//       setState(() => _result = 'Invalid vehicle number format. Use format like: MH 12 AB 1234');
//       return;
//     }
//
//     List<String> extractedNumbers = _extractVehicleNumbers(_extractedText!);
//
//     for (String extractedNumber in extractedNumbers) {
//       if (extractedNumber == cleanedEntered) {
//         setState(() => _result = '✅ Vehicle number matches the document perfectly!');
//         return;
//       }
//     }
//
//     double bestSimilarity = 0.0;
//     String bestMatch = '';
//
//     for (String extractedNumber in extractedNumbers) {
//       double similarity = _calculateSimilarity(extractedNumber, cleanedEntered);
//       if (similarity > bestSimilarity) {
//         bestSimilarity = similarity;
//         bestMatch = extractedNumber;
//       }
//     }
//
//     String smartCorrectedText = _applySmartCorrections(_extractedText!);
//     String cleanedExtracted = smartCorrectedText.replaceAll(RegExp(r'[^A-Z0-9]'), '');
//
//     if (cleanedExtracted.contains(cleanedEntered)) {
//       setState(() => _result = '✅ Vehicle number found in document!');
//       return;
//     }
//
//     double textSimilarity = _calculateSimilarity(cleanedExtracted, cleanedEntered);
//     if (textSimilarity >= 0.8) {
//       setState(() => _result = '✅ Vehicle number matches document text');
//       return;
//     }
//
//     if (bestSimilarity >= 0.85) {
//       setState(() => _result = '✅ Vehicle number matches (${(bestSimilarity * 100).toStringAsFixed(1)}% similarity with $bestMatch)');
//     } else if (bestSimilarity >= 0.70) {
//       setState(() => _result = '⚠️ Partial match found (${(bestSimilarity * 100).toStringAsFixed(1)}% similarity with $bestMatch). Please verify manually.');
//     } else {
//       setState(() => _result = '❌ Vehicle number does not match the document');
//     }
//   }
//
//   void _showSnackBar(String message, Color color) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: color, duration: Duration(seconds: 3)),
//       );
//     }
//   }
//
//   void _showImageSourceDialog() {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return SafeArea(
//           child: Container(
//             child: Wrap(
//               children: [
//                 ListTile(
//                   leading: Icon(Icons.photo_camera, color: Colors.blue),
//                   title: Text('Camera (Photo)'),
//                   onTap: () { Navigator.pop(context); _pickImageFromCamera(); },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.videocam, color: Colors.red),
//                   title: Text('Camera (Video)'),
//                   onTap: () { Navigator.pop(context); _recordVideo(); },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.photo_library, color: Colors.green),
//                   title: Text('Gallery (Image)'),
//                   onTap: () { Navigator.pop(context); _pickImageFromGallery(); },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.video_library, color: Colors.purple),
//                   title: Text('Gallery (Video)'),
//                   onTap: () { Navigator.pop(context); _pickVideoFile(); },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.description, color: Colors.orange),
//                   title: Text('File (PDF/Image)'),
//                   onTap: () { Navigator.pop(context); _pickFile(); },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Vehicle Number Plate Verifier'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Card(
//               elevation: 3,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     TextField(
//                       controller: _numberController,
//                       inputFormatters: [
//                         VehicleNumberFormatter(),
//                         LengthLimitingTextInputFormatter(15), // Prevent excessive length
//                       ],
//                       decoration: InputDecoration(
//                         border: OutlineInputBorder(),
//                         labelText: 'Enter Vehicle Number',
//                         prefixIcon: Icon(Icons.directions_car),
//                         helperText: 'Format: MH 12 AB 1234 (spaces auto-added)',
//                         hintText: 'MH 12 AB 1234',
//                       ),
//                       textCapitalization: TextCapitalization.characters,
//                       onChanged: (val) => _enteredNumber = val,
//                     ),
//                     SizedBox(height: 16),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton.icon(
//                         icon: Icon(Icons.add_a_photo),
//                         label: Text('Upload Document/Video'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.blue,
//                           foregroundColor: Colors.white,
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         onPressed: _isLoading ? null : _showImageSourceDialog,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             // Video player and frame info
//             if (_selectedVideo != null && _videoController != null) ...[
//               SizedBox(height: 16),
//               Card(
//                 elevation: 3,
//                 child: Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Column(
//                     children: [
//                       Text('Selected Video:', style: TextStyle(fontWeight: FontWeight.bold)),
//                       SizedBox(height: 8),
//                       Container(
//                         height: 200,
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: _videoController!.value.isInitialized
//                             ? ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: AspectRatio(
//                             aspectRatio: _videoController!.value.aspectRatio,
//                             child: VideoPlayer(_videoController!),
//                           ),
//                         )
//                             : Center(child: CircularProgressIndicator()),
//                       ),
//                       if (_videoController!.value.isInitialized) ...[
//                         SizedBox(height: 8),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             IconButton(
//                               icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
//                               onPressed: () {
//                                 setState(() {
//                                   if (_videoController!.value.isPlaying) {
//                                     _videoController!.pause();
//                                   } else {
//                                     _videoController!.play();
//                                   }
//                                 });
//                               },
//                             ),
//                             Text('${_extractedFrames.length} frames extracted'),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//
//             // Image display widget
//             if (_selectedImage != null && _selectedVideo == null) ...[
//               SizedBox(height: 16),
//               Card(
//                 elevation: 3,
//                 child: Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Column(
//                     children: [
//                       Text('Selected Image:', style: TextStyle(fontWeight: FontWeight.bold)),
//                       SizedBox(height: 8),
//                       Container(
//                         height: 200,
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: Image.file(
//                             _selectedImage!,
//                             fit: BoxFit.contain,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//
//             if (_extractedText != null && _extractedText!.isNotEmpty) ...[
//               SizedBox(height: 16),
//               Card(
//                 elevation: 3,
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Extracted Text:', style: TextStyle(fontWeight: FontWeight.bold)),
//                       SizedBox(height: 8),
//                       Container(
//                         padding: EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[100],
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.grey[300]!),
//                         ),
//                         child: Text(
//                           _extractedText!,
//                           style: TextStyle(fontFamily: 'monospace'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//
//             SizedBox(height: 20),
//             ElevatedButton.icon(
//               icon: Icon(Icons.verified),
//               label: Text('Verify Number'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 foregroundColor: Colors.white,
//                 padding: EdgeInsets.symmetric(vertical: 15),
//                 textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               onPressed: _enteredNumber.isNotEmpty &&
//                   _extractedText != null &&
//                   _extractedText!.isNotEmpty &&
//                   !_isLoading
//                   ? _verifyNumber
//                   : null,
//             ),
//
//             if (_isLoading) ...[
//               SizedBox(height: 20),
//               Center(
//                 child: Column(
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 8),
//                     Text('Processing...'),
//                   ],
//                 ),
//               ),
//             ],
//
//             if (_result != null) ...[
//               SizedBox(height: 20),
//               Card(
//                 elevation: 3,
//                 color: _result!.contains('✅')
//                     ? Colors.green[50]
//                     : _result!.contains('⚠️')
//                     ? Colors.orange[50]
//                     : Colors.red[50],
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Text(
//                     _result!,
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: _result!.contains('✅')
//                           ? Colors.green[700]
//                           : _result!.contains('⚠️')
//                           ? Colors.orange[700]
//                           : Colors.red[700],
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }