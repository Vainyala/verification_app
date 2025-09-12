
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:id_verification_app/videoToText.dart';

import 'faceDetection.dart';
Future<void> main() async {
  final cameras = await availableCameras();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home:HomeScreen(cameras: cameras),
    //home: VerifyDocScreen(),
    //home: videoToText(),
    //home: LiveFaceVerificationScreen(cameras: cameras),
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
  ));
}



