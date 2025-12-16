import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:nic_typer/scan_service.dart';
import 'package:image/image.dart' as Img;

class CameraPage extends StatefulWidget {
  final String? serverUrl;

  const CameraPage({super.key, this.serverUrl});

  @override
  State createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late Future<bool> _camLoad;
  CameraController? _camControl;

  bool flashOn = false;

  bool _scanning = false;
  bool? _success;
  final ScanService _scanService = ScanService();

  Dio? http;

  GlobalKey mrzZoneKey = GlobalKey();
  GlobalKey cameraViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _camLoad = initCamera();

    if (widget.serverUrl != null) {
      http = Dio(BaseOptions(baseUrl: widget.serverUrl!));
    }
  }

  Future<bool> initCamera() async {
    final cameras = await availableCameras();
    _camControl = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _camControl!.initialize();
    //await _camControl!.startImageStream((image) {},);
    return true;
  }

  Future<void> toggleFlash() async {
    setState(() {
      flashOn = !flashOn;
    });

    await _camControl!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> capture() async {
    setState(() => _scanning = true);
    XFile file = await _camControl!.takePicture();

    MRZResult? result = await _scanService.detectDocumentNumber(
      await Img.decodeImageFile(file.path) ?? Img.Image.empty(),
    );

    if (result != null) {
      if (http != null) {
        await http!.post(
          "/api/v1/mrz",
          data: jsonEncode({
            "documentType": result.documentType,
            "countryCode": result.countryCode,
            "surnames": result.surnames,
            "givenNames": result.givenNames,
            "documentNumber": result.documentNumber,
            "nationalityCountryCode": result.nationalityCountryCode,
            "birthDate": result.birthDate.toString(),
            "sex": result.sex.toString(),
            "expiryDate": result.expiryDate.toString(),
            "personalNumber": result.personalNumber,
            "personalNumber2": result.personalNumber2,
          }),
        );
      }
    }

    setState(() {
      _scanning = false;
      _success = result != null;

      if (_success != null) {
        Timer(Duration(seconds: 2), () {
          setState(() => _success = null);
        });
      }
    });
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
                  return buildUi(context);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          if (_scanning) Center(child: CircularProgressIndicator()),
          if (_success != null)
            Center(
              child: Icon(
                _success! ? Icons.check : Icons.error,
                size: 64,
                color: _success! ? Colors.green : Colors.red,
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
              onPressed: capture,
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

  Widget buildUi(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(key: cameraViewKey, _camControl!)),
        Positioned(
          left: 16,
          right: 16,
          top: 64,
          bottom: 64 + 40,
          child: Opacity(
            opacity: 0.3,
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 4,
              height: MediaQuery.of(context).size.height / 4,
              child: Card(color: Colors.white),
            ),
          ),
        ),
        Positioned(
          left: 40,
          top: 64 + 20,
          bottom: 64 + 64,
          child: Opacity(
            opacity: 0.2,
            child: SizedBox(
              key: mrzZoneKey,
              width: 128,
              child: Card(color: Colors.yellow),
            ),
          ),
        ),
      ],
    );
  }
}
