import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_parser/mrz_parser.dart';
import 'package:nic_typer/scan_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class CameraPage extends StatefulWidget {
  final String mrzPostUrl;

  const CameraPage({super.key, required this.mrzPostUrl});

  @override
  State createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late Future<bool> _camLoad;
  CameraController? _camControl;

  final ScreenshotController _screenshotControl = ScreenshotController();

  bool capturing = false;
  bool? captured;
  bool flashOn = false;

  final GlobalKey cameraPreviewKey = GlobalKey();
  final GlobalKey mrzZoneKey = GlobalKey();

  final ScanService scanService = ScanService();
  late final Dio http;

  @override
  void initState() {
    super.initState();
    _camLoad = initCamera();
    http = Dio(BaseOptions(baseUrl: "${widget.mrzPostUrl}/api/v1/mrz"));
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

  Future<void> capture(BuildContext context) async {
    setState(() => capturing = true);

    final filePath = await _screenshotControl.captureAndSave(
      (await getTemporaryDirectory()).path,
      fileName: "captured.png",
    );

    if (filePath == null) {
      return;
    }

    setState(() {
      capturing = false;
      captured = null;
      Timer(Duration(seconds: 2), () => setState(() => captured = null));
    });
    
    final result = process(filePath);
    result.then((value) {
      setState(() {
      capturing = false;
      captured = value;
      Timer(Duration(seconds: 2), () => setState(() => captured = null));
    });
    });
  }

  Future<bool> process(String filePath) async {
    img.Image? image = await img.decodePngFile(filePath);
    if (image == null) {
      setState(() => capturing = false);
      return false;
    }

    image = img.copyCrop(
      image,
      x: 0,
      y: 32,
      width: image.width ~/ 2,
      height: image.height,
    );

    image = img.copyRotate(image, angle: -90);

    /*if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              Image.memory(img.encodeBmp(image!).buffer.asUint8List()),
        ),
      );
    }*/

    MRZResult? result = await scanService.scanDocumentNumber(
      image,
      onlyDocumentNumber: true,
    );

    if (result == null) {
      return false;
    }

      await http.post(
        widget.mrzPostUrl,
        data: {
          "documentType": (result.documentType.isEmpty
              ? null
              : result.documentType),
          "countryCode": (result.countryCode.isEmpty
              ? null
              : result.countryCode),
          "surnames": (result.surnames.isEmpty ? null : result.surnames),
          "givenNames": (result.givenNames.isEmpty ? null : result.givenNames),
          "documentNumber": (result.documentNumber.isEmpty
              ? null
              : result.documentNumber),
          "nationalityCountryCode": (result.nationalityCountryCode.isEmpty
              ? null
              : result.nationalityCountryCode),
          "birthDate": result.birthDate.toIso8601String(),
          "sex": (result.sex == Sex.none
              ? null
              : result.sex.name[0].toUpperCase()),
          "expiryDate": result.expiryDate.toIso8601String(),
          "personalNumber": (result.personalNumber.isEmpty
              ? null
              : result.personalNumber),
          "personalNumber2": result.personalNumber2,
        },
      );
    return true;
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
            child: Center(
              child: IconButton(
                onPressed: () => capture(context),
                icon: Icon(Icons.camera, size: 64),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16.0,
            child: RotatedBox(
              quarterTurns: 1,
              child: IconButton(
                onPressed: () => toggleFlash(),
                icon: Icon(
                  Icons.flash_on,
                  color: (flashOn ? Colors.white : Colors.grey),
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCameraUi(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        Screenshot(
          controller: _screenshotControl,
          child: Positioned.fill(child: _camControl!.buildPreview()),
        ),
        Positioned(
          left: 32,
          top: 96,
          bottom: 96,
          child: Container(
            key: mrzZoneKey,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.teal,
                width: 8,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            width: screenSize.width * 0.4,
            height: screenSize.height * 0.8,
          ),
        ),
      ],
    );
  }
}
