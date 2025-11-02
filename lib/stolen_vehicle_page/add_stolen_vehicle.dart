
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../database/stolen_vehicle_database.dart';
import '../../services/vehicle_match_services.dart';

class StolenVehiclePage extends StatefulWidget {
  const StolenVehiclePage({super.key});

  @override
  State<StolenVehiclePage> createState() => _StolenVehiclePageState();
}

class _StolenVehiclePageState extends State<StolenVehiclePage> {
  final _suspectNameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _noteController = TextEditingController(); // Short Note controller

  File? _suspectImage;
  File? _vehicleImage;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();
  final VehicleMatchService _matchService = VehicleMatchService();

  // 🔹 Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _matchService.init();
    VehicleDb.init();
    _speech = stt.SpeechToText();
    _regNoController.addListener(_formatVehicleNumber);
  }

  void _formatVehicleNumber() {
    String text = _regNoController.text.toUpperCase().replaceAll(' ', '');
    String formatted = '';

    // Insert space after 2, 4, and 6 characters
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 3 || i == 5) {
        formatted += ' ';
      }
    }

    // Prevent cursor jump
    if (formatted != _regNoController.text) {
      _regNoController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _pickImage(bool isSuspect) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => _imageSourceSheet(),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() {
        if (isSuspect) {
          _suspectImage = File(picked.path);
        } else {
          _vehicleImage = File(picked.path);
        }
      });
    }
  }

  Widget _imageSourceSheet() {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Take from Camera"),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Choose from Gallery"),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToDatabase() async {
    final suspectImagePath = _suspectImage?.path ?? '';
    final vehicleImagePath = _vehicleImage?.path ?? '';

    if (_regNoController.text.trim().isEmpty ||
        _vehicleTypeController.text.trim().isEmpty ||
        suspectImagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ Please fill all required fields properly")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String imagePath;
      if (suspectImagePath.isNotEmpty) {
        imagePath = suspectImagePath;
      } else if (vehicleImagePath.isNotEmpty) {
        imagePath = vehicleImagePath;
      } else {
        imagePath = 'assets/hatchback_6469044.png';
      }

      List<double> embedding = [];
      try {
        if (suspectImagePath.isNotEmpty) {
          final bytes = await _suspectImage!.readAsBytes();
          embedding = await _matchService.generateEmbedding(bytes);
        } else {
          final bytes = await DefaultAssetBundle.of(context)
              .load('assets/AfzalGurustory216.jpg');
          embedding =
          await _matchService.generateEmbedding(bytes.buffer.asUint8List());
        }
      } catch (e) {
        debugPrint("❌ Error generating embedding: $e");
      }

      await VehicleDb.insertDummyOnce(
        DateTime.now().microsecondsSinceEpoch.toString(),
        _vehicleTypeController.text.trim(),
        embedding,
        imagePath,
        vehicleNumber: _regNoController.text.trim(),
        vehicleType: _vehicleTypeController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("✅ Vehicle & Suspect Data Saved Successfully")),
      );

      _clearFields();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error saving data: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearFields() {
    _suspectNameController.clear();
    _regNoController.clear();
    _vehicleTypeController.clear();
    _noteController.clear();
    _suspectImage = null;
    _vehicleImage = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Add Stolen Vehicle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Form Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Vehicle Image",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildModernImagePicker(_suspectImage),
                        const SizedBox(height: 24),
                        _buildModernTextField(
                          controller: _regNoController,
                          label: "Registration Number",
                          icon: Icons.confirmation_number,
                          hint: "e.g., SH 12 HJ 1234",
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _vehicleTypeController,
                          label: "Vehicle Type",
                          icon: Icons.directions_car,
                          hint: "e.g., Sedan, SUV, Bike",
                        ),
                        const SizedBox(height: 16),
                        _buildModernVoiceTextField(
                          controller: _noteController,
                          label: "Additional Notes",
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveToDatabase,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Save Vehicle Data",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernImagePicker(File? imageFile) {
    return GestureDetector(
      onTap: () => _pickImage(true),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: imageFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(imageFile, fit: BoxFit.cover),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: Color(0xFF1A237E),
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Tap to add vehicle image",
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernVoiceTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: "Add any additional information...",
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.mic,
                  color: _isListening ? Colors.red : const Color(0xFF1A237E),
                ),
                onPressed: () => _startListening(controller),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildImagePicker(File? imageFile, bool isSuspect) {
  //   return GestureDetector(
  //     onTap: () => _pickImage(isSuspect),
  //     child: Container(
  //       height: 150,
  //       width: double.infinity,
  //       decoration: BoxDecoration(
  //         color: Colors.white.withOpacity(0.1),
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(color: Colors.white30),
  //       ),
  //       child: imageFile != null
  //           ? ClipRRect(
  //         borderRadius: BorderRadius.circular(12),
  //         child: Image.file(imageFile, fit: BoxFit.cover, width: double.infinity),
  //       )
  //           : Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: const [
  //           Icon(Icons.camera_alt, color: Colors.white70, size: 40),
  //           SizedBox(height: 10),
  //           Text(
  //             "Tap to select image",
  //             style: TextStyle(color: Colors.white70),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildTextField({
  //   required TextEditingController controller,
  //   required String label,
  //   IconData? icon,
  // }) {
  //   return TextField(
  //     controller: controller,
  //     style: const TextStyle(color: Colors.white),
  //     decoration: InputDecoration(
  //       prefixIcon: Icon(icon, color: Colors.white70),
  //       labelText: label,
  //       labelStyle: const TextStyle(color: Colors.white70),
  //       filled: true,
  //       fillColor: Colors.white.withOpacity(0.1),
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: const BorderSide(color: Colors.white30),
  //       ),
  //       enabledBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: const BorderSide(color: Colors.white30),
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: const BorderSide(color: Colors.white, width: 1.5),
  //       ),
  //     ),
  //   );
  // }
  //
  // // 🔹 Voice-enabled Short Note with visual mic state
  // Widget _buildVoiceTextField({
  //   required TextEditingController controller,
  //   required String label,
  // }) {
  //   return TextField(
  //     controller: controller,
  //     style: const TextStyle(color: Colors.white),
  //     maxLines: 2,
  //     decoration: InputDecoration(
  //       labelText: label,
  //       labelStyle: const TextStyle(color: Colors.white70),
  //       filled: true,
  //       fillColor: Colors.white.withOpacity(0.1),
  //       suffixIcon: IconButton(
  //         icon: Icon(
  //           Icons.mic,
  //           color: _isListening ? Colors.redAccent : Colors.white70, // 🔴 mic on
  //         ),
  //         onPressed: () => _startListening(controller),
  //       ),
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: const BorderSide(color: Colors.white30),
  //       ),
  //       enabledBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: const BorderSide(color: Colors.white30),
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: const BorderSide(color: Colors.white, width: 1.5),
  //       ),
  //     ),
  //   );
  // }

  void _startListening(TextEditingController controller) async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            controller.text = result.recognizedWords;
          });
        },
        onSoundLevelChange: null,
        listenMode: stt.ListenMode.dictation,
      );
      _speech.statusListener = (status) {
        if (status == "notListening") {
          setState(() => _isListening = false); // mic off
        }
      };
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎤 Speech recognition not available")),
      );
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _suspectNameController.dispose();
    _regNoController.dispose();
    _vehicleTypeController.dispose();
    _noteController.dispose();
    _regNoController.removeListener(_formatVehicleNumber);
    _regNoController.dispose();
    super.dispose();
  }
}
