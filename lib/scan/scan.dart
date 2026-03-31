import 'package:image/image.dart';
import 'package:mrz_parser/mrz_parser.dart';

class Scan {
  final Image image;
  final MRZResult? result;

  Image get scannableImage => _generateScannableImage();

  const Scan({required this.image, this.result});

  Image _generateScannableImage() {
    Image image = copyCrop(
      this.image,
      x: 0,
      y: 32,
      width: this.image.width ~/ 2,
      height: this.image.height,
    );

    image = copyRotate(image, angle: -90);

    return image;
  }
}
