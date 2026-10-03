import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';

class ProgressTabView extends StatelessWidget {
  const ProgressTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: const Center(child: Text('Progress dashboard coming soon')),
    );
  }
}
