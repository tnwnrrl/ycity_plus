import 'package:flutter/material.dart';
import '../models/vehicle_service_error.dart';

/// 개선된 에러 위젯 - VehicleServiceError 전용
class EnhancedErrorWidget extends StatelessWidget {
  final VehicleServiceError error;
  final VoidCallback? onRetry;
  final VoidCallback? onSettings;
  final bool showDetails;

  const EnhancedErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onSettings,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getErrorColor(error.type).withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 에러 아이콘
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getErrorColor(error.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      error.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 에러 메시지
                Text(
                  error.userMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // 권장 액션
                Text(
                  error.recommendedAction,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),

                // 상세 정보 (선택적)
                if (showDetails && error.details != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.3)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '상세 정보: ${error.details}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 액션 버튼들
                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final List<Widget> buttons = [];

    // 재시도 버튼
    if (error.isRecoverable && onRetry != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_getRetryButtonText()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // 설정 버튼 (네트워크 에러인 경우)
    if (error.type == VehicleServiceErrorType.network && onSettings != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_rounded),
          label: const Text('네트워크 설정'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            side: const BorderSide(color: Color(0xFF6366F1)),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: buttons
          .map(
            (button) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: button,
            ),
          )
          .toList(),
    );
  }

  Color _getErrorColor(VehicleServiceErrorType type) {
    switch (type) {
      case VehicleServiceErrorType.network:
        return Colors.orange;
      case VehicleServiceErrorType.timeout:
        return Colors.amber;
      case VehicleServiceErrorType.parsing:
        return Colors.purple;
      case VehicleServiceErrorType.server:
        return Colors.red;
      case VehicleServiceErrorType.validation:
        return Colors.blue;
      case VehicleServiceErrorType.unknown:
        return Colors.grey;
    }
  }

  String _getRetryButtonText() {
    switch (error.type) {
      case VehicleServiceErrorType.network:
        return '연결 다시 시도';
      case VehicleServiceErrorType.timeout:
        return '다시 시도';
      case VehicleServiceErrorType.parsing:
        return '새로고침';
      case VehicleServiceErrorType.server:
        return '재시도';
      default:
        return '다시 시도';
    }
  }
}

/// 에러 스낵바 생성 유틸리티
class ErrorSnackBar {
  static SnackBar create(
    VehicleServiceError error, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    return SnackBar(
      content: Row(
        children: [
          Text(
            error.icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.userMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (error.recommendedAction.isNotEmpty)
                  Text(
                    error.recommendedAction,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: _getSnackBarColor(error.type),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      action: error.isRecoverable && onRetry != null
          ? SnackBarAction(
              label: '재시도',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );
  }

  static Color _getSnackBarColor(VehicleServiceErrorType type) {
    switch (type) {
      case VehicleServiceErrorType.network:
        return Colors.orange.shade600;
      case VehicleServiceErrorType.timeout:
        return Colors.amber.shade700;
      case VehicleServiceErrorType.parsing:
        return Colors.purple.shade600;
      case VehicleServiceErrorType.server:
        return Colors.red.shade600;
      case VehicleServiceErrorType.validation:
        return Colors.blue.shade600;
      case VehicleServiceErrorType.unknown:
        return Colors.grey.shade600;
    }
  }
}

/// 에러 상태 표시를 위한 인디케이터 위젯
class ErrorIndicator extends StatelessWidget {
  final VehicleServiceError error;
  final double size;
  final bool showMessage;

  const ErrorIndicator({
    super.key,
    required this.error,
    this.size = 24,
    this.showMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getErrorColor(error.type);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              error.icon,
              style: TextStyle(fontSize: size * 0.6),
            ),
          ),
        ),
        if (showMessage) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              error.userMessage,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Color _getErrorColor(VehicleServiceErrorType type) {
    switch (type) {
      case VehicleServiceErrorType.network:
        return Colors.orange;
      case VehicleServiceErrorType.timeout:
        return Colors.amber.shade700;
      case VehicleServiceErrorType.parsing:
        return Colors.purple;
      case VehicleServiceErrorType.server:
        return Colors.red;
      case VehicleServiceErrorType.validation:
        return Colors.blue;
      case VehicleServiceErrorType.unknown:
        return Colors.grey;
    }
  }
}
