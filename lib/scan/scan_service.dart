import 'dart:async';

import 'package:image/image.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:nic_typer/scan/scan.dart';
import 'package:path_provider/path_provider.dart';

class ScanService {
  final void Function(Scan result) onScanned;
  final void Function(Scan result) onScanError;
  final void Function(int count) onScanCountChanged;

  bool _working = false;
  String? _lastScanDocNumber;
  final List<Scan> _queue = List.empty(growable: true);

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final RegExp minimalExp = RegExp(r'(I<CMR(\d{9}))');
  final RegExp fullExp = RegExp(r'(I<CMR(\d{9})\d([A-Z]{2}\d{8}))');

  int get pendingScanCount => _queue.length;

  ScanService({
    required this.onScanned,
    required this.onScanError,
    required this.onScanCountChanged,
  });

  void scanDocument(Image image) {
    _queue.add(Scan(image: image));
    onScanCountChanged(_queue.length);
    resume();
  }

  void resume() {
    _working = true;
    _processQueue();
  }

  void stop() {
    _working = false;
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      return;
    }

    final scan = _queue.removeAt(0);
    final result = await _processScan(scan.image);
    if (result == null || result.result == null) {
      stop();
      onScanError(scan);
    } else {
      // Avoid duplicates
      if (true || result.result!.documentNumber != _lastScanDocNumber) {
        _lastScanDocNumber = result.result!.documentNumber;
        onScanned(result);
      }

      onScanCountChanged(_queue.length);
      if (_working) Timer(const Duration(seconds: 2), _processQueue);
    }
  }

  Future<InputImage> _convertImageToInputImage(Image image) async {
    final filePath = "${(await getTemporaryDirectory()).path}/converted.png";
    await encodePngFile(filePath, image);
    return InputImage.fromFilePath(filePath);
  }

  Future<Scan?> _processScan(Image image) async {
    final inputScan = Scan(image: image);

    final text = await _recognizer.processImage(
      await _convertImageToInputImage(inputScan.scannableImage),
    );

    final result = await _parseMrz(text.text);
    return Scan(image: inputScan.scannableImage, result: result);
  }

  Future<MRZResult?> _parseMrz(String str) async {
    final preprocessed = str
        .replaceAll('\n', '')
        .replaceAll(' ', '')
        .replaceAll('O', '0');

    String documentNumber;
    String personalNumber;

    RegExpMatch? mrzMatch = fullExp.firstMatch(preprocessed);
    if (mrzMatch != null) {
      documentNumber = mrzMatch.group(2) ?? "";
      personalNumber = mrzMatch.group(3) ?? "";
    } else {
      mrzMatch = minimalExp.firstMatch(preprocessed);
      if (mrzMatch == null) {
        return null;
      }
      documentNumber = mrzMatch.group(2) ?? "";
      personalNumber = "";
    }

    return MRZResult(
      documentType: "I",
      countryCode: "CMR",
      surnames: "",
      givenNames: "",
      documentNumber: documentNumber,
      nationalityCountryCode: "CMR",
      birthDate: DateTime(2001),
      sex: Sex.none,
      expiryDate: DateTime(2025),
      personalNumber: personalNumber,
    );
  }
}
