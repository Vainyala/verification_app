// import 'dart:io';
// import 'package:http/http.dart' as http;
//
// class UploadService {
//   // static const String baseUrl = "http://192.168.0.106:5000"; // or localhost if emulator
//   static const String baseUrl = "https://08667ad8beb8.ngrok-free.app";
//
//   static Future<bool> uploadImage(File imageFile, String userId) async {
//     try {
//       var request = http.MultipartRequest(
//         "POST",
//         Uri.parse("$baseUrl/api/upload"),
//       );
//
//       // Add userId field
//       request.fields['userId'] = userId;
//
//       // Add image file
//       request.files.add(
//         await http.MultipartFile.fromPath('image', imageFile.path),
//       );
//
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         print("✅ Upload success");
//         return true;
//       } else {
//         print("❌ Upload failed: ${response.statusCode}");
//         return false;
//       }
//     } catch (e) {
//       print("❌ Upload error: $e");
//       return false;
//     }
//   }
// }
