import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ReleaseInfo {
  final String version;
  final String changelog;
  final String apkUrl;
  final int apkSize;

  const ReleaseInfo({
    required this.version,
    required this.changelog,
    required this.apkUrl,
    required this.apkSize,
  });
}

enum DownloadStatus { idle, downloading, installing, error }

class DownloadProgress {
  final DownloadStatus status;
  final double progress;
  final String? errorMessage;

  const DownloadProgress({
    required this.status,
    this.progress = 0,
    this.errorMessage,
  });

  static const idle = DownloadProgress(status: DownloadStatus.idle);
}

class UpdateService {
  static const _githubOwner = 'bodnn02';
  static const _githubRepo = 'hdrezka-tv-app';
  static const _apiUrl =
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Accept': 'application/vnd.github+json'},
  ));

  Future<ReleaseInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final current = _parseVersion(info.version);

    final resp = await _dio.get<Map<String, dynamic>>(_apiUrl);
    final data = resp.data!;

    final tagName = (data['tag_name'] as String).replaceFirst('v', '');
    final latest = _parseVersion(tagName);

    if (!_isNewer(latest, current)) return null;

    final assets = data['assets'] as List<dynamic>;
    final apkAsset = assets.firstWhere(
      (a) => (a['name'] as String).endsWith('.apk'),
      orElse: () => null,
    );
    if (apkAsset == null) return null;

    final body = (data['body'] as String? ?? '').trim();

    return ReleaseInfo(
      version: tagName,
      changelog: body.isEmpty ? 'Нет описания обновления.' : body,
      apkUrl: apkAsset['browser_download_url'] as String,
      apkSize: apkAsset['size'] as int,
    );
  }

  Future<void> downloadAndInstall(
    ReleaseInfo release,
    void Function(DownloadProgress) onProgress,
  ) async {
    onProgress(const DownloadProgress(
      status: DownloadStatus.downloading,
      progress: 0,
    ));

    try {
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          onProgress(const DownloadProgress(
            status: DownloadStatus.error,
            errorMessage: 'Необходимо разрешение на установку приложений.',
          ));
          return;
        }
      }

      final dir = await getExternalStorageDirectory() ??
          await getApplicationCacheDirectory();
      final savePath = '${dir.path}/hdrezka_update.apk';

      await _dio.download(
        release.apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(DownloadProgress(
              status: DownloadStatus.downloading,
              progress: received / total,
            ));
          }
        },
      );

      onProgress(const DownloadProgress(status: DownloadStatus.installing));

      final result = await OpenFile.open(savePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        onProgress(DownloadProgress(
          status: DownloadStatus.error,
          errorMessage: 'Не удалось запустить установщик: ${result.message}',
        ));
      }
    } on DioException catch (e) {
      onProgress(DownloadProgress(
        status: DownloadStatus.error,
        errorMessage: 'Ошибка загрузки: ${e.message}',
      ));
    } catch (e) {
      onProgress(DownloadProgress(
        status: DownloadStatus.error,
        errorMessage: 'Неизвестная ошибка: $e',
      ));
    }
  }

  List<int> _parseVersion(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

  bool _isNewer(List<int> latest, List<int> current) {
    for (var i = 0; i < 3; i++) {
      final l = i < latest.length ? latest[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
