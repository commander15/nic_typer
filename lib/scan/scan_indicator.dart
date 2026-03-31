import 'package:flutter/material.dart';

class ScanIndicator extends StatefulWidget {
  final ScanIndicatorController controller;

  const ScanIndicator({super.key, required this.controller});

  @override
  State createState() => _ScanIndicatorState();
}

class ScanIndicatorController {
  final ValueNotifier<int> _valueNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _healthyNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _workingNotifier = ValueNotifier<bool>(false);

  int get value => _valueNotifier.value;
  bool get healthy => _healthyNotifier.value;
  bool get working => _workingNotifier.value;

  set value(int value) {
    _valueNotifier.value = value;
  }

  set healthy(bool healthy) {
    _healthyNotifier.value = healthy;
  }

  set working(bool working) {
    _workingNotifier.value = working;
  }

  void update({int? value, bool? healthy, bool? working}) {
    if (value != null) _valueNotifier.value = value;
    if (healthy != null) _healthyNotifier.value = healthy;
    if (working != null) _workingNotifier.value = working;
  }
}

class _ScanIndicatorState extends State<ScanIndicator> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller._healthyNotifier,
      builder: (context, child) {
        return buildX(context, child);
      },
    );
  }

  Widget buildX(BuildContext context, Widget? child) {
    final size = 64.0;
    return SizedBox(
      width: size,
      height: size,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size / 2),
        ),
        color: (widget.controller.healthy ? Colors.blue : Colors.red),
        child: Stack(
          children: [
            Center(
              child: ListenableBuilder(
                listenable: widget.controller._valueNotifier,
                builder: (context, child) {
                  return Text(
                    widget.controller.value.toString(),
                    style: TextStyle(color: Colors.white, fontSize: size / 3),
                  );
                },
              ),
            ),

            ListenableBuilder(
              listenable: widget.controller._workingNotifier,
              builder: (context, child) {
                if (widget.controller.working) {
                  return const Positioned.fill(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 8,
                    ),
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),

            child ?? const SizedBox(),
          ],
        ),
      ),
    );
  }
}
