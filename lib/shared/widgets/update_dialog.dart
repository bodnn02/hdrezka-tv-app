import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/update_provider.dart';

class UpdateDialog extends ConsumerWidget {
  final ReleaseInfo release;

  const UpdateDialog({super.key, required this.release});

  static Future<void> show(BuildContext context, ReleaseInfo release) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(updateDownloadProvider);
    final isDownloading = download.status == DownloadStatus.downloading;
    final isInstalling = download.status == DownloadStatus.installing;
    final hasError = download.status == DownloadStatus.error;
    final busy = isDownloading || isInstalling;

    return PopScope(
      canPop: !busy,
      child: Center(
        child: SizedBox(
          width: 560,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x44FFFFFF), Color(0x14FFFFFF)],
                  ),
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 48, spreadRadius: -8),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Доступно обновление',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Версия ${release.version}',
                                style: const TextStyle(
                                  color: AppColors.onSurfaceMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Container(height: 0.5, color: AppColors.glassBorder),
                    const SizedBox(height: 20),

                    // Changelog
                    const Text(
                      'Что нового',
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Text(
                          release.changelog,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error message
                    if (hasError) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                download.errorMessage ?? 'Неизвестная ошибка',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Progress bar
                    if (isDownloading) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(height: 6, color: Colors.white.withAlpha(25)),
                                  FractionallySizedBox(
                                    widthFactor: download.progress,
                                    child: Container(
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [AppColors.accent, AppColors.accentSecondary],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(download.progress * 100).round()}%',
                            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (isInstalling) ...[
                      const Row(
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Запуск установщика…',
                            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!busy)
                          _DialogButton(
                            label: 'Позже',
                            onSelect: () {
                              ref.read(updateDownloadProvider.notifier).reset();
                              ref.read(updateCheckProvider.notifier).dismiss();
                              Navigator.of(context).pop();
                            },
                          ),
                        const SizedBox(width: 12),
                        _DialogButton(
                          label: busy
                              ? (isInstalling ? 'Устанавливается…' : 'Загрузка…')
                              : (hasError ? 'Повторить' : 'Обновить'),
                          accent: true,
                          enabled: !isInstalling,
                          onSelect: busy && !hasError
                              ? null
                              : () {
                                  ref
                                      .read(updateDownloadProvider.notifier)
                                      .downloadAndInstall(release);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final bool accent;
  final bool enabled;
  final VoidCallback? onSelect;

  const _DialogButton({
    required this.label,
    this.accent = false,
    this.enabled = true,
    this.onSelect,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.enabled && widget.onSelect != null;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (!effectiveEnabled) return KeyEventResult.ignored;
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: effectiveEnabled ? widget.onSelect : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: widget.accent
                    ? LinearGradient(
                        colors: [
                          AppColors.accent.withAlpha(_focused ? 230 : 200),
                          AppColors.accentSecondary.withAlpha(_focused ? 230 : 200),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withAlpha(_focused ? 35 : 20),
                          Colors.white.withAlpha(_focused ? 15 : 8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: Border.all(
                  color: _focused ? AppColors.glassBorderFocus : AppColors.glassBorder,
                  width: _focused ? 2 : 1,
                ),
                boxShadow: _focused
                    ? [BoxShadow(
                        color: widget.accent
                            ? AppColors.accentGlow
                            : const Color(0x40FFFFFF),
                        blurRadius: 20,
                      )]
                    : null,
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: effectiveEnabled ? Colors.white : AppColors.onSurfaceMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
