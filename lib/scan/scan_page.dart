import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nic_typer/scan/scan_indicator.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ScanIndicatorController _controller = ScanIndicatorController();

  @override
  void initState() {
    super.initState();

    Timer.periodic(
      Duration(seconds: 3),
      (timer) => _controller.update(
        healthy: timer.tick % 2 == 0,
        value: _controller.value + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ScanIndicator(controller: _controller),
    );
  }
}
