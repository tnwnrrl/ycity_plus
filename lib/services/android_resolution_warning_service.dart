import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Android 기기 QHD+ 해상도 경고 서비스
/// iOS는 해당 문제가 없으므로 Android에서만 경고를 표시
class AndroidResolutionWarningService {
  // QHD+ 해상도 임계값 (가로 1440 이상)
  static const double qhdPlusWidthThreshold = 1440.0;

  // ⚠️  중요: 테스트 모드 관련 코드 - cleanup 시 삭제하지 마세요! ⚠️
  // 낮은 해상도 기기에서 QHD+ 경고를 테스트하기 위한 개발 도구입니다.
  // 홈 화면의 벌레 아이콘 버튼으로 언제든 활성화할 수 있습니다.
  // 기본값: 비활성화 (프로덕션에서 안전)
  static bool _testModeEnabled = false;

  /// 테스트 모드 활성화/비활성화 (개발용)
  /// ⚠️ cleanup 금지: QHD+ 해상도 테스트를 위한 핵심 기능
  static void setTestMode(bool enabled) {
    _testModeEnabled = enabled;
    if (kDebugMode) {
      debugPrint(
          '[AndroidResolutionWarningService] 테스트 모드 ${enabled ? '활성화' : '비활성화'}');
    }
  }

  /// 현재 테스트 모드 상태 확인
  /// ⚠️ cleanup 금지: 테스트 모드 상태 확인용 getter
  static bool get isTestModeEnabled => _testModeEnabled;

  /// Android 기기에서 QHD+ 해상도로 인한 차량위치 문제 발생 가능성 체크
  ///
  /// 반환값:
  /// - true: Android + QHD+ 해상도 → 경고 필요
  /// - false: iOS 또는 Android 저해상도 → 경고 불필요
  static bool shouldShowAndroidQHDWarning(BuildContext context) {
    try {
      // iOS는 해당 문제가 없으므로 경고 불필요
      if (Platform.isIOS) {
        if (kDebugMode) {
          debugPrint('[AndroidResolutionWarningService] iOS 기기 - 경고 생략');
        }
        return false;
      }

      // Android에서만 해상도 체크
      if (Platform.isAndroid) {
        // ⚠️ cleanup 금지: 테스트 모드 감지 로직
        // 테스트 모드가 활성화된 경우 강제로 경고 표시
        if (_testModeEnabled) {
          if (kDebugMode) {
            debugPrint(
                '[AndroidResolutionWarningService] 테스트 모드 활성화 - 강제로 QHD+ 경고 표시');
          }
          return true;
        }

        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        final pixelRatio = mediaQuery.devicePixelRatio;

        // 물리적 해상도 계산
        final physicalHeight = screenSize.height * pixelRatio;
        final physicalWidth = screenSize.width * pixelRatio;

        // QHD+ (1440 x 3120) 해상도 체크 - 가로 해상도 기준
        final isQHDPlus = physicalWidth >= qhdPlusWidthThreshold;

        if (kDebugMode) {
          debugPrint('[AndroidResolutionWarningService] Android 해상도 정보:');
          debugPrint(
              '  - 논리적 해상도: ${screenSize.width.toInt()} x ${screenSize.height.toInt()}');
          debugPrint(
              '  - 물리적 해상도: ${physicalWidth.toInt()} x ${physicalHeight.toInt()}');
          debugPrint('  - 픽셀 비율: ${pixelRatio}x');
          debugPrint('  - QHD+ 감지: $isQHDPlus');
          debugPrint('  - 테스트 모드: $_testModeEnabled');

          if (isQHDPlus) {
            debugPrint('  - 경고 필요: 차량위치 표시 문제 발생 가능');
          } else {
            debugPrint('  - 경고 불필요: 정상 해상도');
          }
        }

        return isQHDPlus;
      }

      // 기타 플랫폼은 경고 불필요
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AndroidResolutionWarningService] 해상도 체크 오류: $e');
      }
      return false;
    }
  }

  /// 현재 기기의 해상도 정보 조회 (디버깅용)
  static ResolutionInfo getCurrentResolution(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final pixelRatio = mediaQuery.devicePixelRatio;

    return ResolutionInfo(
      logicalWidth: screenSize.width,
      logicalHeight: screenSize.height,
      physicalWidth: screenSize.width * pixelRatio,
      physicalHeight: screenSize.height * pixelRatio,
      pixelRatio: pixelRatio,
      platform: Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
              ? 'iOS'
              : 'Unknown',
    );
  }

  /// 해상도 타입 판별 (가로 해상도 기준)
  static String getResolutionType(BuildContext context) {
    final resolution = getCurrentResolution(context);
    final width = resolution.physicalWidth;

    if (width >= 1440) {
      return 'QHD+ (${resolution.physicalWidth.toInt()} x ${resolution.physicalHeight.toInt()})';
    } else if (width >= 1080) {
      return 'FHD+ (${resolution.physicalWidth.toInt()} x ${resolution.physicalHeight.toInt()})';
    } else {
      return 'HD+ (${resolution.physicalWidth.toInt()} x ${resolution.physicalHeight.toInt()})';
    }
  }
}

/// 해상도 정보 모델
class ResolutionInfo {
  final double logicalWidth;
  final double logicalHeight;
  final double physicalWidth;
  final double physicalHeight;
  final double pixelRatio;
  final String platform;

  const ResolutionInfo({
    required this.logicalWidth,
    required this.logicalHeight,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.pixelRatio,
    required this.platform,
  });

  /// QHD+ 해상도 여부 (가로 해상도 기준)
  bool get isQHDPlus =>
      physicalWidth >= AndroidResolutionWarningService.qhdPlusWidthThreshold;

  /// 안전한 해상도 여부 (FHD+ 이하)
  bool get isSafeResolution =>
      physicalWidth < AndroidResolutionWarningService.qhdPlusWidthThreshold;

  @override
  String toString() {
    return 'ResolutionInfo('
        'platform: $platform, '
        'logical: ${logicalWidth.toInt()}x${logicalHeight.toInt()}, '
        'physical: ${physicalWidth.toInt()}x${physicalHeight.toInt()}, '
        'ratio: ${pixelRatio}x, '
        'isQHDPlus: $isQHDPlus'
        ')';
  }
}
