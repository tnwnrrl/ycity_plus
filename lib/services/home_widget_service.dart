import 'dart:async';
import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/parking_floor_info.dart';

class HomeWidgetService {
  static const String _appGroupId = 'group.com.ilsan-ycity.ilsanycityplus';

  // ⚠️ 중요: iOS 위젯과 키 이름 일치를 위해 flutter. 접두사 사용
  // home_widget 패키지는 접두사를 자동으로 추가하지 않으므로 명시적으로 추가해야 함
  static const String _floorInfoKey = 'flutter.floor_info';
  static const String _colorKey = 'flutter.floor_color';
  static const String _statusKey = 'flutter.status_text';
  static const String _lastUpdateTimestampKey = 'flutter.last_update_timestamp';

  // 다중 차량 지원을 위한 새로운 키들
  static const String _selectedVehicleIndexKey = 'flutter.selected_vehicle_index';
  static const String _vehicleCountKey = 'flutter.vehicle_count';

  // 사용자 정보 키 (iOS 위젯 백그라운드 새로고침용)
  static const String _userDongKey = 'flutter.user_dong';
  static const String _userHoKey = 'flutter.user_ho';
  static const String _userSerialNumberKey = 'flutter.user_serial_number';

  // 위젯 자동 새로고침 설정 키
  static const String _widgetAutoRefreshKey = 'flutter.widget_auto_refresh';

  // Android MethodChannel for widget click events
  static const MethodChannel _widgetClickChannel =
      MethodChannel('ycityplus/widget_click');

  // Android MethodChannel for WorkManager background updates
  static const MethodChannel _workManagerChannel =
      MethodChannel('ycityplus/workmanager');

  // 위젯 서비스 초기화
  static Future<void> initialize() async {
    try {
      // iOS App Group 설정
      _log('🔧 App Group 설정 시작: $_appGroupId');
      await HomeWidget.setAppGroupId(_appGroupId);
      _log('✅ App Group 설정 완료: $_appGroupId');

      // 플랫폼별 위젯 클릭 이벤트 처리
      if (Platform.isAndroid) {
        // Android: MethodChannel을 통한 위젯 클릭 처리
        _widgetClickChannel.setMethodCallHandler((call) async {
          if (call.method == 'onWidgetClicked') {
            final uriString = call.arguments as String?;
            _log('Android MethodChannel에서 위젯 클릭 수신: $uriString');
            if (uriString != null) {
              _handleWidgetClick(Uri.parse(uriString));
            }
          }
        });

        // 앱 시작 시 위젯 클릭 Intent 확인
        try {
          final initialUri =
              await _widgetClickChannel.invokeMethod('getWidgetClickIntent');
          if (initialUri != null && initialUri is String) {
            _log('Android 앱 시작 시 위젯 클릭 URI: $initialUri');
            _handleWidgetClick(Uri.parse(initialUri));
          }
        } on FormatException catch (e) {
          _log('Android 초기 위젯 클릭 URI 파싱 오류: $e');
        } catch (e) {
          _log('Android 초기 위젯 클릭 확인 중 예상치 못한 오류: $e');
        }
      } else {
        // iOS: 기존 home_widget 패키지 사용
        HomeWidget.widgetClicked.listen((Uri? uri) {
          _log('iOS HomeWidget.widgetClicked 이벤트 수신: $uri');
          if (uri != null) {
            _handleWidgetClick(uri);
          }
        });

        // 초기 위젯 URL 확인 (앱이 위젯 클릭으로 시작된 경우)
        final initialUrl = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (initialUrl != null) {
          _log('iOS 앱이 위젯 클릭으로 시작됨: $initialUrl');
          _handleWidgetClick(initialUrl);
        }
      }

      _log('HomeWidgetService 초기화 완료');
    } catch (e) {
      _log('HomeWidgetService 초기화 중 오류: $e');
    }
  }

  // 위젯 클릭 이벤트 처리
  static void _handleWidgetClick(Uri uri) {
    _log('🎯 위젯 클릭 이벤트 수신: ${uri.toString()}');

    // 위치확인 화면으로 이동하는 URL 스킴인 경우
    if (uri.toString().startsWith('ycityplus://vehicle_location')) {
      _log('✅ 차량 위치 확인 화면으로 이동 요청 - 스트림에 이벤트 전달');

      // 위젯 클릭 시 즉시 새로고침 실행
      refreshWidgetOnTap();

      // 이 이벤트를 메인 앱에서 처리할 수 있도록 글로벌 스트림에 전달
      if (_widgetClickController.hasListener) {
        _log('📢 스트림 리스너 확인됨 - 이벤트 전달 중');
        _widgetClickController.add('vehicle_location');
        _log('🚀 vehicle_location 이벤트 스트림에 전달 완료');
      } else {
        _log('❌ 스트림 리스너가 없음 - 이벤트 전달 불가');
      }
    } else {
      _log('❌ 인식되지 않는 URL 스킴: ${uri.toString()}');
    }
  }

