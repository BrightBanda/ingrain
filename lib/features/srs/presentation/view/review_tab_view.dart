import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';

class ReviewTabView extends StatelessWidget {
  const ReviewTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: const Center(child: Text('SRS review coming soon')),
    );
  }
}
