
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
    const primaryColor = Color(0xFF0A1F44);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: const Text(
          "Add Stolen Vehicle Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: primaryColor,
        elevation: 5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add Vehicle Image",
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildImagePicker(_suspectImage, true),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _regNoController,
              label: "Registration No.",
              icon: Icons.confirmation_number,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _vehicleTypeController,
              label: "Vehicle Type",
              icon: Icons.directions_car,
            ),
            const SizedBox(height: 20),
            _buildVoiceTextField(
              controller: _noteController,
              label: "Short Note",
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveToDatabase,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSaving ? "Saving..." : "Save Vehicle Data",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(File? imageFile, bool isSuspect) {
    return GestureDetector(
      onTap: () => _pickImage(isSuspect),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: imageFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(imageFile, fit: BoxFit.cover, width: double.infinity),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.camera_alt, color: Colors.white70, size: 40),
            SizedBox(height: 10),
            Text(
              "Tap to select image",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

  // 🔹 Voice-enabled Short Note with visual mic state
  Widget _buildVoiceTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: 2,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        suffixIcon: IconButton(
          icon: Icon(
            Icons.mic,
            color: _isListening ? Colors.redAccent : Colors.white70, // 🔴 mic on
          ),
          onPressed: () => _startListening(controller),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

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
    super.dispose();
  }
}
