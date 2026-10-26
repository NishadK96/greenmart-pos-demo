import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../application/windows_update_installer.dart';
import '../domain/app_update_info.dart';

class WindowsUpdateGate extends ConsumerStatefulWidget {
  const WindowsUpdateGate({
    super.key,
    required this.accessToken,
    required this.child,
  });

  final String accessToken;
  final Widget child;

  @override
  ConsumerState<WindowsUpdateGate> createState() => _WindowsUpdateGateState();
}

class _WindowsUpdateGateState extends ConsumerState<WindowsUpdateGate> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final currentVersion = await installedAppVersion();
      final update = await ref
          .read(apiProvider)
          .windowsAppUpdate(
            accessToken: widget.accessToken,
            currentVersion: currentVersion,
          );
      if (!mounted || !update.mandatory || !update.canInstall) return;
      await showWindowsUpdateDialog(context, update);
    } catch (error) {
      if (!mounted || kDebugMode) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to check for app updates right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<String> installedAppVersion() async {
  final package = await PackageInfo.fromPlatform();
  final version = package.version.trim();
  final build = package.buildNumber.trim();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return build.isEmpty || build == '0' ? version : '$version (Build $build)';
  }
  if (build.isEmpty || build == '0' || version.endsWith('.$build')) {
    return version;
  }
  return '$version.$build';
}

Future<void> showWindowsUpdateDialog(
  BuildContext context,
  AppUpdateInfo update, {
  bool preview = false,
  bool allowDismiss = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: preview || allowDismiss || !update.mandatory,
  builder: (_) => _WindowsUpdateDialog(
    update: update,
    preview: preview,
    allowDismiss: allowDismiss,
  ),
);

class _WindowsUpdateDialog extends StatefulWidget {
  const _WindowsUpdateDialog({
    required this.update,
    required this.preview,
    required this.allowDismiss,
  });

  final AppUpdateInfo update;
  final bool preview;
  final bool allowDismiss;

  @override
  State<_WindowsUpdateDialog> createState() => _WindowsUpdateDialogState();
}

class _WindowsUpdateDialogState extends State<_WindowsUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    if (widget.preview) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await downloadAndLaunchWindowsUpdate(
        widget.update,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'The update could not be installed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final canDismiss =
        widget.preview || widget.allowDismiss || !update.mandatory;
    final small = MediaQuery.sizeOf(context).width < 600;
    const dark = Color(0xFF17243A);
    return PopScope(
      canPop: canDismiss && !_downloading,
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: small ? 16 : 32,
          vertical: 20,
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(small ? 24 : 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canDismiss)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: _downloading
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                Container(
                  width: small ? 88 : 104,
                  height: small ? 88 : 104,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9F7F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  update.mandatory ? 'Update Required' : 'Update Available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark,
                    fontSize: small ? 25 : 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Version ${update.version ?? '—'} is ready to install.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF59677B),
                    fontSize: small ? 15 : 18,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(small ? 18 : 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article_outlined, color: dark),
                          const SizedBox(width: 12),
                          const Text(
                            'What’s new',
                            style: TextStyle(
                              color: dark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (update.releaseNotes.isEmpty)
                        const Text(
                          'Release notes are not available for this version.',
                          style: TextStyle(color: Color(0xFF59677B)),
                        )
                      else
                        ...update.releaseNotes.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 7),
                                  child: Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Color(0xFF10A67D),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: const TextStyle(
                                      color: Color(0xFF4F5D70),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _UpdateFact(
                              icon: Icons.insert_drive_file_outlined,
                              label: 'File size',
                              value: _formatSize(update.size),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 45,
                            color: const Color(0xFFD6E1E0),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _UpdateFact(
                              icon: Icons.settings_outlined,
                              label: 'Version',
                              value: update.version ?? '—',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_downloading || widget.preview) ...[
                  const SizedBox(height: 26),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: widget.preview ? .99 : _progress,
                      minHeight: 9,
                      backgroundColor: const Color(0xFFE0E5E9),
                      color: const Color(0xFF10A67D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Downloading... ${((widget.preview ? .99 : _progress) * 100).round()}%',
                      style: const TextStyle(color: Color(0xFF59677B)),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (canDismiss)
                      OutlinedButton(
                        onPressed: _downloading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Later'),
                      ),
                    FilledButton.icon(
                      onPressed: _downloading
                          ? null
                          : widget.preview
                          ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Design preview: no installer will be downloaded.',
                                ),
                              ),
                            )
                          : _install,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        _error == null ? 'Download and install' : 'Try again',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSize(int? size) {
  if (size == null || size <= 0) return 'Not available';
  return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
}

class _UpdateFact extends StatelessWidget {
  const _UpdateFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF263A50)),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF59677B))),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF17243A),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class UpdateDialogPreviewScreen extends StatefulWidget {
  const UpdateDialogPreviewScreen({super.key});

  @override
  State<UpdateDialogPreviewScreen> createState() =>
      _UpdateDialogPreviewScreenState();
}

class _UpdateDialogPreviewScreenState extends State<UpdateDialogPreviewScreen> {
  static const _sample = AppUpdateInfo(
    updateAvailable: true,
    version: '1.0.0.75',
    minimumVersion: '1.0.0.70',
    mandatory: true,
    filename: 'Eazy-POS-Setup-1.0.0.75.exe',
    downloadUrl: null,
    sha256: null,
    size: 39300628,
    channel: 'stable',
    releaseNotes: [
      'Improved performance and stability',
      'Bug fixes and minor enhancements',
    ],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(mandatory: true);
    });
  }

  Future<void> _show({required bool mandatory}) => showWindowsUpdateDialog(
    context,
    AppUpdateInfo(
      updateAvailable: _sample.updateAvailable,
      version: _sample.version,
      minimumVersion: _sample.minimumVersion,
      mandatory: mandatory,
      filename: _sample.filename,
      downloadUrl: _sample.downloadUrl,
      sha256: _sample.sha256,
      size: _sample.size,
      channel: _sample.channel,
      releaseNotes: _sample.releaseNotes,
    ),
    preview: true,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Update dialog preview')),
    body: Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: () => _show(mandatory: true),
            child: const Text('Preview required update'),
          ),
          OutlinedButton(
            onPressed: () => _show(mandatory: false),
            child: const Text('Preview optional update'),
          ),
        ],
      ),
    ),
  );
}
