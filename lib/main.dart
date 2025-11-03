import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:id_verification_app/services/storage_service.dart';
import 'package:id_verification_app/vehicle_detection.dart';
import 'package:id_verification_app/videoToText.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Database/stolen_vehicle_database.dart';
import 'faceDetection.dart';
import 'provider/vehicleMatchProvider.dart';

Future<void> main() async {
  // Ensure Flutter engine and plugins are fully initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences safely
  try {
    final prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint("⚠️ SharedPreferences init failed: $e");
  }
  await StorageService.init();
  await VehicleDb.init();

  final vehicleMatchProvider = VehicleMatchProvider();
  await vehicleMatchProvider.init();

  final cameras = await availableCameras();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleMatchProvider>.value(
          value: vehicleMatchProvider,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: VehicleDetectionScreen(),
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
      ),
    ),
  );
}
