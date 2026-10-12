import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'app_update_settings_card.dart';

class AppUpdateSettingsPreviewScreen extends StatelessWidget {
  const AppUpdateSettingsPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(title: const Text('Settings preview')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure your business and connected services.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            const AppUpdateSettingsCard(),
          ],
        ),
      ),
    ),
  );
}
