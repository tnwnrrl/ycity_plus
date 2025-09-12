import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/android_resolution_warning_service.dart';

/// Android QHD+ 해상도 문제 해결 안내 다이얼로그
class AndroidResolutionFixDialog extends StatefulWidget {
  const AndroidResolutionFixDialog({super.key});

  @override
  State<AndroidResolutionFixDialog> createState() =>
      _AndroidResolutionFixDialogState();
}

class _AndroidResolutionFixDialogState
    extends State<AndroidResolutionFixDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final resolutionType =
        AndroidResolutionWarningService.getResolutionType(context);
    // ⚠️ cleanup 금지: 테스트 모드 감지 변수
    final isTestMode = AndroidResolutionWarningService.isTestModeEnabled;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Android 해상도 설정 안내',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 문제 설명
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTestMode ? '🧪 테스트 모드 활성화됨' : '⚠️ 해상도 문제 감지',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTestMode
                        ? 'QHD+ 해상도 경고 테스트가 활성화되어 있습니다. 실제 기기에서는 문제가 없을 수 있습니다.'
                        : 'Android 기기에서 가로 해상도가 1440px 이상일 경우 정상적인 위치가 찍히지 않습니다.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 해상도: $resolutionType',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (isTestMode) ...[
                        const SizedBox(height: 4),
                        Text(
                          '테스트 모드: 활성화됨',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[600],
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Android 해상도 설정 화면 이미지
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/android_resolution_settings.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Android 해상도 설정 화면',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '(이미지를 찾을 수 없습니다)',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 다시 보지 않기 체크박스
            Row(
              children: [
                Checkbox(
                  value: _dontShowAgain,
                  onChanged: (value) {
                    setState(() {
                      _dontShowAgain = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    '다시 보지 않기',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        // ⚠️ cleanup 금지: 테스트 모드별 액션 버튼 로직
        if (isTestMode) ...[
          // 테스트 모드 종료
          TextButton(
            onPressed: () {
              // ⚠️ cleanup 금지: 테스트 모드 비활성화 로직
              AndroidResolutionWarningService.setTestMode(false);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QHD+ 해상도 테스트 모드가 비활성화되었습니다.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text('테스트 종료'),
          ),

          // 그대로 진행
          ElevatedButton(
            onPressed: () {
              _handleDismiss();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('테스트 계속'),
          ),
        ] else ...[
          // 그대로 진행
          ElevatedButton(
            onPressed: () {
              _handleDismiss();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ],
    );
  }

  /// 다시 보지 않기 설정 처리
  void _handleDismiss() {
    if (_dontShowAgain) {
      final appState = context.read<AppStateProvider>();
      appState.setAndroidResolutionWarningDismissed(true);

      if (kDebugMode) {
        debugPrint('[AndroidResolutionFixDialog] 다시 보지 않기 설정됨');
      }
    }
  }
}
