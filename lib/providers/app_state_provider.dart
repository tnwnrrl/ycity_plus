import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 전역 앱 상태 관리 Provider
class AppStateProvider extends ChangeNotifier {
  // SharedPreferences 키 상수들
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyIsFirstLaunch = 'app_is_first_launch';
  static const String _keyLastBackgroundTime = 'app_last_background_time';
  static const String _keyCurrentTabIndex = 'app_current_tab_index';
  static const String _keyLocale = 'app_locale';
  static const String _keyIsBottomNavVisible = 'app_is_bottom_nav_visible';
  static const String _keyAndroidResolutionWarningDismissed =
      'android_qhd_warning_dismissed';

  // 앱 상태 변수들
  bool _isAppInitialized = false;
  bool _isFirstLaunch = true;
  String? _initializationError;
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  // 네트워크 상태
  bool _isOnline = true;

  // UI 상태
  bool _isBottomNavigationVisible = true;
  int _currentTabIndex = 0;

  // 백그라운드 상태
  bool _isAppInBackground = false;
  DateTime? _lastBackgroundTime;

  // Android 해상도 경고 상태
  bool _androidResolutionWarningDismissed = false;

  // Getters
  bool get isAppInitialized => _isAppInitialized;
  bool get isFirstLaunch => _isFirstLaunch;
  String? get initializationError => _initializationError;
  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  bool get isOnline => _isOnline;
  bool get isBottomNavigationVisible => _isBottomNavigationVisible;
  int get currentTabIndex => _currentTabIndex;
  bool get isAppInBackground => _isAppInBackground;
  DateTime? get lastBackgroundTime => _lastBackgroundTime;
  bool get androidResolutionWarningDismissed =>
      _androidResolutionWarningDismissed;

