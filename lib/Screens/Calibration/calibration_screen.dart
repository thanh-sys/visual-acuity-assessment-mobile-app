import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {

  // Standard credit card/ID card size (inches)
  static const double creditCardWidthInches = 3.37;   // Longer edge
  static const double creditCardHeightInches = 2.125; // Shorter edge

  // Slider to adjust displayed length (pixels)
  double _cardWidth = 200;
  double? _savedPpi; // Previously saved PPI

  @override
  void initState() {
    super.initState();
    _loadSavedPPI();
  }

  Future<void> _loadSavedPPI() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPpi = prefs.getDouble('screen_ppi');
    });
  }

  double _calculateCurrentPPI() {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return (_cardWidth * dpr) / creditCardWidthInches;
  }

  Future<void> _savePPI() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    // Calculate PPI based on the card's long edge
    final screenPpi = (_cardWidth * dpr) / creditCardWidthInches;

    await prefs.setDouble('screen_ppi', screenPpi);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PPI has been saved!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Calibration'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: _cardWidth * (creditCardHeightInches / creditCardWidthInches), // SHORT EDGE
                height: _cardWidth, // LONG EDGE (VERTICAL)
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Place your credit/ID card on the screen.\n'
                  'Adjust the slider until the LONG side of the frame matches the card’s real length.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                         _cardWidth = (_cardWidth - 1).clamp(50, 1200);

                        });
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      child: Slider(
                        value: _cardWidth,
                        min: 100,
                        max: 1200,
                        onChanged: (value) {
                          setState(() {
                            _cardWidth = value;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _cardWidth = (_cardWidth + 1).clamp(50, 1200);
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                // Show current & saved PPI
                Text(
                  'Current PPI: ${_calculateCurrentPPI().toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_savedPpi != null)
                  Text(
                    'Saved PPI: ${_savedPpi!.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _savePPI,
                  child: const Text('Save Calibration'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
