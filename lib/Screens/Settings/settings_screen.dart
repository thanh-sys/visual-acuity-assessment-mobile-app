import 'package:flutter/material.dart';
import '../Calibration/calibration_screen.dart';
import '../Profile/profile_management.dart';
import 'package:flutter_application_1/Screens/TestHistory/test_history.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Screen'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile Management'),
            subtitle: const Text('View and edit personal information'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileManagement(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.screen_rotation),
            title: const Text('Calibration Screen'),
            subtitle: const Text('Calibration screen for eye chart'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CalibrationScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.screen_rotation),
            title: const Text('Test History'),
            subtitle: const Text('Test History'),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TestHistory(),
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