  // 다크모드 여부
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Provider 초기화 (상태 복원 포함)
  Future<void> initialize() async {
    try {
      // 저장된 상태 복원
      await restoreState();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppStateProvider] 초기화 오류: $e');
      }
    }
  }

  /// 앱 초기화 상태 설정
  void setAppInitialized(bool initialized, {String? error}) {
    _isAppInitialized = initialized;
    _initializationError = error;

    if (initialized) {
      _isFirstLaunch = false;
    }

    notifyListeners();
    _autoSave();

    if (kDebugMode) {
      debugPrint(
          '[AppStateProvider] 앱 초기화 상태: $initialized ${error != null ? '(오류: $error)' : ''}');
    }
  }

  /// 첫 실행 상태 설정
  void setFirstLaunch(bool isFirst) {
    if (_isFirstLaunch != isFirst) {
      _isFirstLaunch = isFirst;
      notifyListeners();
      _autoSave();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 첫 실행 상태: $isFirst');
      }
    }
  }

  /// 테마 모드 변경
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      _autoSave();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 테마 모드 변경: $mode');
      }
    }
  }

  /// 다크모드 토글
  void toggleDarkMode() {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }

  /// 로케일 설정
  void setLocale(Locale? newLocale) {
    if (_locale != newLocale) {
      _locale = newLocale;
      notifyListeners();
      _autoSave();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 로케일 변경: $newLocale');
      }
    }
  }

  /// 네트워크 상태 설정
  void setNetworkStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 네트워크 상태: ${isOnline ? '온라인' : '오프라인'}');
      }
    }
  }

  /// 바텀 네비게이션 표시 상태 설정
  void setBottomNavigationVisible(bool visible) {
    if (_isBottomNavigationVisible != visible) {
      _isBottomNavigationVisible = visible;
      notifyListeners();
      _autoSave();
    }
  }

  /// 현재 탭 인덱스 설정
  void setCurrentTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
      _autoSave();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 현재 탭: $index');
      }
    }
  }

  /// 앱 백그라운드 상태 설정
  void setAppBackgroundStatus(bool isInBackground) {
    _isAppInBackground = isInBackground;

    if (isInBackground) {
      _lastBackgroundTime = DateTime.now();
    }

    notifyListeners();
    _autoSave();

    if (kDebugMode) {
      debugPrint('[AppStateProvider] 앱 백그라운드 상태: $isInBackground');
    }
  }

  /// Android 해상도 경고 해제 상태 설정
  void setAndroidResolutionWarningDismissed(bool dismissed) {
    if (_androidResolutionWarningDismissed != dismissed) {
      _androidResolutionWarningDismissed = dismissed;
      notifyListeners();
      _autoSave();

      if (kDebugMode) {
        debugPrint('[AppStateProvider] Android 해상도 경고 해제 상태: $dismissed');
      }
    }
  }

  /// 백그라운드에서 복귀한 시간 계산
  Duration? get timeInBackground {
    if (_lastBackgroundTime == null || _isAppInBackground) {
      return null;
    }

    return DateTime.now().difference(_lastBackgroundTime!);
  }

  /// 백그라운드에서 장시간 있었는지 확인
  bool get wasInBackgroundTooLong {
    final backgroundTime = timeInBackground;
    if (backgroundTime == null) return false;

    // 5분 이상 백그라운드에 있었으면 true
    return backgroundTime.inMinutes >= 5;
  }

  /// 앱 재시작 필요한지 확인
  bool get shouldRefreshOnForeground {
    return wasInBackgroundTooLong || !_isOnline;
  }

  /// 전역 상태 초기화
  void resetAppState() {
    _isAppInitialized = false;
    _isFirstLaunch = true;
    _initializationError = null;
    _currentTabIndex = 0;
    _isAppInBackground = false;
    _lastBackgroundTime = null;

    notifyListeners();

    if (kDebugMode) {
      debugPrint('[AppStateProvider] 앱 상태 초기화 완료');
    }
  }

  /// 디버그 정보 출력
  void printDebugInfo() {
    if (kDebugMode) {
      debugPrint('[AppStateProvider] === 앱 상태 정보 ===');
      debugPrint('  - 초기화됨: $_isAppInitialized');
      debugPrint('  - 첫 실행: $_isFirstLaunch');
      debugPrint('  - 테마 모드: $_themeMode');
      debugPrint('  - 온라인: $_isOnline');
      debugPrint('  - 현재 탭: $_currentTabIndex');
      debugPrint('  - 백그라운드: $_isAppInBackground');
      debugPrint('  - 마지막 백그라운드 시간: $_lastBackgroundTime');
      if (timeInBackground != null) {
        debugPrint('  - 백그라운드 시간: ${timeInBackground!.inMinutes}분');
      }
      debugPrint('=====================================');
    }
  }

  // ================================
  // State Persistence 기능 (Phase 2.2)
  // ================================

  /// 앱 상태를 SharedPreferences에 저장
  Future<void> persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 테마 모드 저장
      await prefs.setString(_keyThemeMode, _themeMode.toString());

      // 첫 실행 여부 저장
      await prefs.setBool(_keyIsFirstLaunch, _isFirstLaunch);

      // 현재 탭 인덱스 저장
      await prefs.setInt(_keyCurrentTabIndex, _currentTabIndex);

      // 바텀 네비게이션 표시 상태 저장
      await prefs.setBool(_keyIsBottomNavVisible, _isBottomNavigationVisible);

      // 마지막 백그라운드 시간 저장
      if (_lastBackgroundTime != null) {
        await prefs.setString(
            _keyLastBackgroundTime, _lastBackgroundTime!.toIso8601String());
      }

      // Android 해상도 경고 해제 상태 저장
      await prefs.setBool(_keyAndroidResolutionWarningDismissed,
          _androidResolutionWarningDismissed);

      // 로케일 저장 (있는 경우)
      if (_locale != null) {
        await prefs.setString(_keyLocale, _locale!.toString());
      }

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 앱 상태 저장 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppStateProvider] 앱 상태 저장 오류: $e');
      }
    }
  }

  /// SharedPreferences에서 앱 상태 복원
  Future<void> restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 테마 모드 복원
      final themeModeString = prefs.getString(_keyThemeMode);
      if (themeModeString != null) {
        switch (themeModeString) {
          case 'ThemeMode.light':
            _themeMode = ThemeMode.light;
            break;
          case 'ThemeMode.dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'ThemeMode.system':
          default:
            _themeMode = ThemeMode.system;
            break;
        }
      }

      // 첫 실행 여부 복원
      _isFirstLaunch = prefs.getBool(_keyIsFirstLaunch) ?? true;

      // 현재 탭 인덱스 복원
      _currentTabIndex = prefs.getInt(_keyCurrentTabIndex) ?? 0;

      // 바텀 네비게이션 표시 상태 복원
      _isBottomNavigationVisible =
          prefs.getBool(_keyIsBottomNavVisible) ?? true;

      // Android 해상도 경고 해제 상태 복원
      _androidResolutionWarningDismissed =
          prefs.getBool(_keyAndroidResolutionWarningDismissed) ?? false;

      // 마지막 백그라운드 시간 복원
      final lastBackgroundTimeString = prefs.getString(_keyLastBackgroundTime);
      if (lastBackgroundTimeString != null) {
        try {
          _lastBackgroundTime = DateTime.parse(lastBackgroundTimeString);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AppStateProvider] 백그라운드 시간 파싱 오류: $e');
          }
          _lastBackgroundTime = null;
        }
      }

      // 로케일 복원
      final localeString = prefs.getString(_keyLocale);
      if (localeString != null && localeString.isNotEmpty) {
        try {
          final parts = localeString.split('_');
          if (parts.length >= 2) {
            _locale = Locale(parts[0], parts[1]);
          } else if (parts.length == 1) {
            _locale = Locale(parts[0]);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AppStateProvider] 로케일 파싱 오류: $e');
          }
          _locale = null;
        }
      }

      if (kDebugMode) {
        debugPrint('[AppStateProvider] 앱 상태 복원 완료');
        debugPrint('  - 복원된 테마 모드: $_themeMode');
        debugPrint('  - 복원된 첫 실행 여부: $_isFirstLaunch');
        debugPrint('  - 복원된 현재 탭: $_currentTabIndex');
        debugPrint('  - 복원된 바텀 네비게이션: $_isBottomNavigationVisible');
      }

      // 상태 변경 알림
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppStateProvider] 앱 상태 복원 오류: $e');
      }
    }
  }

  /// 앱 상태 변경 시 자동 저장 (모든 setter에서 호출)
  Future<void> _autoSave() async {
    // 백그라운드에서 자동 저장하여 UI 블로킹 방지
    Future.microtask(() => persistState());
  }
}
