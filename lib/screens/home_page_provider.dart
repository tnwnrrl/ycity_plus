import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import 'dart:io';

import '../providers/app_state_provider.dart';
import '../providers/user_info_provider.dart';
import '../providers/vehicle_location_provider.dart';
import '../providers/parking_history_provider.dart';
import '../models/parking_floor_info.dart';
import '../screens/vehicle_location_screen.dart';
import '../screens/parking_history_screen.dart';
import '../services/home_widget_service.dart';
import '../services/android_resolution_warning_service.dart';

/// Provider 패턴을 사용하는 새로운 HomePage
class HomePageProvider extends StatefulWidget {
  const HomePageProvider({super.key});

  @override
  State<HomePageProvider> createState() => _HomePageProviderState();
}

class _HomePageProviderState extends State<HomePageProvider> with WidgetsBindingObserver {
  // 상수 정의
  static const Duration _uiInitializationDelay = Duration(milliseconds: 1000);
  static const Duration _navigationDelay = Duration(milliseconds: 200);
  static const int _recentLaunchThresholdMs = 10000; // 10초
  // Constants
  static const Duration _locationUpdateInterval = Duration(minutes: 3);
  static const Duration _backgroundUpdateInterval = Duration(minutes: 10); // 백그라운드에서는 더 느리게
  static const String _saveSuccessMessage = '정보가 성공적으로 저장되었습니다';
  static const String _saveFailureMessage = '정보 저장에 실패했습니다';
  static const String _selectDongMessage = '동을 선택해주세요';
  static const String _noVehicleInfoMessage = '등록된 차량 정보가 없습니다';

  final _formKey = GlobalKey<FormState>();

  // 컨트롤러들
  final TextEditingController _hoController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();

  // 선택된 동
  String? _selectedDong;

  // 타이머 (자동 업데이트용)
  Timer? _locationUpdateTimer;

  // 위젯 클릭 이벤트 구독
  StreamSubscription<String>? _widgetClickSubscription;

  // 앱 버전 정보
  String _appVersion = '';
  
