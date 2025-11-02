
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:id_verification_app/vehicle_detection.dart';
import 'package:id_verification_app/videoToText.dart';
import 'package:provider/provider.dart';

import 'Database/stolen_vehicle_database.dart';
import 'faceDetection.dart';
import 'provider/vehicleMatchProvider.dart';

// Future<void> main() async {
//   final cameras = await availableCameras();
//   runApp(MaterialApp(
//     debugShowCheckedModeBanner: false,
//     //home:HomeScreen(cameras: cameras),
//     //home: VerifyDocScreen(),
//     //home: videoToText(),
//     //home: LiveFaceVerificationScreen(cameras: cameras),
//     theme: ThemeData(
//       primarySwatch: Colors.blue,
//       visualDensity: VisualDensity.adaptivePlatformDensity,
//     ),
//   ));
// }



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        //home: HomeScreen(cameras: cameras),
        //home: VerifyDocScreen(),
        //home: videoToText(),
        home: VehicleDetectionScreen(),
        //home: LiveFaceVerificationScreen(cameras: cameras),
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
      ),
    ),
  );
}