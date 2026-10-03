import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:ingrain/features/settings/presentation/viewmodel/settings_view_model.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(settingsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: builderForState(uiState, context, ref),
    );
  }

  Widget builderForState(
    SettingsUiState uiState,
    BuildContext context,
    WidgetRef ref,
  ) {
    if (uiState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (uiState.error != null) {
      return Center(child: Text('Error: ${uiState.error}'));
    }
    final settings = uiState.settings;
    if (settings == null) {
      return const Center(child: Text('No settings available'));
    }
    return _buildContent(context, ref, settings);
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final vm = ref.read(settingsViewModelProvider.notifier);
    return ListView(
      children: [
        _buildSection('Appearance', [
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeSetting>(
              value: settings.themeMode,
              items: const [
                DropdownMenuItem(
                  value: ThemeSetting.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeSetting.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(value: ThemeSetting.dark, child: Text('Dark')),
              ],
              onChanged: (v) {
                if (v != null) vm.setThemeMode(v);
              },
            ),
          ),
          _buildSliderTile(
            label: 'Subtitle font size',
            value: settings.subtitleFontSize,
            min: 10,
            max: 30,
            divisions: 20,
            onChanged: (v) => vm.setSubtitleFontSize(v),
          ),
        ]),
        _buildSection('Playback', [
          _buildSliderTile(
            label: 'Playback speed',
            value: settings.playbackSpeed,
            min: 0.5,
            max: 3.0,
            divisions: 25,
            onChanged: (v) => vm.setPlaybackSpeed(v),
            formatter: (v) => '${v.toStringAsFixed(1)}x',
          ),
        ]),
        _buildSection('Goals', [
          ListTile(
            title: const Text('Daily goal'),
            trailing: Text('${settings.dailyGoalMinutes} min'),
            onTap: () =>
                _showGoalDialog(context, ref, settings.dailyGoalMinutes),
          ),
        ]),
        _buildSection('About', [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Dictionary attribution'),
            subtitle: const Text('JMdict/EDICT (CC BY-SA 4.0)'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Dictionary Data'),
                  content: const Text(
                    'This app uses JMdict dictionary data licensed under '
                    'CC BY-SA 4.0. Source: '
                    'https://www.jdic.org/codedoc JMdict',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Version'),
            trailing: Text('1.0.0+1'),
          ),
        ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String Function(double)? formatter,
  }) {
    final display = formatter?.call(value) ?? value.toStringAsFixed(1);
    return ListTile(
      title: Text(label),
      trailing: Text(display),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: display,
        onChanged: onChanged,
      ),
    );
  }

  void _showGoalDialog(BuildContext context, WidgetRef ref, int current) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily goal (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '30'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n > 0) {
                ref
                    .read(settingsViewModelProvider.notifier)
                    .setDailyGoalMinutes(n);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
