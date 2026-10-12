import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/localized_text.dart';
import '../../auth/auth_controller.dart';
import 'windows_update_gate.dart';

class AppUpdateSettingsCard extends ConsumerStatefulWidget {
  const AppUpdateSettingsCard({super.key});

  @override
  ConsumerState<AppUpdateSettingsCard> createState() =>
      _AppUpdateSettingsCardState();
}

class _AppUpdateSettingsCardState extends ConsumerState<AppUpdateSettingsCard> {
  String? _version;
  String? _status;
  DateTime? _lastChecked;
  bool _checking = false;

  bool get _supportsInstaller =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await installedAppVersion();
      if (mounted) setState(() => _version = version);
    } catch (_) {
      if (mounted) setState(() => _version = 'Unavailable');
    }
  }

  Future<void> _check() async {
    if (_checking || !_supportsInstaller) return;
    setState(() {
      _checking = true;
      _status = null;
    });
    try {
      final version = _version ?? await installedAppVersion();
      final token = await ref.read(authControllerProvider.future);
      if (token == null || token.isEmpty || token == 'offline-local-session') {
        throw const FormatException(
          'Connect and sign in to check for updates.',
        );
      }
      final update = await ref
          .read(apiProvider)
          .windowsAppUpdate(accessToken: token, currentVersion: version);
      if (!mounted) return;
      setState(() {
        _version = version;
        _lastChecked = DateTime.now();
        _status = update.updateAvailable
            ? update.canInstall
                  ? 'Version ${update.version} is available.'
                  : 'An update is available, but its download details are incomplete.'
            : 'You are using the latest version.';
      });
      if (update.canInstall) await showWindowsUpdateDialog(context, update);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastChecked = DateTime.now();
        _status = error is FormatException
            ? error.message
            : 'Unable to check for updates right now.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        _status ??
        (_supportsInstaller
            ? 'Required updates appear after sign in. Check here for optional updates.'
            : kIsWeb
            ? 'The web app is updated automatically.'
            : 'Automatic installers are currently available on Windows.');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE7E3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('App updates'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(status),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (_lastChecked != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${context.tr('Last checked')}: ${_time(_lastChecked!)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _VersionBadge(version: _version),
              OutlinedButton.icon(
                onPressed: _supportsInstaller && !_checking ? _check : null,
                icon: _checking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  context.tr(_checking ? 'Checking…' : 'Check for updates'),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 14), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});
  final String? version;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6F4),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      '${context.tr('Version')} ${version ?? '…'} · ${context.tr('Stable')}',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
