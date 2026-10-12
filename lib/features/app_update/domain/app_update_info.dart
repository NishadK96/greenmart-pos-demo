class AppUpdateInfo {
  const AppUpdateInfo({
    required this.updateAvailable,
    required this.version,
    required this.minimumVersion,
    required this.mandatory,
    required this.filename,
    required this.downloadUrl,
    required this.sha256,
    required this.size,
    required this.channel,
    required this.releaseNotes,
  });

  final bool updateAvailable;
  final String? version;
  final String? minimumVersion;
  final bool mandatory;
  final String? filename;
  final String? downloadUrl;
  final String? sha256;
  final int? size;
  final String? channel;
  final List<String> releaseNotes;

  bool get canInstall =>
      updateAvailable &&
      version != null &&
      downloadUrl != null &&
      downloadUrl!.isNotEmpty &&
      sha256 != null &&
      sha256!.isNotEmpty &&
      size != null &&
      size! > 0;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final notes = json['release_notes'];
    return AppUpdateInfo(
      updateAvailable: json['update_available'] == true,
      version: json['version']?.toString(),
      minimumVersion: json['minimum_version']?.toString(),
      mandatory: json['mandatory'] == true,
      filename: json['filename']?.toString(),
      downloadUrl: json['download_url']?.toString(),
      sha256: json['sha256']?.toString().toLowerCase(),
      size: switch (json['size']) {
        int value => value,
        final value => int.tryParse(value?.toString() ?? ''),
      },
      channel: json['channel']?.toString(),
      releaseNotes: notes is List
          ? notes.map((note) => note.toString()).toList(growable: false)
          : notes == null || notes.toString().trim().isEmpty
          ? const []
          : [notes.toString()],
    );
  }
}
