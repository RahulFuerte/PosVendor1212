import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const MyText(text: "Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("General"),
          _settingTile(
            icon: Icons.print_outlined,
            title: "Printer Settings",
            onTap: () {
              // Navigate to printer settings
            },
          ),
          _settingTile(
            icon: Icons.receipt,
            title: "Billing Settings",
            onTap: () {
              // Navigate to notification settings
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 🔹 Section title widget
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MyText(
        text: title,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  // 🔹 Setting tile widget
  Widget _settingTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black),
      title: MyText(
        text: title,
        color: textColor,
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
