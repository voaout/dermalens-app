// Stub used on non-web platforms. The real implementation lives in
// web_camera_web.dart and is selected via conditional import.

import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<Uint8List?> captureFromWebcam(NavigatorState navigator) async => null;
