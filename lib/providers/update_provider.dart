import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((_) => UpdateService());

// Состояние проверки обновлений
sealed class UpdateCheckState {}
class UpdateCheckIdle extends UpdateCheckState {}
class UpdateCheckLoading extends UpdateCheckState {}
class UpdateCheckUpToDate extends UpdateCheckState {}
class UpdateCheckAvailable extends UpdateCheckState {
  final ReleaseInfo release;
  UpdateCheckAvailable(this.release);
}
class UpdateCheckError extends UpdateCheckState {
  final String message;
  UpdateCheckError(this.message);
}

class UpdateCheckNotifier extends StateNotifier<UpdateCheckState> {
  final UpdateService _service;

  UpdateCheckNotifier(this._service) : super(UpdateCheckIdle());

  Future<void> check() async {
    state = UpdateCheckLoading();
    try {
      final release = await _service.checkForUpdate();
      state = release != null
          ? UpdateCheckAvailable(release)
          : UpdateCheckUpToDate();
    } catch (e) {
      state = UpdateCheckError(e.toString());
    }
  }

  void dismiss() => state = UpdateCheckIdle();
}

final updateCheckProvider =
    StateNotifierProvider<UpdateCheckNotifier, UpdateCheckState>(
  (ref) => UpdateCheckNotifier(ref.read(updateServiceProvider)),
);

// Состояние загрузки/установки APK
class UpdateDownloadNotifier extends StateNotifier<DownloadProgress> {
  final UpdateService _service;

  UpdateDownloadNotifier(this._service) : super(DownloadProgress.idle);

  Future<void> downloadAndInstall(ReleaseInfo release) async {
    await _service.downloadAndInstall(release, (progress) {
      state = progress;
    });
  }

  void reset() => state = DownloadProgress.idle;
}

final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadNotifier, DownloadProgress>(
  (ref) => UpdateDownloadNotifier(ref.read(updateServiceProvider)),
);
