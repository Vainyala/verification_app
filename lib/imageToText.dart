// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:printing/printing.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
//
// class VerifyDocScreen extends StatefulWidget {
//   @override
//   _VerifyDocScreenState createState() => _VerifyDocScreenState();
// }
//
// class _VerifyDocScreenState extends State<VerifyDocScreen> {
//   String? _extractedText;
//   String _enteredNumber = '';
//   String? _result;
//   bool _isLoading = false;
//   File? _selectedImage;
//   final TextEditingController _numberController = TextEditingController();
//
//   Future<void> _pickFile() async {
//     setState(() {
//       _isLoading = true;
//       _result = null;
//       _extractedText = null;
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
//     // Apply OCR corrections for common misreadings in vehicle plates
//     Map<String, String> corrections = {
//       '@': 'A',
//       '€': 'E',
//       '£': 'E',
//       '¢': 'C',
//       '§': 'S',
//       'µ': 'U',
//       '¤': 'O',
//       '¥': 'Y',
//       '©': 'C',
//       '®': 'R',
//       '&': '8',
//       // Common OCR mistakes in number plates
//       // Only apply these in numeric contexts
//     };
//
//     String cleaned = text.toUpperCase();
//
//     // Apply corrections
//     for (String key in corrections.keys) {
//       cleaned = cleaned.replaceAll(key, corrections[key]!);
//     }
//
//     // Remove special characters and extra spaces
//     cleaned = cleaned
//         .replaceAll(RegExp(r'[^\w\s]'), ' ')
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .trim();
//
//     return cleaned;
//   }
//
//   // Apply smart OCR corrections only where appropriate
//   String _applySmartCorrections(String text) {
//     // Create a more context-aware correction
//     String result = text;
//
//     // Split into words to apply corrections contextually
//     List<String> words = result.split(' ');
//
//     for (int i = 0; i < words.length; i++) {
//       String word = words[i];
//
//       // If word looks like it could be part of a vehicle number
//       if (RegExp(r'^[A-Z0-9]+$').hasMatch(word)) {
//         // Apply number plate specific corrections
//         if (RegExp(r'^[A-Z]{2}$').hasMatch(word)) {
//           // This is likely a state code - don't change letters to numbers
//           continue;
//         } else if (RegExp(r'^[A-Z]+$').hasMatch(word) && word.length <= 3) {
//           // This is likely a letter sequence in middle - be careful
//           word = word
//               .replaceAll('S', '5') // Only in letter sequences at the end
//               .replaceAll('O', '0')
//               .replaceAll('I', '1')
//               .replaceAll('l', '1');
//         } else if (RegExp(r'^[0-9A-Z]+$').hasMatch(word)) {
//           // Mixed sequence - apply corrections carefully
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
//
//     return words.join(' ');
//   }
//
//   // Extract all potential vehicle number patterns from text
//   List<String> _extractVehicleNumbers(String text) {
//     List<String> vehicleNumbers = [];
//
//     // First clean the text
//     String cleanedText = _cleanOCRText(text);
//
//     // Then apply smart corrections
//     String smartCorrectedText = _applySmartCorrections(cleanedText);
//
//     print('Original text: $text');
//     print('Cleaned text: $cleanedText');
//     print('Smart corrected text: $smartCorrectedText');
//
//     // Indian vehicle number patterns (flexible)
//     List<RegExp> patterns = [
//       // Standard format: MH12AB1234, KA02KJ9088
//       RegExp(r'\b[A-Z]{2}\s*\d{1,2}\s*[A-Z]{1,3}\s*\d{1,4}\b'),
//       // More flexible spacing
//       RegExp(r'\b[A-Z]{2}\s*\d{1,2}\s*[A-Z]{1,2}\s*\d{1,5}\b'),
//     ];
//
//     for (RegExp pattern in patterns) {
//       Iterable<Match> matches = pattern.allMatches(smartCorrectedText);
//       for (Match match in matches) {
//         String numberPlate = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
//         if (!vehicleNumbers.contains(numberPlate) && _isValidIndianPlateFormat(numberPlate)) {
//           vehicleNumbers.add(numberPlate);
//           print('Found potential vehicle number: $numberPlate');
//         }
//       }
//     }
//
//     // If no patterns found, try to construct from individual components
//     if (vehicleNumbers.isEmpty) {
//       List<String> words = smartCorrectedText.split(RegExp(r'\s+'));
//       print('Words found: $words');
//
//       if (words.length >= 4) {
//         // Try to combine: STATE CODE LETTERS NUMBERS
//         for (int i = 0; i <= words.length - 4; i++) {
//           String candidate = words[i] + words[i + 1] + words[i + 2] + words[i + 3];
//           if (_isValidIndianPlateFormat(candidate)) {
//             vehicleNumbers.add(candidate);
//             print('Constructed vehicle number: $candidate');
//           }
//         }
//       }
//     }
//
//     return vehicleNumbers;
//   }
//
//   bool _isValidIndianPlateFormat(String plate) {
//     // Remove spaces and convert to uppercase
//     plate = plate.replaceAll(' ', '').toUpperCase();
//
//     // Indian vehicle number format validation
//     List<RegExp> validFormats = [
//       RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{1,4}$'), // KA02KJ9088
//       RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,5}$'), // Some variations
//     ];
//
//     bool isValid = validFormats.any((pattern) => pattern.hasMatch(plate));
//     print('Validating plate format: $plate -> $isValid');
//     return isValid;
//   }
//
//   // Calculate similarity between two strings
//   double _calculateSimilarity(String str1, String str2) {
//     if (str1 == str2) return 1.0;
//
//     int longer = str1.length > str2.length ? str1.length : str2.length;
//     if (longer == 0) return 1.0;
//
//     return (longer - _getLevenshteinDistance(str1, str2)) / longer.toDouble();
//   }
//
//   int _getLevenshteinDistance(String str1, String str2) {
//     List<List<int>> matrix = List.generate(
//       str1.length + 1,
//           (i) => List.filled(str2.length + 1, 0),
//     );
//
//     for (int i = 0; i <= str1.length; i++) {
//       matrix[i][0] = i;
//     }
//
//     for (int j = 0; j <= str2.length; j++) {
//       matrix[0][j] = j;
//     }
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
//
//     return matrix[str1.length][str2.length];
//   }
//
//   void _verifyNumber() {
//     if (_enteredNumber.isEmpty || _extractedText == null || _extractedText!.isEmpty) {
//       setState(() => _result = 'Please upload a document and enter the vehicle number');
//       return;
//     }
//
//     // Clean and normalize the entered number
//     String cleanedEntered = _enteredNumber.replaceAll(' ', '').toUpperCase().trim();
//
//     // Validate the entered number format
//     if (!_isValidIndianPlateFormat(cleanedEntered)) {
//       setState(() => _result = 'Invalid vehicle number format. Use format like: MH12AB1234');
//       return;
//     }
//
//     // Extract all vehicle numbers from the OCR text
//     List<String> extractedNumbers = _extractVehicleNumbers(_extractedText!);
//
//     print('Entered Number: $cleanedEntered');
//     print('Extracted Numbers: $extractedNumbers');
//     print('Full Extracted Text: $_extractedText');
//
//     // Check for exact match first
//     for (String extractedNumber in extractedNumbers) {
//       if (extractedNumber == cleanedEntered) {
//         setState(() => _result = '✅ Vehicle number matches the document perfectly!');
//         return;
//       }
//     }
//
//     // Check for high similarity match
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
//     // Also check against the entire cleaned text with smart corrections
//     String smartCorrectedText = _applySmartCorrections(_extractedText!);
//     String cleanedExtracted = smartCorrectedText.replaceAll(RegExp(r'[^A-Z0-9]'), '');
//
//     if (cleanedExtracted.contains(cleanedEntered)) {
//       setState(() => _result = '✅ Vehicle number found in document!');
//       return;
//     }
//
//     // Check similarity with the entire text
//     double textSimilarity = _calculateSimilarity(cleanedExtracted, cleanedEntered);
//     if (textSimilarity >= 0.8) {
//       setState(() => _result = '✅ Vehicle number matches document text');
//       return;
//     }
//
//     // Determine result based on similarity
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
//         SnackBar(
//           content: Text(message),
//           backgroundColor: color,
//           duration: Duration(seconds: 3),
//         ),
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
//                   title: Text('Camera'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _pickImageFromCamera();
//                   },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.photo_library, color: Colors.green),
//                   title: Text('Gallery'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _pickImageFromGallery();
//                   },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.description, color: Colors.orange),
//                   title: Text('File (PDF/Image)'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _pickFile();
//                   },
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
//                       decoration: InputDecoration(
//                         border: OutlineInputBorder(),
//                         labelText: 'Enter Vehicle Number (e.g., MH12AB1234)',
//                         prefixIcon: Icon(Icons.directions_car),
//                         helperText: 'Supported formats: MH12AB1234, KA02KJ9088, etc.',
//                       ),
//                       textCapitalization: TextCapitalization.characters,
//                       onChanged: (val) => _enteredNumber = val,
//                     ),
//                     SizedBox(height: 16),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton.icon(
//                         icon: Icon(Icons.add_a_photo),
//                         label: Text('Upload Document'),
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
//             if (_selectedImage != null) ...[
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
//                       SizedBox(height: 8),
//
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
//
//   @override
//   void dispose() {
//     _numberController.dispose();
//     super.dispose();
//   }
// }