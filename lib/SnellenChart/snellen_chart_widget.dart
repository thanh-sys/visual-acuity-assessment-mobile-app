import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ppi_calculator.dart';

class SnellenChartWidget extends StatefulWidget {
  final int feet;
  final String letterToDisplay;
  const SnellenChartWidget({
    Key? key,
    required this.feet,
    required this.letterToDisplay,
  }) : super(key: key);

  @override
  State<SnellenChartWidget> createState() => _SnellenChartWidgetState();
}

class _SnellenChartWidgetState extends State<SnellenChartWidget> {
  double? _savedPpi;

  @override
  void initState() {
    super.initState();
    _loadPPI();
  }

  Future<void> _loadPPI() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPpi = prefs.getDouble('screen_ppi');
    });
  }

  double _getFontSize() {
    if (_savedPpi == null) {
      // Fallback to old calculation if PPI is not calibrated
      final Map<int, double> fontSize = {
        70: (16 / 12) * 152,
        60: (16 / 12) * 130,
        50: (16 / 12) * 108,
        40: (16 / 12) * 87,
        30: (16 / 12) * 65,
        20: (16 / 12) * 43,
        15: (16 / 12) * 33,
        10: (16 / 12) * 21,
        7: (16 / 12) * 15,
        4: (16 / 12) * 9,
      };
      return fontSize[widget.feet] ?? 0;
    }

    return getCalibratedFontSize(
      snellenLine: widget.feet.toDouble(),
      screenPpi: _savedPpi!,
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.letterToDisplay,
      style: TextStyle(
        fontSize: _getFontSize(),
        fontFamily: 'Snellen',
      ),
    );
  }
}
