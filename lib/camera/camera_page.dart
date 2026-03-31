import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart';
import 'package:nic_typer/client/client.dart';
import 'package:nic_typer/scan/scan_dialog.dart';
import 'package:nic_typer/scan/scan_indicator.dart';
import 'package:nic_typer/scan/scan_service.dart';

class CameraPage extends StatefulWidget {
  final String mrzPostUrl;

  const CameraPage({super.key, required this.mrzPostUrl});

  @override
  State createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  Future<bool>? _cameraInitFuture;
  CameraController? _cameraController;

  late Client _client;

  final ScanIndicatorController _controller = ScanIndicatorController();
  late ScanService _scanService;

  @override
  void initState() {
    super.initState();

    _cameraInitFuture = initCamera();

    _client = Client(url: widget.mrzPostUrl);

    _scanService = ScanService(
      onScanned: (scan) {
        _controller.update(healthy: true);
        _client.postMrz(scan.result!);
        Timer(const Duration(seconds: 3), capture);
      },
      onScanError: (scan) async {
        _controller.update(healthy: false, working: false);

        await showDialog(
          context: context,
          builder: (context) => ScanDialog(scan: scan),
        );

        _scanService.resume();
      },
      onScanCountChanged: (value) =>
          _controller.update(value: value, working: value > 0),
    );
  }

  Future<bool> initCamera() async {
    final cameras = await availableCameras();

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();

    return true;
  }

  Future<void> releaseCamera() async {
    await _cameraController!.dispose();
    _cameraController = null;
  }

  Future<void> capture() async {
    final file = await _cameraController?.takePicture();
    if (file == null) return;

    final image = await decodeJpgFile(file.path);
    _scanService.scanDocument(image!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: IconButton(
        onPressed: capture,
        icon: ScanIndicator(controller: _controller),
      ),
      body: FutureBuilder(
        future: _cameraInitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return buildCameraPreview();
          } else {
            return buildLoadScreen(context, "Initializing camera...");
          }
        },
      ),
    );
  }

  Widget buildCameraPreview() {
    return _cameraController!.buildPreview();
  }

  Widget buildLoadScreen(BuildContext context, String msg) {
    return Center(
      child: Column(
        spacing: 32,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), Text(msg)],
      ),
    );
  }

  @override
  void dispose() {
    _scanService.stop();
    releaseCamera();
    super.dispose();
  }
}