  // 앱 상태 추적
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    
    // 앱 라이프사이클 감지기 등록
    WidgetsBinding.instance.addObserver(this);

    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
      _loadAppVersion();
    });

    // 홈위젯 클릭 이벤트 리스너 설정
    _setupWidgetClickListener();
  }

  @override
  void dispose() {
    _hoController.dispose();
    _serialNumberController.dispose();
    _locationUpdateTimer?.cancel();
    _widgetClickSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // 앱이 백그라운드로 이동
        _isInBackground = true;
        _adjustUpdateInterval();
        break;
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 복귀
        _isInBackground = false;
        _adjustUpdateInterval();
        // 포그라운드 복귀 시 즉시 한 번 업데이트
        _refreshLocationInfo();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// 앱 초기화 (상태 복원 포함)
  Future<void> _initializeApp() async {
    final appStateProvider = context.read<AppStateProvider>();
    final userInfoProvider = context.read<UserInfoProvider>();

    // AppStateProvider 초기화 및 상태 복원
    await appStateProvider.initialize();
    appStateProvider.setAppInitialized(true);

    // UserInfoProvider 초기화 - 이전 사용자 정보 로드
    await userInfoProvider.initialize();

    // 사용자 정보 및 차량 위치 로드
    _loadUserInfoFromProvider();
    _startLocationUpdates();

    // 위젯 클릭으로 앱이 시작되었는지 확인 (지연 실행으로 UI 준비 후)
    _checkInitialWidgetLaunch();
  }

  /// 위젯 클릭으로 앱이 시작되었는지 확인하고 위치확인 화면으로 이동
  void _checkInitialWidgetLaunch() {
    // UI가 완전히 초기화된 후 실행
    Future.delayed(_uiInitializationDelay, () async {
      if (!mounted) return;

      try {
        // SharedPreferences에서 위젯 클릭 플래그 확인
        final prefs = await SharedPreferences.getInstance();
        final widgetLaunched = prefs.getBool('widget_launched_app') ?? false;
        final launchTime = prefs.getInt('widget_launch_time') ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        // 10초 이내에 위젯으로 앱이 시작되었는지 확인 (너무 오래된 플래그는 무시)
        final isRecentLaunch = (currentTime - launchTime) < _recentLaunchThresholdMs;

        if (kDebugMode) {
          debugPrint(
              '[HomePageProvider] 위젯 시작 플래그 확인: $widgetLaunched, 최근 실행: $isRecentLaunch');
        }

        if (widgetLaunched && isRecentLaunch) {
          if (kDebugMode) {
            debugPrint('[HomePageProvider] ✅ 위젯 클릭으로 앱 시작됨 - 위치확인 화면 자동 이동');
          }

          // 플래그 초기화 (한 번만 실행되도록)
          await prefs.remove('widget_launched_app');
          await prefs.remove('widget_launch_time');

          // 위치확인 화면으로 자동 이동
          _navigateToVehicleLocation();
        } else {
          if (kDebugMode) {
            debugPrint('[HomePageProvider] 일반 앱 시작 - 위치확인 화면 자동 이동 안 함');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[HomePageProvider] 위젯 시작 확인 중 오류: $e');
        }
      }
    });
  }

  /// 홈위젯 클릭 이벤트 리스너 설정
  void _setupWidgetClickListener() {
    _widgetClickSubscription =
        HomeWidgetService.widgetClickStream.listen((action) {
      if (kDebugMode) {
        debugPrint('[HomePageProvider] 위젯 클릭 이벤트 수신: $action');
      }

      // 위치확인 화면으로 이동
      if (action == 'vehicle_location' && mounted) {
        // 약간의 지연을 두어 안정적으로 네비게이션 처리
        Future.delayed(_navigationDelay, () {
          if (mounted) {
            _navigateToVehicleLocation();
          }
        });
      }
    });
  }

  /// 위치확인 화면으로 네비게이션
  Future<void> _navigateToVehicleLocation() async {
    try {
      if (kDebugMode) {
        debugPrint('[HomePageProvider] 위치확인 화면 네비게이션 시작');
      }

      final userInfoProvider = context.read<UserInfoProvider>();

      if (kDebugMode) {
        debugPrint(
            '[HomePageProvider] UserInfoProvider 상태: hasCurrentUser=${userInfoProvider.hasCurrentUser}');
      }

      if (!userInfoProvider.hasCurrentUser) {
        if (kDebugMode) {
          debugPrint('[HomePageProvider] ❌ 사용자 정보가 없어 위치확인 화면으로 이동할 수 없음');
        }

        // 사용자 정보가 없으면 스낵바로 알림
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 먼저 등록해주세요'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final currentUser = userInfoProvider.currentUser!;

      if (kDebugMode) {
        debugPrint(
            '[HomePageProvider] ✅ 사용자 정보 확인: ${currentUser.dong}동 ${currentUser.ho}호');
        debugPrint('[HomePageProvider] mounted 상태: $mounted');
      }

      // 위치확인 화면으로 네비게이션
      if (mounted) {
        if (kDebugMode) {
          debugPrint('[HomePageProvider] 🚀 위치확인 화면으로 네비게이션 실행');
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleLocationScreen(
              dong: currentUser.dong,
              ho: currentUser.ho,
              serialNumber: currentUser.serialNumber,
            ),
          ),
        );

        if (kDebugMode) {
          debugPrint('[HomePageProvider] ✅ 위치확인 화면 네비게이션 완료');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[HomePageProvider] ❌ mounted가 false라서 네비게이션 취소됨');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomePageProvider] ❌ 위치확인 화면 이동 중 오류: $e');
        debugPrint('[HomePageProvider] 오류 스택 트레이스: ${e.toString()}');
      }
    }
  }

  /// Provider에서 사용자 정보 로드
  Future<void> _loadUserInfoFromProvider() async {
    final userInfoProvider = context.read<UserInfoProvider>();

    if (userInfoProvider.hasCurrentUser) {
      final currentUser = userInfoProvider.currentUser!;

      // 동 번호가 "103"이면 "103동"으로 표시하기 위해 변환
      String displayDong = currentUser.dong;
      if (!displayDong.endsWith('동') && displayDong.isNotEmpty) {
        displayDong = '$displayDong동';
      }

      if (mounted) {
        setState(() {
          _selectedDong = displayDong;
          _hoController.text = currentUser.ho;
          _serialNumberController.text = currentUser.serialNumber;
        });
      }

      // 주차 이력을 먼저 로드하여 마지막 주차 층 정보를 확인
      if (mounted) {
        final parkingHistoryProvider = context.read<ParkingHistoryProvider>();
        await parkingHistoryProvider.loadParkingHistory(currentUser);

        // 마지막 주차 층 정보가 있으면 먼저 표시
        final lastParkedFloor = parkingHistoryProvider.getLastParkedFloor();
        if (lastParkedFloor != null && mounted) {
          final vehicleLocationProvider =
              context.read<VehicleLocationProvider>();

          // 마지막 주차 층으로 임시 표시
          final tempFloorInfo = ParkingFloorInfo(
            dong: currentUser.dong,
            ho: currentUser.ho,
            serialNumber: currentUser.serialNumber,
            floor: lastParkedFloor,
            lastUpdated: DateTime.now(),
            isDefault: true, // 임시 데이터임을 표시
          );

          vehicleLocationProvider.setTemporaryFloorInfo(tempFloorInfo);

          if (kDebugMode) {
            debugPrint('[HomePageProvider] 마지막 주차 층 임시 표시: $lastParkedFloor');
          }
        }

        // 차량 위치 정보 로드 (다중 차량 지원)
        if (mounted) {
          final vehicleLocationProvider =
              context.read<VehicleLocationProvider>();
          // 다중 차량 API를 먼저 시도
          await vehicleLocationProvider.fetchMultipleVehicleLocation(
              userInfo: currentUser);
          
          // 단일 차량 호환성을 위해 기존 API도 호출 (다중 차량이 없는 경우)
          if (!vehicleLocationProvider.hasMultipleVehicles) {
            vehicleLocationProvider.fetchWithCacheOptimistic(
                userInfo: currentUser);
          }
        }

        if (kDebugMode) {
          debugPrint(
              '[HomePageProvider] Provider에서 사용자 정보 로드 완료: ${currentUser.toString()}');
        }
      }
    }
  }

  /// 앱 상태에 따라 업데이트 주기 조정
  void _adjustUpdateInterval() {
    _locationUpdateTimer?.cancel();
    
    final interval = _isInBackground ? _backgroundUpdateInterval : _locationUpdateInterval;
    _startLocationUpdatesWithInterval(interval);
  }
  
  /// 차량 위치 자동 업데이트 시작
  void _startLocationUpdates() {
    _startLocationUpdatesWithInterval(_locationUpdateInterval);
  }
  
  /// 지정된 주기로 자동 업데이트 시작
  void _startLocationUpdatesWithInterval(Duration interval) {
    _locationUpdateTimer?.cancel();

    _locationUpdateTimer = Timer.periodic(interval, (_) {
      final userInfoProvider = context.read<UserInfoProvider>();

      if (userInfoProvider.hasCurrentUser) {
        final vehicleLocationProvider = context.read<VehicleLocationProvider>();
        
        // 비동기 작업을 Future.microtask로 처리
        Future.microtask(() async {
          // 다중 차량 API를 우선 사용 (자동 업데이트)
          await vehicleLocationProvider.fetchMultipleVehicleLocation(
            userInfo: userInfoProvider.currentUser!,
          );
          
          // 단일 차량 호환성
          if (!vehicleLocationProvider.hasMultipleVehicles) {
            vehicleLocationProvider.fetchWithCacheOptimistic(
              userInfo: userInfoProvider.currentUser!,
            );
          }
        });

        if (kDebugMode) {
          debugPrint('[HomePageProvider] 자동 위치 업데이트 실행');
        }
      }
    });
  }

  /// 사용자 정보 저장
  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDong == null) {
      _showSnackBar(_selectDongMessage);
      return;
    }

    final userInfoProvider = context.read<UserInfoProvider>();

    // 동 번호에서 "동" 제거 (예: "103동" → "103")
    String dongNumber = _selectedDong!;
    if (dongNumber.endsWith('동')) {
      dongNumber = dongNumber.substring(0, dongNumber.length - 1).trim();
    }

    try {
      bool success;

      if (userInfoProvider.hasCurrentUser) {
        // 기존 사용자 정보 업데이트
        success = await userInfoProvider.updateUser(
          id: userInfoProvider.currentUser!.id!,
          dong: dongNumber,
          ho: _hoController.text.trim(),
          serialNumber: _serialNumberController.text.trim(),
        );
      } else {
        // 새 사용자 추가
        success = await userInfoProvider.addUser(
          dong: dongNumber,
          ho: _hoController.text.trim(),
          serialNumber: _serialNumberController.text.trim(),
        );
      }

      if (success) {
        _showSnackBar(_saveSuccessMessage);

        // 저장 후 차량 위치 정보 즉시 업데이트 (다중 차량 지원)
        if (mounted && userInfoProvider.hasCurrentUser) {
          final vehicleLocationProvider =
              context.read<VehicleLocationProvider>();
          // 다중 차량 API를 우선 사용
          await vehicleLocationProvider.fetchMultipleVehicleLocation(
            userInfo: userInfoProvider.currentUser!,
            forceRefresh: true,
          );
          
          // 단일 차량 호환성
          if (!vehicleLocationProvider.hasMultipleVehicles) {
            vehicleLocationProvider.fetchWithCacheOptimistic(
              userInfo: userInfoProvider.currentUser!,
              forceRefresh: true,
            );
          }

          // 주차 이력도 새로고침
          if (mounted) {
            final parkingHistoryProvider = context.read<ParkingHistoryProvider>();
            parkingHistoryProvider
                .loadParkingHistory(userInfoProvider.currentUser!);
          }
        }
      } else {
        final error = userInfoProvider.error ?? _saveFailureMessage;
        _showSnackBar(error);
      }
    } catch (e) {
      _showSnackBar('$_saveFailureMessage: $e');

      if (kDebugMode) {
        debugPrint('[HomePageProvider] 사용자 정보 저장 오류: $e');
      }
    }
  }

  /// 차량 위치 새로고침 (Phase 2.3: Optimistic Updates 적용)
  Future<void> _refreshLocationInfo() async {
    final userInfoProvider = context.read<UserInfoProvider>();

    if (!userInfoProvider.hasCurrentUser) {
      _showSnackBar(_noVehicleInfoMessage);
      return;
    }

    if (!mounted) return;
    final vehicleLocationProvider = context.read<VehicleLocationProvider>();

    // 다중 차량 API를 우선 사용하고 단일 차량으로 폴백
    await vehicleLocationProvider.fetchMultipleVehicleLocation(
      userInfo: userInfoProvider.currentUser!,
      forceRefresh: true,
    );

    if (!mounted) return;
    // 다중 차량이 감지되지 않으면 기존 단일 차량 API도 시도 (호환성)
    if (!vehicleLocationProvider.hasMultipleVehicles) {
      await vehicleLocationProvider.fetchWithCacheOptimistic(
        userInfo: userInfoProvider.currentUser!,
        forceRefresh: true,
      );
    }

    if (!mounted) return;
    if (vehicleLocationProvider.locationError != null) {
      _showSnackBar(vehicleLocationProvider.locationError!.userMessage);
    } else if (vehicleLocationProvider.hasMultipleVehicles) {
      _showSnackBar('${vehicleLocationProvider.vehicleCount}개 차량이 발견되었습니다');
    }

    // 위젯 강제 업데이트 (앱 포그라운드 진입 시 및 수동 새로고침 시)
    try {
      await HomeWidgetService.forceUpdateWidgetOnAppResume();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomePageProvider] 위젯 강제 업데이트 실패: $e');
      }
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// 시리얼 번호 도움말 다이얼로그 표시
  void _showSerialNumberHelp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: const Color(0xFF6366F1),
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              '시리얼 번호란?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '시리얼 번호는 주차태그 기기마다 부여되는 고유 식별번호입니다.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.monitor,
                        color: const Color(0xFF6366F1),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '월패드에서 확인',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '월패드 → 조회 → 주차위치 로 이동하여\n자동차 그림 밑에 있는 시리얼 넘버를 입력 하세요',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_outlined,
                              color: Colors.amber.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '주의사항',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '주차태그 기기를 반드시 차량 안에 비치해야 합니다.\n분실했거나 충전이 되지 않을경우 생활지원센터에 문의 해 주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '확인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 32),
                _buildUserInfoForm(isDark),
                const SizedBox(height: 32),
                _buildCurrentLocationCard(isDark),
                const SizedBox(height: 24),
                _buildActionButtons(isDark),
                const SizedBox(height: 32),
                _buildVersionInfo(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 헤더 위젯
  Widget _buildHeader(bool isDark) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YCITY+',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '차량 위치 확인',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // ⚠️ cleanup 금지: QHD+ 해상도 테스트 모드 버튼 (개발용)
                // 낮은 해상도 기기에서 QHD+ 경고를 테스트하기 위한 중요한 개발 도구
                // 기본값: 숨김 (필요시 false로 변경하여 활성화)
                if (Platform.isAndroid && kDebugMode && false)
                  // ignore: dead_code
                  IconButton(
                    onPressed: () {
                      // ⚠️ cleanup 금지: 테스트 모드 토글 로직
                      // 테스트 모드 토글
                      final currentTestMode =
                          AndroidResolutionWarningService.isTestModeEnabled;
                      AndroidResolutionWarningService.setTestMode(
                          !currentTestMode);

                      // 상태 알림
                      _showSnackBar(!currentTestMode
                          ? 'QHD+ 해상도 테스트 모드 활성화'
                          : 'QHD+ 해상도 테스트 모드 비활성화');

                      // 상태 변경으로 UI 새로고침
                      setState(() {});
                    },
                    icon: Icon(
                      AndroidResolutionWarningService.isTestModeEnabled
                          ? Icons.bug_report
                          : Icons.bug_report_outlined,
                      size: 26,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AndroidResolutionWarningService.isTestModeEnabled
                              ? Colors.orange.withValues(alpha: 0.2)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1)),
                      foregroundColor: AndroidResolutionWarningService
                              .isTestModeEnabled
                          ? Colors.orange
                          : (isDark ? Colors.white70 : Colors.grey.shade600),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: AndroidResolutionWarningService.isTestModeEnabled
                        ? 'QHD+ 테스트 모드 OFF'
                        : 'QHD+ 테스트 모드 ON',
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showSettingsDialog(context, isDark),
                  icon: Icon(
                    Icons.settings,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                  tooltip: '설정',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: appState.toggleDarkMode,
                  icon: Icon(
                    appState.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 사용자 정보 입력 폼
  Widget _buildUserInfoForm(bool isDark) {
    return Consumer<UserInfoProvider>(
      builder: (context, userInfoProvider, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '차량 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 20),

                // 동 선택
                _buildDongDropdown(isDark),
                const SizedBox(height: 16),

                // 호수 입력
                _buildHoField(isDark),
                const SizedBox(height: 16),

                // 시리얼 번호 입력
                _buildSerialNumberField(isDark),
                const SizedBox(height: 24),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        userInfoProvider.isLoading ? null : _saveUserInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: userInfoProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '저장하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 동 선택 드롭다운
  Widget _buildDongDropdown(bool isDark) {
    const dongs = ['101동', '102동', '103동', '104동', '105동', '106동'];

    return DropdownButtonFormField<String>(
      initialValue: _selectedDong,
      decoration: InputDecoration(
        labelText: '동',
        filled: true,
        fillColor: isDark
            ? const Color(0xFF334155).withValues(alpha: 0.3)
            : Colors.grey.shade50,
      ),
      items: dongs
          .map((dong) => DropdownMenuItem(
                value: dong,
                child: Text(dong),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedDong = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '동을 선택해주세요';
        }
        return null;
      },
    );
  }

  /// 호수 입력 필드
  Widget _buildHoField(bool isDark) {
    return TextFormField(
      controller: _hoController,
      decoration: InputDecoration(
        labelText: '호',
        hintText: '예: 1234',
        filled: true,
        fillColor: isDark
            ? const Color(0xFF334155).withValues(alpha: 0.3)
            : Colors.grey.shade50,
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '호수를 입력해주세요';
        }
        if (value.length < 3 || value.length > 4) {
          return '올바른 호수를 입력해주세요';
        }
        return null;
      },
    );
  }

  /// 시리얼 번호 입력 필드
  Widget _buildSerialNumberField(bool isDark) {
    return TextFormField(
      controller: _serialNumberController,
      decoration: InputDecoration(
        labelText: '시리얼 번호',
        hintText: '예: a001234',
        filled: true,
        fillColor: isDark
            ? const Color(0xFF334155).withValues(alpha: 0.3)
            : Colors.grey.shade50,
        suffixIcon: IconButton(
          onPressed: () => _showSerialNumberHelp(),
          icon: Icon(
            Icons.help_outline,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.grey.shade600,
            size: 20,
          ),
          tooltip: '시리얼 번호 도움말',
        ),
      ),
      keyboardType: TextInputType.text,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '시리얼 번호를 입력해주세요';
        }
        if (value.length < 4) {
          return '시리얼 번호는 4자 이상 입력해주세요';
        }
        // 영어, 숫자만 허용하는 정규식 검증
        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
          return '시리얼 번호는 영어와 숫자만 입력 가능합니다';
        }
        return null;
      },
    );
  }

  /// 현재 차량 위치 카드
  Widget _buildCurrentLocationCard(bool isDark) {
    return Consumer<VehicleLocationProvider>(
      builder: (context, vehicleProvider, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '현재 차량 위치',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  if (vehicleProvider.isLocationLoading)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      onPressed: _refreshLocationInfo,
                      icon: const Icon(Icons.refresh),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF6366F1).withValues(alpha: 0.1),
                        foregroundColor: const Color(0xFF6366F1),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // 다중 차량 선택 UI (2개 이상일 때만 표시) - 방어적 조건 검사
              if (vehicleProvider.hasMultipleVehicles && 
                  vehicleProvider.isMultipleVehicleMode &&
                  vehicleProvider.multipleFloorInfoList != null &&
                  vehicleProvider.multipleFloorInfoList!.length > 1)
                _buildVehicleSelector(vehicleProvider, isDark),
              if (vehicleProvider.hasMultipleVehicles && 
                  vehicleProvider.isMultipleVehicleMode &&
                  vehicleProvider.multipleFloorInfoList != null &&
                  vehicleProvider.multipleFloorInfoList!.length > 1) 
                const SizedBox(height: 20),
              if (vehicleProvider.locationError != null)
                _buildErrorState(
                    vehicleProvider.locationError!.userMessage, isDark)
              else if (vehicleProvider.currentFloorInfo != null)
                _buildLocationInfo(vehicleProvider.currentFloorInfo!, isDark,
                    vehicleProvider.isOptimisticUpdate)
              else
                _buildEmptyLocationState(isDark),
              if (vehicleProvider.lastUpdated != null) ...[
                const SizedBox(height: 12),
                Text(
                  '마지막 업데이트: ${_formatUpdateTime(vehicleProvider.lastUpdated!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 다중 차량 선택 UI 위젯
  Widget _buildVehicleSelector(VehicleLocationProvider vehicleProvider, bool isDark) {
    final vehicleList = vehicleProvider.multipleFloorInfoList ?? [];
    final selectedIndex = vehicleProvider.selectedVehicleIndex;
    
    // 방어적 조건 검사: 다중 차량 상태가 아니거나 차량이 1개 이하인 경우 빈 위젯 반환
    if (!vehicleProvider.isMultipleVehicleMode || vehicleList.length <= 1) {
      if (kDebugMode) {
        debugPrint('[HomePageProvider] 차량 선택기 조건 불충족: isMultiple=${vehicleProvider.isMultipleVehicleMode}, count=${vehicleList.length}');
      }
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '차량 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark 
                ? Colors.white.withValues(alpha: 0.8) 
                : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: vehicleList.length,
            itemBuilder: (context, index) {
              final vehicle = vehicleList[index];
              final vehicleIndex = index + 1; // 1-based indexing
              final isSelected = vehicleIndex == selectedIndex;
              final floorColor = _getFloorColor(vehicle.floor);
              
              return Padding(
                padding: EdgeInsets.only(right: index < vehicleList.length - 1 ? 12 : 0),
                child: GestureDetector(
                  onTap: () {
                    vehicleProvider.selectVehicle(vehicleIndex);
                    if (kDebugMode) {
                      debugPrint('[HomePageProvider] 차량 선택: ${vehicle.displayName}');
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? floorColor.withValues(alpha: 0.15)
                          : (isDark 
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: floorColor.withValues(alpha: 0.6),
                              width: 2,
                            )
                          : Border.all(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.1) 
                                  : Colors.grey.withValues(alpha: 0.2),
                              width: 1,
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 차량 아이콘
                        Icon(
                          Icons.directions_car,
                          size: 18,
                          color: isSelected
                              ? floorColor
                              : (isDark 
                                  ? Colors.white.withValues(alpha: 0.7) 
                                  : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 6),
                        // 차량 이름
                        Text(
                          vehicle.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF1F2937))
                                : (isDark 
                                    ? Colors.white.withValues(alpha: 0.8) 
                                    : Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 층 정보
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? floorColor.withValues(alpha: 0.2)
                                : (isDark 
                                    ? Colors.white.withValues(alpha: 0.1) 
                                    : Colors.grey.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            vehicle.floor == '출차됨' ? '출차' : vehicle.floor,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? floorColor
                                  : (isDark 
                                      ? Colors.white.withValues(alpha: 0.7) 
                                      : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 위치 정보 표시 (Phase 2.3: Optimistic Update 표시 추가)
  Widget _buildLocationInfo(
      ParkingFloorInfo floorInfo, bool isDark, bool isOptimistic) {
    final isParked = floorInfo.floor != '출차됨' && floorInfo.floor.isNotEmpty;
    final floorColor = _getFloorColor(floorInfo.floor);

    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: floorColor.withValues(alpha: isOptimistic ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(16),
                // Phase 2.3: Optimistic Update 시 점선 테두리 표시
                border: isOptimistic
                    ? Border.all(
                        color: floorColor.withValues(alpha: 0.5),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  isParked ? floorInfo.floor : '🚗',
                  style: TextStyle(
                    fontSize: isParked ? 16 : 24,
                    fontWeight: FontWeight.w700,
                    color: floorColor,
                  ),
                ),
              ),
            ),
            // Phase 2.3: Optimistic Update 상태 표시
            if (isOptimistic)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.sync,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isParked ? '${floorInfo.floor}층에 주차됨' : '출차 완료',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  // Phase 2.3: Optimistic Update 텍스트 표시
                  if (isOptimistic) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '업데이트 중',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isParked
                      ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isParked ? '주차 중' : '출차됨',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isParked
                        ? const Color(0xFF6366F1)
                        : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 에러 상태 표시
  Widget _buildErrorState(String errorMessage, bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.red, size: 32),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '정보를 불러올 수 없음',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 빈 위치 상태 표시
  Widget _buildEmptyLocationState(bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.help_outline, color: Colors.grey, size: 32),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '위치 정보 없음',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '차량 정보를 저장한 후 위치를 확인하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 액션 버튼들
  Widget _buildActionButtons(bool isDark) {
    return Consumer<UserInfoProvider>(
      builder: (context, userInfoProvider, child) {
        final hasUserInfo = userInfoProvider.hasCurrentUser;

        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasUserInfo
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => VehicleLocationScreen(
                              dong: userInfoProvider.currentUser!.dong,
                              ho: userInfoProvider.currentUser!.ho,
                              serialNumber:
                                  userInfoProvider.currentUser!.serialNumber,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.location_on),
                label: const Text('위치 확인'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasUserInfo
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ParkingHistoryScreen(
                              dong: userInfoProvider.currentUser!.dong,
                              ho: userInfoProvider.currentUser!.ho,
                              serialNumber:
                                  userInfoProvider.currentUser!.serialNumber,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.history),
                label: const Text('주차 이력'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? const Color(0xFF334155) : Colors.grey.shade100,
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF1F2937),
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }



  /// 층 색상 가져오기
  Color _getFloorColor(String floor) {
    switch (floor.toUpperCase()) {
      case 'B1':
        return const Color(0xFF6366F1);
      case 'B2':
        return const Color(0xFF8B5CF6);
      case 'B3':
        return const Color(0xFFF59E0B);
      case 'B4':
        return const Color(0xFFEC4899);
      case '출차됨':
        return Colors.grey.shade500;
      default:
        return const Color(0xFF6366F1);
    }
  }

  /// 업데이트 시간 포맷
  String _formatUpdateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 앱 버전 정보 로드
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      debugPrint('[HomePageProvider] 버전 정보 로드 실패: $e');
    }
  }

  /// 버전 정보 표시
  Widget _buildVersionInfo(bool isDark) {
    if (_appVersion.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Text(
        _appVersion,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.grey.shade500,
        ),
      ),
    );
  }

  /// 설정 다이얼로그 표시
  void _showSettingsDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(
                '설정',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '위젯 설정',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<bool>(
                    future: HomeWidgetService.getWidgetAutoRefreshSetting(),
                    builder: (context, snapshot) {
                      final isEnabled = snapshot.data ?? true;
                      
                      return SwitchListTile(
                        title: Text(
                          '위젯 자동 새로고침',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          isEnabled 
                            ? '위젯이 백그라운드에서 자동으로 새로고침됩니다 (iOS: 15분, Android: 15분)'
                            : '위젯 자동 새로고침이 비활성화됩니다',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        value: isEnabled,
                        onChanged: (bool value) {
                          HomeWidgetService.saveWidgetAutoRefreshSetting(value);
                          setDialogState(() {}); // 다이얼로그 UI 업데이트
                          
                          // 설정 변경 알림
                          _showSnackBar(value 
                            ? '위젯 자동 새로고침이 활성화되었습니다'
                            : '위젯 자동 새로고침이 비활성화되었습니다');
                          
                          // Android의 경우 WorkManager 백그라운드 작업 제어
                          if (Platform.isAndroid) {
                            final userProvider = context.read<UserInfoProvider>();
                            final currentUser = userProvider.currentUser;
                            
                            if (currentUser != null) {
                              if (value) {
                                // 백그라운드 업데이트 시작
                                HomeWidgetService.startPeriodicBackgroundUpdates(
                                  currentUser.dong,
                                  currentUser.ho,
                                  currentUser.serialNumber,
                                );
                              } else {
                                // 백그라운드 업데이트 중지
                                HomeWidgetService.stopPeriodicBackgroundUpdates();
                              }
                            }
                          }
                        },
                        activeThumbColor: Theme.of(context).primaryColor,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ℹ️ 위젯 자동 새로고침을 비활성화하면 위젯은 앱을 열었을 때만 업데이트됩니다.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  // iOS에서 위젯 디버그 버튼 표시 (Release 모드에서도 테스트 가능)
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      '🔧 디버그',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showWidgetDebugInfo(context, isDark),
                      icon: const Icon(Icons.bug_report, size: 18),
                      label: const Text('위젯 디버그 정보'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await HomeWidgetService.forceRefreshIOSWidget();
                        if (mounted) {
                          _showSnackBar('iOS 위젯 새로고침 요청 완료');
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('위젯 강제 새로고침'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '닫기',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }

  // iOS 위젯 디버그 정보 표시 다이얼로그
  Future<void> _showWidgetDebugInfo(BuildContext parentContext, bool isDark) async {
    // 디버그 정보 조회 (로딩 다이얼로그 없이 진행)
    final debugInfo = await HomeWidgetService.getWidgetDebugInfo();

    if (!mounted) return;

    // 디버그 정보 표시
    showDialog(
      // ignore: use_build_context_synchronously
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Text(
              '위젯 디버그 정보',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Group 상태 표시 (가장 먼저)
              _buildDebugSection(isDark, '🔧 App Group 상태', [
                'App Group: ${debugInfo['_app_group_status'] ?? 'N/A'}',
                if (debugInfo['user_dong_error'] != null)
                  '⚠️ user_dong 에러: ${debugInfo['user_dong_error']}',
              ]),
              const SizedBox(height: 16),
              _buildDebugSection(isDark, '사용자 정보', [
                '동: ${debugInfo['user_dong']?.toString().isNotEmpty == true ? debugInfo['user_dong'] : 'N/A'}',
                '호: ${debugInfo['user_ho']?.toString().isNotEmpty == true ? debugInfo['user_ho'] : 'N/A'}',
                '시리얼: ${(debugInfo['user_serial_number'] as String?)?.isNotEmpty == true ? '***' : 'N/A'}',
              ]),
              const SizedBox(height: 16),
              _buildDebugSection(isDark, '위젯 데이터', [
                '층 정보: ${debugInfo['floor_info']?.toString().isNotEmpty == true ? debugInfo['floor_info'] : 'N/A'}',
                '색상 키: ${debugInfo['floor_color']?.toString().isNotEmpty == true ? debugInfo['floor_color'] : 'N/A'}',
                '상태 텍스트: ${debugInfo['status_text']?.toString().isNotEmpty == true ? debugInfo['status_text'] : 'N/A'}',
              ]),
              const SizedBox(height: 16),
              _buildDebugSection(isDark, '마지막 업데이트', [
                '시간: ${debugInfo['last_update_time'] ?? 'N/A'}',
                '경과: ${debugInfo['last_update_ago'] ?? 'N/A'}',
              ]),
              const SizedBox(height: 16),
              _buildDebugSection(isDark, 'iOS 위젯 상태', [
                '자동 새로고침: ${debugInfo['widget_auto_refresh'] == true ? '✅ 활성화' : '❌ 비활성화'}',
                '새로고침 횟수: ${debugInfo['widget_refresh_count'] ?? 0}회',
                '마지막 새로고침: ${debugInfo['widget_last_refresh_ago'] ?? 'N/A'}',
                '서버 요청 성공: ${debugInfo['widget_last_fetch_success'] == true ? '✅' : '❌'}',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              _showWidgetDebugInfo(parentContext, isDark); // 새로고침
            },
            child: Text(
              '새로고침',
              style: TextStyle(color: Colors.blue.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '닫기',
              style: TextStyle(color: Theme.of(dialogContext).primaryColor),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // 디버그 섹션 빌더
  Widget _buildDebugSection(bool isDark, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
