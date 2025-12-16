import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as Img;
import 'package:mrz_scanner_plus/mrz_scanner_plus.dart';
import 'package:path_provider/path_provider.dart';

class ScanService {
  final TextRecognizer recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<MRZResult?> scanDocumentNumber(InputImage image) async {
    final output = await recognizer.processImage(image);
    return MRZHelper.parse(output.text);
  }

  Future<MRZResult?> detectDocumentNumber(Img.Image image) async {
    final output = await recognizer.processImage(await preProcessImage(image));

    final RegExp mrzRegExp = RegExp(r'(.*I<CMR(\d{9})\d([A-Z]{2}\d{8})<+).*');

    final preprocessed = output.text.replaceAll('\n', '').replaceAll(' ', '');
    final mrzMatch = mrzRegExp.firstMatch(preprocessed);
    if (mrzMatch == null) {
      return null;
    }

    return MRZResult(
      documentType: "I",
      countryCode: "CMR",
      surnames: "",
      givenNames: "",
      documentNumber: mrzMatch.group(2)!,
      nationalityCountryCode: "CMR",
      birthDate: DateTime(2001),
      sex: Sex.none,
      expiryDate: DateTime(2025),
      personalNumber: "",
    );
  }

  Future<InputImage> preProcessImage(Img.Image image) async {
    image = Img.copyCrop(
      image,
      x: 16,
      y: 0,
      width: image.width ~/ 3,
      height: image.height,
    );
    image = Img.copyRotate(image, angle: -90);

    final tempDir = await getApplicationDocumentsDirectory();
    final filePath = '${tempDir.path}/manipulated_image.jpg';

    await Img.encodeJpgFile(filePath, image);
    return InputImage.fromFilePath(filePath);
  }
}
