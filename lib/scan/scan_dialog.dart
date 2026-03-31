import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:nic_typer/scan/scan.dart';

class ScanDialog extends StatelessWidget {
  final Scan scan;

  const ScanDialog({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [buildContent(context, scan), buildActions(context)],
      ),
    );
  }

  Widget buildContent(BuildContext context, Scan scan) {
    final image = scan.image;
    final bytes = img.encodeJpg(image);

    return SizedBox(height: 256, child: Image.memory(bytes, fit: BoxFit.cover));
  }

  Widget buildActions(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
