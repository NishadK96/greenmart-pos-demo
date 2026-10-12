import 'package:eazy_pos/apis/api.dart';
import 'package:eazy_pos/features/app_update/domain/app_update_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('maps a complete Windows update response', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final api = Api(
      client: MockClient((request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return http.Response(
          '''{"data":{"update_available":true,"version":"1.0.0.73","minimum_version":"1.0.0.56","mandatory":false,"filename":"Eazy-POS-Setup-1.0.0.73.exe","download_url":"https://example.com/Eazy-POS-Setup-1.0.0.73.exe","sha256":"ABC123","size":39743737,"channel":"stable","release_notes":["Update support"]}}''',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final update = await api.windowsAppUpdate(
      accessToken: 'test-token',
      currentVersion: '1.0.0.72',
    );

    expect(requestedUri.path, '/connector/api/app-updates/windows');
    expect(requestedUri.queryParameters['current_version'], '1.0.0.72');
    expect(requestedUri.queryParameters['channel'], 'stable');
    expect(requestedHeaders['authorization'], 'Bearer test-token');
    expect(update.updateAvailable, isTrue);
    expect(update.canInstall, isTrue);
    expect(update.version, '1.0.0.73');
    expect(update.sha256, 'abc123');
    expect(update.size, 39743737);
    expect(update.releaseNotes, ['Update support']);
  });

  test('no-update response is not installable', () {
    final update = AppUpdateInfo.fromJson(const {
      'update_available': false,
      'version': '1.0.0.73',
    });

    expect(update.updateAvailable, isFalse);
    expect(update.canInstall, isFalse);
  });
}
