import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:nic_typer/mrz/mrz_parser.dart';
import 'package:path_provider/path_provider.dart';

class ScanService {
  final TextRecognizer recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final MRZForOCR parser = MRZForOCR.td1();

  Future<MRZResult?> scanDocumentNumber(
    Image image, {
    bool onlyDocumentNumber = false,
  }) async {
    final output = await recognizer.processImage(
      await convertImageToInputImage(image),
    );

    if (onlyDocumentNumber) {
      return detectDocumentNumber(cleanupMrzString(output.text));
    }

    // We try to parse with library parser
    final result = parser.parse(output.text, goFurther: true);
    if (result != null) {
      return result;
    }

    // Trying to detect only document number as last resort
    return null;
  }

  Future<MRZResult?> detectDocumentNumber(String mrzString) async {
    final RegExp mrzRegExp = RegExp(r'(.*I<CMR(\d{9})\d([A-Z]{2}\d{8}).*)');

    final preprocessed = mrzString.replaceAll('\n', '').replaceAll(' ', '').replaceAll('O', '0');
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
      personalNumber: mrzMatch.group(3)!,
    );
  }

  Future<InputImage> convertImageToInputImage(Image image) async {
    final filePath = "${(await getTemporaryDirectory()).path}/converted.png";
    await encodePngFile(filePath, image);
    return InputImage.fromFilePath(filePath);
  }

  String cleanupMrzString(String mrzString) {
    // First, we ensure we have a valid starting point
    while (!mrzString.startsWith('I<') && mrzString.length > 1) {
      mrzString = mrzString.substring(1);
    }

    // Then, we remove all spaces
    mrzString = mrzString.replaceAll(' ', '');

    return mrzString;
  }
}
