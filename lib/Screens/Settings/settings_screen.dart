import 'package:flutter/material.dart';
import '../Calibration/calibration_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.screen_rotation),
            title: const Text('Hiệu chỉnh màn hình'),
            subtitle: const Text('Căn chỉnh kích thước hiển thị cho phù hợp'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CalibrationScreen(),
                ),
              );
            },
          ),
          // Thêm các cài đặt khác ở đây nếu cần
        ],
      ),
    );
  }
}