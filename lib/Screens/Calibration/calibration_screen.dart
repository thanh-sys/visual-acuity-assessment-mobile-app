import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {

  // Kích thước chuẩn thẻ tín dụng/CCCD (inch)
  static const double creditCardWidthInches = 3.37;  // Chiều dài hơn
  static const double creditCardHeightInches = 2.125; // Chiều ngắn hơn

  // Slider để điều chỉnh chiều dài hiển thị (pixel)
  double _cardWidth = 200;
  double? _savedPpi; // PPI đã lưu trước đó

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

    // Tính PPI dựa trên chiều dài của thẻ
    final screenPpi = (_cardWidth * dpr) / creditCardWidthInches;

    await prefs.setDouble('screen_ppi', screenPpi);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PPI đã được lưu!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hiệu chỉnh màn hình'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: _cardWidth * (creditCardHeightInches / creditCardWidthInches), // CHIỀU NGẮN
                height: _cardWidth, // CHIỀU DÀI (ĐỨNG)
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Đặt thẻ ngân hàng/CCCD lên màn hình.\n'
                  'Kéo thanh trượt để chiều DÀI khung bên dưới trùng với chiều dài của thẻ thật.',
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
                          _cardWidth = (_cardWidth - 1).clamp(100, 500);
                        });
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      child: Slider(
                        value: _cardWidth,
                        min: 100,
                        max: 500,
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
                          _cardWidth = (_cardWidth + 1).clamp(100, 500);
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                // Hiển thị PPI hiện tại và đã lưu
                Text(
                  'PPI hiện tại: ${_calculateCurrentPPI().toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_savedPpi != null)
                  Text(
                    'PPI đã lưu: ${_savedPpi!.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _savePPI,
                  child: const Text('Lưu hiệu chỉnh'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
