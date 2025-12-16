import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mrz_scanner_plus/mrz_scanner_plus.dart';
import 'package:nic_typer/scan_service.dart';

class CameraPage extends StatefulWidget {
  final String? serverUrl;

  const CameraPage({super.key, this.serverUrl});

  @override
  State createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late Future<bool> _camLoad;
  CameraController? _camControl;

  bool capturing = false;
  bool? captured;
  bool flashOn = false;

  final ScanService scanService = ScanService();
  late final Dio http;

  GlobalKey mrzZoneKey = GlobalKey();
  GlobalKey cameraViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _camLoad = initCamera();
    http = Dio(BaseOptions(baseUrl: "${widget.serverUrl!}/api/v1/mrz"));
  }

  Future<bool> initCamera() async {
    final cameras = await availableCameras();

    CameraController controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();

    _camControl = controller;
    return true;
  }

  Future<void> capture() async {
    setState(() => capturing = true);

    XFile file = await _camControl!.takePicture();

    setState(() => capturing = false);
  }

  Future<void> toggleFlash() async {
    setState(() {
      flashOn = !flashOn;
    });

    await _camControl?.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder(
              future: _camLoad,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!) {
                  return buildCameraUi(context);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          if (capturing)
            Center(
              child: SizedBox(
                width: 128,
                height: 128,
                child: CircularProgressIndicator(
                  strokeWidth: 18,
                  strokeCap: StrokeCap.round,
                  color: Colors.teal,
                ),
              ),
            ),
          if (captured != null)
            Center(
              child: SizedBox(
                width: 128,
                height: 128,
                child: Icon(
                  captured! ? Icons.check : Icons.close,
                  size: 64,
                  color: captured! ? Colors.green : Colors.red,
                ),
              ),
            ),
          Positioned(
            right: 9,
            top: 32,
            child: Text(
              "Amadou Benjamain",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IconButton(
              onPressed: () => capture(),
              icon: Icon(Icons.camera, size: 64),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16.0,
            child: IconButton(
              onPressed: () {
                toggleFlash();
              },
              icon: Icon(
                Icons.flash_on,
                color: (flashOn ? Colors.white : Colors.grey),
                size: 64,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCameraUi(BuildContext context) {
    return _camControl!.buildPreview();
  }
}