  // 위젯 클릭 이벤트를 메인 앱에 전달하기 위한 스트림
  static final _widgetClickController = StreamController<String>.broadcast();
  static Stream<String> get widgetClickStream => _widgetClickController.stream;

  // 백그라운드 콜백 (위젯 클릭 시 실행)
  @pragma('vm:entry-point')
  static void _backgroundCallback(Uri? uri) {
    if (uri != null) {
      _handleWidgetClick(uri);
    }
  }

  // 사용자 정보를 위젯이 접근할 수 있도록 저장 (백그라운드 새로고침용 포함)
  // ⚠️ 중요: home_widget 패키지는 flutter. 접두사를 자동으로 추가하지 않음!
  // iOS 위젯에서 flutter.user_dong 등으로 접근하므로 명시적으로 flutter. 접두사 포함 키 사용
  static Future<void> saveUserInfo(String dong, String ho, String serialNumber) async {
    try {
      _log('📝 사용자 정보 저장 시작: $dong동 $ho호');

      // App Group이 설정되어 있는지 다시 확인
      await HomeWidget.setAppGroupId(_appGroupId);

      // ⚠️ 키에 flutter. 접두사 사용 (iOS 위젯과 일치)
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_userDongKey, dong),
        HomeWidget.saveWidgetData<String>(_userHoKey, ho),
        HomeWidget.saveWidgetData<String>(_userSerialNumberKey, serialNumber),
      ]);

      _log('✅ 사용자 정보 저장 완료: $dong동 $ho호');
      _log('   저장된 키: $_userDongKey, $_userHoKey, $_userSerialNumberKey');

      // Android WorkManager 자동 시작 (자동 새로고침이 활성화된 경우)
      if (Platform.isAndroid) {
        final autoRefreshEnabled = await getWidgetAutoRefreshSetting();
        if (autoRefreshEnabled) {
          await startPeriodicBackgroundUpdates(dong, ho, serialNumber);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 사용자 정보 저장 실패: $e');
      }
    }
  }

  // 위젯 자동 새로고침 설정 저장
  static Future<void> saveWidgetAutoRefreshSetting(bool enabled) async {
    try {
      await HomeWidget.saveWidgetData<bool>(_widgetAutoRefreshKey, enabled);

      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 위젯 자동 새로고침 설정 저장: $enabled (키: $_widgetAutoRefreshKey)');
      }

      // Android WorkManager 스케줄링 관리
      if (Platform.isAndroid) {
        if (enabled) {
          // 자동 새로고침 활성화 시 WorkManager 스케줄링 시작
          final dong = await HomeWidget.getWidgetData<String>(_userDongKey, defaultValue: '');
          final ho = await HomeWidget.getWidgetData<String>(_userHoKey, defaultValue: '');
          final serialNumber = await HomeWidget.getWidgetData<String>(_userSerialNumberKey, defaultValue: '');
          
          if (dong?.isNotEmpty == true && ho?.isNotEmpty == true && serialNumber?.isNotEmpty == true) {
            await startPeriodicBackgroundUpdates(dong!, ho!, serialNumber!);
          }
        } else {
          // 자동 새로고침 비활성화 시 WorkManager 중지
          await stopPeriodicBackgroundUpdates();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 위젯 자동 새로고침 설정 저장 실패: $e');
      }
    }
  }

  // 앱 포그라운드 진입 시 위젯 강제 업데이트
  static Future<void> forceUpdateWidgetOnAppResume() async {
    try {
      _log('🔄 앱 포그라운드 진입 - 위젯 강제 업데이트 시작');
      
      // 캐시된 위젯 데이터 읽기
      final floorInfo = await HomeWidget.getWidgetData<String>(_floorInfoKey, defaultValue: '');
      final colorKey = await HomeWidget.getWidgetData<String>(_colorKey, defaultValue: 'grey');
      
      if (floorInfo?.isNotEmpty == true) {
        // 강제 위젯 업데이트 트리거
        await HomeWidget.updateWidget(
          name: 'VehicleLocationWidget',
          androidName: 'VehicleLocationWidgetProvider',
          iOSName: 'VehicleLocationWidget',
          qualifiedAndroidName: 'com.mycompany.YcityPlus.VehicleLocationWidgetProvider',
        );
        
        _log('✅ 앱 포그라운드 진입 시 위젯 강제 업데이트 완료: $floorInfo ($colorKey)');
      } else {
        _log('⚠️ 캐시된 위젯 데이터가 없어서 강제 업데이트 건너뜀');
      }
    } catch (e) {
      _log('❌ 앱 포그라운드 진입 시 위젯 강제 업데이트 실패: $e');
    }
  }

  // 위젯 탭 시 즉시 새로고침 (데이터 갱신 포함)
  static Future<void> refreshWidgetOnTap() async {
    try {
      _log('👆 위젯 탭 감지 - 즉시 새로고침 시작');
      
      // 사용자 정보 확인
      final dong = await HomeWidget.getWidgetData<String>(_userDongKey, defaultValue: '');
      final ho = await HomeWidget.getWidgetData<String>(_userHoKey, defaultValue: '');
      final serialNumber = await HomeWidget.getWidgetData<String>(_userSerialNumberKey, defaultValue: '');
      
      if (dong?.isNotEmpty == true && ho?.isNotEmpty == true && serialNumber?.isNotEmpty == true) {
        // Android에서 즉시 WorkManager 업데이트 작업 예약
        if (Platform.isAndroid) {
          await scheduleBackgroundWidgetUpdate(dong!, ho!, serialNumber!);
          _log('📱 Android 즉시 WorkManager 업데이트 예약됨');
        }
        
        _log('✅ 위젯 탭 즉시 새로고침 완료');
      } else {
        _log('⚠️ 사용자 정보가 없어서 즉시 새로고침 불가');
      }
    } catch (e) {
      _log('❌ 위젯 탭 즉시 새로고침 실패: $e');
    }
  }

  // 위젯 자동 새로고침 설정 불러오기
  static Future<bool> getWidgetAutoRefreshSetting() async {
    try {
      final enabled = await HomeWidget.getWidgetData<bool>(_widgetAutoRefreshKey, defaultValue: true);
      return enabled ?? true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 위젯 자동 새로고침 설정 불러오기 실패: $e');
      }
      return true; // 기본값 true
    }
  }

  // 선택된 차량 인덱스 저장 (다중 차량 지원)
  static Future<void> saveSelectedVehicleIndex(int vehicleIndex) async {
    try {
      await HomeWidget.saveWidgetData<int>(_selectedVehicleIndexKey, vehicleIndex);
      
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 선택된 차량 인덱스 저장 완료: $vehicleIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 선택된 차량 인덱스 저장 실패: $e');
      }
    }
  }

  // 선택된 차량 인덱스 불러오기
  static Future<int> getSelectedVehicleIndex() async {
    try {
      final index = await HomeWidget.getWidgetData<int>(_selectedVehicleIndexKey, defaultValue: 1);
      
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 선택된 차량 인덱스 불러오기: $index');
      }
      
      return index ?? 1; // 기본값 1 (첫 번째 차량)
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 선택된 차량 인덱스 불러오기 실패: $e');
      }
      return 1; // 오류 시 기본값 반환
    }
  }

  // 다중 차량 정보 저장 (JSON 직렬화)
  static Future<void> saveMultipleVehicleInfo(List<ParkingFloorInfo> vehicleList) async {
    try {
      // 차량 개수 저장
      await HomeWidget.saveWidgetData<int>(_vehicleCountKey, vehicleList.length);
      
      // 각 차량 정보를 개별적으로 저장 (JSON 직렬화 대신 단순 키-값 방식)
      for (int i = 0; i < vehicleList.length; i++) {
        final vehicle = vehicleList[i];
        final index = i + 1; // 1-based 인덱스
        
        await Future.wait([
          HomeWidget.saveWidgetData<String>('flutter.vehicle_${index}_floor', vehicle.floor),
          HomeWidget.saveWidgetData<String>('flutter.vehicle_${index}_color', vehicle.floorColorKey),
          HomeWidget.saveWidgetData<String>('flutter.vehicle_${index}_status', vehicle.statusText),
          HomeWidget.saveWidgetData<String>('flutter.vehicle_${index}_display_name', vehicle.displayName),
          HomeWidget.saveWidgetData<int>('flutter.vehicle_${index}_vehicle_index', vehicle.vehicleIndex),
        ]);
      }
      
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 다중 차량 정보 저장 완료: ${vehicleList.length}개 차량');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 다중 차량 정보 저장 실패: $e');
      }
    }
  }

  // 다중 차량 개수 불러오기
  static Future<int> getVehicleCount() async {
    try {
      final count = await HomeWidget.getWidgetData<int>(_vehicleCountKey, defaultValue: 0);
      return count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HomeWidgetService] 차량 개수 불러오기 실패: $e');
      }
      return 0;
    }
  }

  // 주차 층 정보를 위젯에 업데이트 (기존 호환성 유지)
  static Future<void> updateWidget(ParkingFloorInfo? floorInfo) async {
    try {
      if (floorInfo == null) {
        await _clearWidgetData();
        return;
      }

      String floorText = floorInfo.floor;
      String colorKey = floorInfo.floorColorKey;
      String statusText = floorInfo.statusText;

      // 층 정보를 표시할 수 없는 경우 X 표시
      if (_shouldShowX(floorInfo.floor)) {
        floorText = 'X';
        colorKey = 'grey';
        statusText = '위치 정보를 확인할 수 없음';
      }

      // 위젯 데이터 저장 (더 자세한 로깅)
      _log('🔄 위젯 데이터 저장 시작: $floorText ($colorKey)');
      
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_floorInfoKey, floorText),
        HomeWidget.saveWidgetData<String>(_colorKey, colorKey),
        HomeWidget.saveWidgetData<String>(_statusKey, statusText),
        // 마지막 업데이트 시간 저장 (flutter. 접두사 사용)
        HomeWidget.saveWidgetData<int>(_lastUpdateTimestampKey, DateTime.now().millisecondsSinceEpoch),
      ]);
      
      _log('  ✅ floor_info 저장됨: $floorText');
      _log('  ✅ floor_color 저장됨: $colorKey');
      _log('  ✅ status_text 저장됨: $statusText');
      _log('  ✅ last_update_timestamp 저장됨: ${DateTime.now().millisecondsSinceEpoch}');

      // 저장된 데이터 검증
      final savedFloor = await HomeWidget.getWidgetData<String>(_floorInfoKey, defaultValue: 'null');
      final savedColor = await HomeWidget.getWidgetData<String>(_colorKey, defaultValue: 'null');
      final savedStatus = await HomeWidget.getWidgetData<String>(_statusKey, defaultValue: 'null');
      
      _log('🔍 저장된 데이터 검증:');
      _log('  - floor_info: $savedFloor');
      _log('  - floor_color: $savedColor');
      _log('  - status_text: $savedStatus');

      // 위젯 클릭 액션 설정 (위치확인 화면으로 이동)
      await HomeWidget.registerInteractivityCallback(_backgroundCallback);

      // 위젯 업데이트 요청
      await HomeWidget.updateWidget(
        name: 'VehicleLocationWidget',
        androidName: 'VehicleLocationWidgetProvider',
        iOSName: 'VehicleLocationWidget',
        qualifiedAndroidName:
            'com.mycompany.YcityPlus.VehicleLocationWidgetProvider',
      );

      _log('✅ 위젯 업데이트 완료: $floorText ($colorKey)');
    } catch (e) {
      _log('위젯 업데이트 중 오류: $e');
    }
  }

  // 다중 차량 정보를 위젯에 업데이트 (선택된 차량 기준)
  static Future<void> updateWidgetWithMultipleVehicles({
    required List<ParkingFloorInfo> vehicleList,
    required int selectedVehicleIndex,
  }) async {
    try {
      if (vehicleList.isEmpty) {
        await _clearWidgetData();
        return;
      }

      // 선택된 차량 인덱스 유효성 검사
      if (selectedVehicleIndex < 1 || selectedVehicleIndex > vehicleList.length) {
        _log('잘못된 차량 인덱스: $selectedVehicleIndex (범위: 1-${vehicleList.length})');
        return;
      }

      // 다중 차량 정보 저장
      await saveMultipleVehicleInfo(vehicleList);
      await saveSelectedVehicleIndex(selectedVehicleIndex);

      // 선택된 차량 정보를 위젯에 표시
      final selectedVehicle = vehicleList[selectedVehicleIndex - 1]; // 0-based 인덱스로 변환
      await updateWidget(selectedVehicle);

      _log('다중 차량 위젯 업데이트 완료: ${vehicleList.length}개 차량, 선택: $selectedVehicleIndex (${selectedVehicle.displayName})');
    } catch (e) {
      _log('다중 차량 위젯 업데이트 중 오류: $e');
    }
  }

  // 선택된 차량만 업데이트 (다중 차량 모드에서 차량 선택 변경 시)
  static Future<void> updateSelectedVehicle({
    required List<ParkingFloorInfo> vehicleList,
    required int selectedVehicleIndex,
  }) async {
    try {
      if (vehicleList.isEmpty || selectedVehicleIndex < 1 || selectedVehicleIndex > vehicleList.length) {
        _log('차량 선택 업데이트 실패: 잘못된 인덱스 $selectedVehicleIndex (범위: 1-${vehicleList.length})');
        return;
      }

      // 선택된 차량 인덱스만 업데이트
      await saveSelectedVehicleIndex(selectedVehicleIndex);

      // 선택된 차량 정보를 위젯에 표시
      final selectedVehicle = vehicleList[selectedVehicleIndex - 1];
      await updateWidget(selectedVehicle);

      _log('선택된 차량 위젯 업데이트 완료: ${selectedVehicle.displayName} (인덱스: $selectedVehicleIndex)');
    } catch (e) {
      _log('선택된 차량 위젯 업데이트 중 오류: $e');
    }
  }

  // 층 정보 표시가 불가능한 경우 판단
  static bool _shouldShowX(String floor) {
    // 빈 문자열, null, '출차됨', '위치 불명' 등의 경우 X 표시
    if (floor.isEmpty ||
        floor == '출차됨' ||
        floor == '위치 불명' ||
        floor == '정보 없음' ||
        floor.contains('오류') ||
        floor.contains('실패')) {
      return true;
    }

    // 유효한 층 정보인지 확인 (B1, B2, B3, B4, 1F, 2F 등)
    final validFloorPattern =
        RegExp(r'^(B[1-4]|[1-9]F?)$', caseSensitive: false);
    return !validFloorPattern.hasMatch(floor);
  }

  // 위젯 데이터 초기화
  static Future<void> _clearWidgetData() async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_floorInfoKey, 'X'),
        HomeWidget.saveWidgetData<String>(_colorKey, 'grey'),
        HomeWidget.saveWidgetData<String>(_statusKey, '등록된 차량 정보가 없습니다'),
      ]);

      await HomeWidget.updateWidget(
        name: 'VehicleLocationWidget',
        androidName: 'VehicleLocationWidgetProvider',
        iOSName: 'VehicleLocationWidget',
      );

      _log('위젯 데이터 초기화 완료');
    } catch (e) {
      _log('위젯 데이터 초기화 중 오류: $e');
    }
  }

  // 디버그 로깅
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HomeWidgetService] $message');
    }
  }

  // 색상 키를 색상 값으로 변환 (Android용)
  static String getColorValue(String colorKey) {
    switch (colorKey) {
      case 'blue':
        return '#2563EB'; // blue-600
      case 'green':
        return '#16A34A'; // green-600
      case 'orange':
        return '#EA580C'; // orange-600
      case 'purple':
        return '#9333EA'; // purple-600
      case 'red':
        return '#DC2626'; // red-600
      default:
        return '#6B7280'; // gray-600
    }
  }

  // 백그라운드 위젯 업데이트 작업 예약 (Android WorkManager)
  static Future<void> scheduleBackgroundWidgetUpdate(String dong, String ho, String serialNumber) async {
    if (Platform.isAndroid) {
      try {
        await _workManagerChannel.invokeMethod('scheduleOneTimeUpdate', {
          'dong': dong,
          'ho': ho,
          'serialNumber': serialNumber,
        });
        _log('Android WorkManager 즉시 업데이트 작업 예약됨: $dong동 $ho호');
      } catch (e) {
        _log('Android WorkManager 즉시 업데이트 예약 실패: $e');
      }
    }
  }

  // 주기적 백그라운드 위젯 업데이트 시작 (Android WorkManager)
  static Future<void> startPeriodicBackgroundUpdates(String dong, String ho, String serialNumber) async {
    if (Platform.isAndroid) {
      try {
        await _workManagerChannel.invokeMethod('schedulePeriodicUpdates', {
          'dong': dong,
          'ho': ho,
          'serialNumber': serialNumber,
        });
        _log('Android WorkManager 주기적 업데이트 시작됨: $dong동 $ho호 (15분마다)');
      } catch (e) {
        _log('Android WorkManager 주기적 업데이트 시작 실패: $e');
      }
    }
  }

  // 주기적 백그라운드 위젯 업데이트 중지 (Android WorkManager)
  static Future<void> stopPeriodicBackgroundUpdates() async {
    if (Platform.isAndroid) {
      try {
        await _workManagerChannel.invokeMethod('cancelPeriodicUpdates');
        _log('Android WorkManager 주기적 업데이트 중지됨');
      } catch (e) {
        _log('Android WorkManager 주기적 업데이트 중지 실패: $e');
      }
    }
  }

  // 🔍 디버그: 위젯 새로고침 상태 확인 (iOS 전용)
  static Future<Map<String, dynamic>> getWidgetDebugInfo() async {
    try {
      // ⚠️ 중요: 데이터 읽기 전에 App Group 설정 필수
      await HomeWidget.setAppGroupId(_appGroupId);

      final debugInfo = <String, dynamic>{};

      // 사용자 정보 확인
      debugInfo['user_dong'] = await HomeWidget.getWidgetData<String>(_userDongKey, defaultValue: '');
      debugInfo['user_ho'] = await HomeWidget.getWidgetData<String>(_userHoKey, defaultValue: '');
      debugInfo['user_serial_number'] = await HomeWidget.getWidgetData<String>(_userSerialNumberKey, defaultValue: '');

      // 위젯 데이터 확인
      debugInfo['floor_info'] = await HomeWidget.getWidgetData<String>(_floorInfoKey, defaultValue: '');
      debugInfo['floor_color'] = await HomeWidget.getWidgetData<String>(_colorKey, defaultValue: '');
      debugInfo['status_text'] = await HomeWidget.getWidgetData<String>(_statusKey, defaultValue: '');

      // 설정 확인
      debugInfo['widget_auto_refresh'] = await HomeWidget.getWidgetData<bool>(_widgetAutoRefreshKey, defaultValue: true);

      // 마지막 업데이트 시간
      final lastUpdateTimestamp = await HomeWidget.getWidgetData<int>(_lastUpdateTimestampKey, defaultValue: 0);
      if (lastUpdateTimestamp != null && lastUpdateTimestamp != 0) {
        final lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateTimestamp);
        debugInfo['last_update_time'] = lastUpdate.toString();
        debugInfo['last_update_ago'] = _getTimeAgo(lastUpdate);
      } else {
        debugInfo['last_update_time'] = 'N/A';
        debugInfo['last_update_ago'] = 'N/A';
      }

      // iOS 위젯 전용 디버그 정보
      // iOS 위젯이 flutter.widget_refresh_count 키로 저장하므로
      // Flutter에서도 동일한 키(flutter. 접두사 포함)로 읽어야 함
      if (Platform.isIOS) {
        debugInfo['widget_refresh_count'] = await HomeWidget.getWidgetData<int>('flutter.widget_refresh_count', defaultValue: 0);

        final lastRefreshTime = await HomeWidget.getWidgetData<double>('flutter.widget_last_refresh_time', defaultValue: 0.0);
        if (lastRefreshTime != null && lastRefreshTime != 0.0) {
          final refreshDate = DateTime.fromMillisecondsSinceEpoch((lastRefreshTime * 1000).toInt());
          debugInfo['widget_last_refresh_time'] = refreshDate.toString();
          debugInfo['widget_last_refresh_ago'] = _getTimeAgo(refreshDate);
        } else {
          debugInfo['widget_last_refresh_time'] = 'N/A';
          debugInfo['widget_last_refresh_ago'] = 'N/A';
        }

        debugInfo['widget_last_fetch_success'] = await HomeWidget.getWidgetData<bool>('flutter.widget_last_fetch_success', defaultValue: false);
      }

      _log('🔍 위젯 디버그 정보: $debugInfo');
      return debugInfo;
    } catch (e) {
      _log('위젯 디버그 정보 조회 실패: $e');
      return {'error': e.toString()};
    }
  }

  // 시간 경과 문자열 생성
  static String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}초 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  // 🔄 iOS 위젯 강제 새로고침 테스트
  static Future<void> forceRefreshIOSWidget() async {
    if (!Platform.isIOS) {
      _log('iOS 전용 기능입니다');
      return;
    }

    try {
      _log('🔄 iOS 위젯 강제 새로고침 시작...');

      // WidgetKit reloadAllTimelines 호출
      await HomeWidget.updateWidget(
        name: 'VehicleLocationWidget',
        iOSName: 'VehicleLocationWidget',
      );

      _log('✅ iOS 위젯 새로고침 요청 완료');
    } catch (e) {
      _log('❌ iOS 위젯 강제 새로고침 실패: $e');
    }
  }
}
