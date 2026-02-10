import 'package:flutter/material.dart';

class NewAdminScreen extends StatelessWidget {
  const NewAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Admin Dashboard")),
      body: const Center(
        child: Text("Welcome, New Admin!"),
      ),
    );
  }
}
