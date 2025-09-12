import 'package:flutter/foundation.dart';
import '../models/parking_floor_info.dart';
import '../models/user_info.dart';
import '../models/vehicle_service_error.dart';
import '../services/vehicle_location_service.dart';
import '../services/home_widget_service.dart';
import '../services/preferences_service.dart';

/// 차량 위치 정보 상태 관리 Provider - 다중 차량 지원
class VehicleLocationProvider extends ChangeNotifier {
  final VehicleLocationService _vehicleLocationService;
  final PreferencesService _preferencesService;

  // 단일 차량 상태 변수들 (호환성 유지)
  ParkingFloorInfo? _currentFloorInfo;
  bool _isLocationLoading = false;
  VehicleServiceError? _locationError;
  DateTime? _lastUpdated;

  // 다중 차량 상태 변수들
  List<ParkingFloorInfo>? _multipleFloorInfoList;
  int _selectedVehicleIndex = 1; // 선택된 차량 인덱스 (1, 2, 3...)
  bool _isMultipleVehicleMode = false; // 다중 차량 모드 여부

  // Optimistic Updates 관련 상태 (Phase 2.3)
  ParkingFloorInfo? _optimisticFloorInfo; // 즉시 반영할 임시 데이터
  bool _isOptimisticUpdate = false; // 현재 상태가 optimistic인지 여부

  // 생성자
  VehicleLocationProvider({
    VehicleLocationService? vehicleLocationService,
    PreferencesService? preferencesService,
  }) : _vehicleLocationService =
            vehicleLocationService ?? VehicleLocationService(),
        _preferencesService = preferencesService ?? PreferencesService();

  // 단일/다중 차량 통합 Getters
  ParkingFloorInfo? get currentFloorInfo {
    // Optimistic update가 있으면 우선 반환
    if (_isOptimisticUpdate && _optimisticFloorInfo != null) {
      return _optimisticFloorInfo;
    }
    
    // 다중 차량 모드인 경우 선택된 차량 반환
    if (_isMultipleVehicleMode && _multipleFloorInfoList != null) {
      final selectedVehicle = _getSelectedVehicle();
      if (selectedVehicle != null) {
        return selectedVehicle;
      }
    }
    
    // 단일 차량 모드 또는 폴백
    return _currentFloorInfo;
  }
  
  bool get isLocationLoading => _isLocationLoading;
  VehicleServiceError? get locationError => _locationError;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isOptimisticUpdate => _isOptimisticUpdate;
  
  // 다중 차량 관련 Getters
  List<ParkingFloorInfo>? get multipleFloorInfoList => _multipleFloorInfoList;
  int get selectedVehicleIndex => _selectedVehicleIndex;
  bool get isMultipleVehicleMode => _isMultipleVehicleMode;
  bool get hasMultipleVehicles => _isMultipleVehicleMode && _multipleFloorInfoList != null && _multipleFloorInfoList!.length > 1;
  int get vehicleCount => _multipleFloorInfoList?.length ?? 0;

  /// 차량 위치 정보 조회 (Optimistic Updates 지원)
  Future<void> fetchVehicleLocation({
    required UserInfo userInfo,
    bool forceRefresh = false,
    bool useOptimisticUpdate = false,
    ParkingFloorInfo? optimisticData,
  }) async {
    // Phase 2.3: Optimistic Updates - 즉시 UI 업데이트
    if (useOptimisticUpdate && optimisticData != null) {
      _setOptimisticUpdate(true);
      _setOptimisticFloorInfo(optimisticData);

      if (kDebugMode) {
        debugPrint(
            '[VehicleLocationProvider] Optimistic Update 적용: ${optimisticData.floor}');
      }
    }

    // 로딩 상태 설정
    _setLocationLoading(true);

    try {
      final result =
          await _vehicleLocationService.getVehicleLocationInfoWithErrorHandling(
        dong: userInfo.dong,
        ho: userInfo.ho,
        serialNumber: userInfo.serialNumber,
        useCache: !forceRefresh,
      );

      if (result.isSuccess && result.data != null) {
        // Phase 2.3: 실제 서버 응답으로 optimistic update 해제
        _clearOptimisticUpdate();
        _setCurrentFloorInfo(result.data!);
        _clearLocationError();
        _setLastUpdated(DateTime.now());

        // 홈 위젯 업데이트
        await _updateHomeWidget(result.data!);

        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 위치 정보 업데이트 완료: ${result.data}');
          if (useOptimisticUpdate) {
            debugPrint(
                '[VehicleLocationProvider] Optimistic Update 검증: ${optimisticData?.floor == result.data!.floor ? "일치" : "불일치"}');
          }
        }
      } else if (result.error != null) {
        // Phase 2.3: 오류 시 optimistic update 롤백
        if (_isOptimisticUpdate) {
          _rollbackOptimisticUpdate();
          if (kDebugMode) {
            debugPrint('[VehicleLocationProvider] Optimistic Update 롤백됨 (오류)');
          }
        }

        _setLocationError(result.error!);
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 위치 조회 오류: ${result.error}');
        }
      }
    } catch (e) {
      // Phase 2.3: 예외 시 optimistic update 롤백
      if (_isOptimisticUpdate) {
        _rollbackOptimisticUpdate();
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] Optimistic Update 롤백됨 (예외)');
        }
      }

      _setLocationError(VehicleServiceError(
        type: VehicleServiceErrorType.unknown,
        message: e.toString(),
      ));

      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 예상치 못한 오류: $e');
      }
    } finally {
      _setLocationLoading(false);
    }
  }

  /// 다중 차량 위치 정보 조회 (새로운 API)
  Future<void> fetchMultipleVehicleLocation({
    required UserInfo userInfo,
    bool forceRefresh = false,
  }) async {
    // 로딩 상태 설정
    _setLocationLoading(true);

    try {
      final result = await _vehicleLocationService
          .getMultipleVehicleLocationInfoWithErrorHandling(
        dong: userInfo.dong,
        ho: userInfo.ho,
        serialNumber: userInfo.serialNumber,
        useCache: !forceRefresh,
      );

      if (result.isSuccess && result.data != null) {
        final vehicleList = result.data!;
        final isNowMultipleMode = vehicleList.length > 1;
        final wasMultipleMode = _isMultipleVehicleMode;
        
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 다중 차량 정보 수신: ${vehicleList.length}개 차량 (이전: ${wasMultipleMode ? "다중" : "단일"} → 현재: ${isNowMultipleMode ? "다중" : "단일"})');
        }
        
        // 다중 → 단일 차량 전환 시 기존 상태 완전 초기화
        if (wasMultipleMode && !isNowMultipleMode) {
          if (kDebugMode) {
            debugPrint('[VehicleLocationProvider] 다중 → 단일 차량 전환 감지, 상태 초기화 시작');
          }
          
          // 다중 차량 관련 상태 완전 초기화
          _multipleFloorInfoList = null;
          _selectedVehicleIndex = 1;
          _isMultipleVehicleMode = false;
          
          if (kDebugMode) {
            debugPrint('[VehicleLocationProvider] 다중 차량 상태 초기화 완료');
          }
        }
        
        // 새로운 차량 데이터로 상태 업데이트 (순서 중요)
        _setMultipleVehicleMode(isNowMultipleMode);
        _setMultipleFloorInfoList(vehicleList);
        
        // 이전 선택된 차량 인덱스 복원 또는 기본값 설정
        await _restoreSelectedVehicleIndex(vehicleList.length);
        
        // 단일 차량 호환성: 선택된 차량을 currentFloorInfo로 설정
        final selectedVehicle = _getSelectedVehicle();
        if (selectedVehicle != null) {
          _setCurrentFloorInfo(selectedVehicle);
        }
        
        _clearLocationError();
        _setLastUpdated(DateTime.now());

        // SharedPreferences에 다중 차량 정보 저장
        await _preferencesService.saveMultipleVehicleInfo(
          selectedVehicleIndex: _selectedVehicleIndex,
          vehicleCount: vehicleList.length,
          isMultipleMode: _isMultipleVehicleMode,
        );

        // 홈 위젯 업데이트 (선택된 차량 기준)
        if (selectedVehicle != null) {
          await _updateHomeWidget(selectedVehicle);
        }

        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 다중 차량 업데이트 완료: 총 ${vehicleList.length}개, 선택: $_selectedVehicleIndex');
        }
      } else if (result.error != null) {
        _setLocationError(result.error!);
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 다중 차량 조회 오류: ${result.error}');
        }
      }
    } catch (e) {
      _setLocationError(VehicleServiceError(
        type: VehicleServiceErrorType.unknown,
        message: e.toString(),
      ));

      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 다중 차량 예상치 못한 오류: $e');
      }
    } finally {
      _setLocationLoading(false);
    }
  }

  /// 차량 위치 정보 새로고침 (다중 차량 우선)
  Future<void> refreshVehicleLocation(UserInfo userInfo) async {
    // 다중 차량 API를 먼저 시도
    await fetchMultipleVehicleLocation(userInfo: userInfo, forceRefresh: true);
    
    // 호환성: 단일 차량 API도 호출 (기존 코드 대응)
    if (!_isMultipleVehicleMode) {
      await fetchVehicleLocation(userInfo: userInfo, forceRefresh: true);
    }
  }
  
  /// 차량 선택
  void selectVehicle(int vehicleIndex) {
    if (!_isMultipleVehicleMode || _multipleFloorInfoList == null) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 다중 차량 모드가 아니거나 차량 데이터가 없음');
      }
      return;
    }
    
    if (vehicleIndex < 1 || vehicleIndex > _multipleFloorInfoList!.length) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 잘못된 차량 인덱스: $vehicleIndex (범위: 1-${_multipleFloorInfoList!.length})');
      }
      return;
    }
    
    _setSelectedVehicleIndex(vehicleIndex);
    
    // 선택된 차량을 currentFloorInfo로 업데이트 (단일 차량 호환성)
    final selectedVehicle = _getSelectedVehicle();
    if (selectedVehicle != null) {
      _setCurrentFloorInfo(selectedVehicle);
      
      // 홈 위젯 업데이트 및 인덱스 동기화
      Future.microtask(() async {
        // 양쪽 서비스에 동기화
        await _syncSelectedVehicleIndex(vehicleIndex);
        
        // 홈 위젯 업데이트
        await HomeWidgetService.updateSelectedVehicle(
          vehicleList: _multipleFloorInfoList!,
          selectedVehicleIndex: vehicleIndex,
        );
      });
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 차량 선택: ${selectedVehicle.displayName} (층: ${selectedVehicle.floor})');
      }
    }
  }

  /// Phase 2.3: Optimistic Update 적용 (즉시 UI 반영)
  void applyOptimisticUpdate(ParkingFloorInfo optimisticData) {
    _setOptimisticUpdate(true);
    _setOptimisticFloorInfo(optimisticData);

    if (kDebugMode) {
      debugPrint(
          '[VehicleLocationProvider] Optimistic Update 수동 적용: ${optimisticData.floor}');
    }
  }

  /// Phase 2.3: 캐시 기반 Optimistic Update (이전 데이터 활용)
  Future<void> fetchWithCacheOptimistic({
    required UserInfo userInfo,
    bool forceRefresh = false,
  }) async {
    // 기존 캐시가 있고 유효하다면 optimistic으로 먼저 표시
    if (_currentFloorInfo != null && isCacheValid && !forceRefresh) {
      _setOptimisticUpdate(true);
      _setOptimisticFloorInfo(_currentFloorInfo!);

      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 캐시 기반 Optimistic Update 적용');
      }
    }

    // 실제 데이터 조회
    await fetchVehicleLocation(userInfo: userInfo, forceRefresh: forceRefresh);
  }

  /// 홈 위젯 업데이트 (다중 차량 지원)
  Future<void> _updateHomeWidget(ParkingFloorInfo floorInfo) async {
    try {
      // 다중 차량 모드인 경우 다중 차량 위젯 업데이트 사용
      if (_isMultipleVehicleMode && _multipleFloorInfoList != null) {
        await HomeWidgetService.updateWidgetWithMultipleVehicles(
          vehicleList: _multipleFloorInfoList!,
          selectedVehicleIndex: _selectedVehicleIndex,
        );
      } else {
        // 단일 차량 모드인 경우 기존 방식 사용
        await HomeWidgetService.updateWidget(floorInfo);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 홈 위젯 업데이트 실패: $e');
      }
    }
  }

  /// 현재 층 정보 설정
  void _setCurrentFloorInfo(ParkingFloorInfo floorInfo) {
    if (_currentFloorInfo != floorInfo) {
      _currentFloorInfo = floorInfo;
      notifyListeners();
    }
  }

  /// 로딩 상태 설정
  void _setLocationLoading(bool loading) {
    if (_isLocationLoading != loading) {
      _isLocationLoading = loading;
      notifyListeners();
    }
  }

  /// 오류 상태 설정
  void _setLocationError(VehicleServiceError error) {
    _locationError = error;
    notifyListeners();
  }

  /// 오류 상태 초기화
  void _clearLocationError() {
    if (_locationError != null) {
      _locationError = null;
      notifyListeners();
    }
  }

  /// 마지막 업데이트 시간 설정
  void _setLastUpdated(DateTime dateTime) {
    _lastUpdated = dateTime;
    notifyListeners();
  }

  // ================================
  // Phase 2.3: Optimistic Updates 관리 메서드들
  // ================================

  /// Optimistic Update 상태 설정
  void _setOptimisticUpdate(bool isOptimistic) {
    if (_isOptimisticUpdate != isOptimistic) {
      _isOptimisticUpdate = isOptimistic;
      notifyListeners();
    }
  }

  /// Optimistic Floor Info 설정
  void _setOptimisticFloorInfo(ParkingFloorInfo floorInfo) {
    _optimisticFloorInfo = floorInfo;
    notifyListeners();
  }

  /// 임시 층 정보 설정 (앱 시작 시 마지막 주차 층 표시용)
  void setTemporaryFloorInfo(ParkingFloorInfo floorInfo) {
    _currentFloorInfo = floorInfo;
    _setLastUpdated(DateTime.now());

    if (kDebugMode) {
      debugPrint('[VehicleLocationProvider] 임시 층 정보 설정: ${floorInfo.floor}');
    }

    notifyListeners();
  }

  /// Optimistic Update 해제
  void _clearOptimisticUpdate() {
    if (_isOptimisticUpdate) {
      _isOptimisticUpdate = false;
      _optimisticFloorInfo = null;
      notifyListeners();
    }
  }

  /// Optimistic Update 롤백 (이전 상태로 복원)
  void _rollbackOptimisticUpdate() {
    if (_isOptimisticUpdate) {
      _isOptimisticUpdate = false;
      _optimisticFloorInfo = null;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] Optimistic Update 롤백 완료');
      }
    }
  }

  /// 상태 초기화 (다중 차량 상태 포함)
  void clearState() {
    // 단일 차량 상태 초기화
    _currentFloorInfo = null;
    _isLocationLoading = false;
    _locationError = null;
    _lastUpdated = null;

    // 다중 차량 상태 초기화
    _multipleFloorInfoList = null;
    _selectedVehicleIndex = 1;
    _isMultipleVehicleMode = false;

    // Phase 2.3: Optimistic Updates 상태도 초기화
    _isOptimisticUpdate = false;
    _optimisticFloorInfo = null;

    notifyListeners();
  }

  /// 캐시된 데이터 유효성 검사
  bool get isCacheValid {
    if (_lastUpdated == null) return false;

    final now = DateTime.now();
    final difference = now.difference(_lastUpdated!);

    // 3분 이내의 데이터는 유효한 것으로 간주
    return difference.inMinutes < 3;
  }

  /// 현재 주차 중인지 여부 (Optimistic Update 고려)
  bool get isCurrentlyParked {
    final floorInfo = currentFloorInfo; // optimistic update가 적용된 데이터 사용
    return floorInfo != null &&
        floorInfo.floor != '출차됨' &&
        floorInfo.floor.isNotEmpty;
  }

  /// 위치 정보 상태 요약 (다중 차량 지원)
  String get locationStatusSummary {
    if (_isLocationLoading) return '위치 확인 중...';
    if (_locationError != null) return '오류: ${_locationError!.userMessage}';

    final floorInfo = currentFloorInfo; // optimistic update 및 선택된 차량 고려
    if (floorInfo == null) return '위치 정보 없음';

    String status = '';
    if (isCurrentlyParked) {
      status = '${floorInfo.floor}층에 주차됨';
      
      // 다중 차량인 경우 차량 정보 표시
      if (_isMultipleVehicleMode && hasMultipleVehicles) {
        status += ' (${floorInfo.displayName})';
      }
    } else {
      status = '출차 상태';
    }

    // Phase 2.3: Optimistic Update 표시
    if (_isOptimisticUpdate) {
      status += ' (업데이트 중...)';
    }

    return status;
  }
  
  // ================================
  // 다중 차량 관리 헬퍼 메서드들
  // ================================
  
  /// 선택된 차량 정보 가져오기
  ParkingFloorInfo? _getSelectedVehicle() {
    if (_multipleFloorInfoList == null || _multipleFloorInfoList!.isEmpty) {
      return null;
    }
    
    // 인덱스 유효성 검사 (1-based 인덱스)
    if (_selectedVehicleIndex < 1 || _selectedVehicleIndex > _multipleFloorInfoList!.length) {
      return null;
    }
    
    // 0-based 인덱스로 변환
    return _multipleFloorInfoList![_selectedVehicleIndex - 1];
  }
  
  
  /// 다중 차량 리스트 설정
  void _setMultipleFloorInfoList(List<ParkingFloorInfo> vehicleList) {
    _multipleFloorInfoList = List.from(vehicleList); // 복사본 생성
    notifyListeners();
  }
  
  /// 다중 차량 모드 설정
  void _setMultipleVehicleMode(bool isMultipleMode) {
    if (_isMultipleVehicleMode != isMultipleMode) {
      final previousMode = _isMultipleVehicleMode;
      _isMultipleVehicleMode = isMultipleMode;
      notifyListeners();
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 다중 차량 모드 변경: $previousMode → $isMultipleMode (hasMultipleVehicles: $hasMultipleVehicles)');
      }
    }
  }
  
  /// 선택된 차량 인덱스 설정
  void _setSelectedVehicleIndex(int index) {
    if (_selectedVehicleIndex != index) {
      _selectedVehicleIndex = index;
      notifyListeners();
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 선택된 차량 인덱스: $index');
      }
    }
  }
  
  /// 이전 선택된 차량 인덱스 복원 (HomeWidgetService + PreferencesService)
  Future<void> _restoreSelectedVehicleIndex(int vehicleCount) async {
    try {
      int savedIndex = 1; // 기본값
      
      // 1차: HomeWidgetService에서 복원 시도
      try {
        savedIndex = await HomeWidgetService.getSelectedVehicleIndex();
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] HomeWidgetService에서 차량 인덱스 복원: $savedIndex');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] HomeWidgetService 복원 실패: $e');
        }
        
        // 2차: PreferencesService에서 복원 시도 (fallback)
        try {
          savedIndex = _preferencesService.getSelectedVehicleIndex();
          if (kDebugMode) {
            debugPrint('[VehicleLocationProvider] PreferencesService에서 차량 인덱스 복원: $savedIndex');
          }
        } catch (prefError) {
          if (kDebugMode) {
            debugPrint('[VehicleLocationProvider] PreferencesService 복원도 실패: $prefError');
          }
        }
      }
      
      // 유효한 인덱스 범위인지 확인
      if (savedIndex >= 1 && savedIndex <= vehicleCount) {
        _setSelectedVehicleIndex(savedIndex);
        
        // 양쪽 서비스에 동기화
        await _syncSelectedVehicleIndex(savedIndex);
        
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 차량 인덱스 복원 완료: $savedIndex');
        }
      } else {
        // 유효하지 않은 경우 기본값 설정
        _setSelectedVehicleIndex(1);
        await _syncSelectedVehicleIndex(1);
        
        if (kDebugMode) {
          debugPrint('[VehicleLocationProvider] 유효하지 않은 저장된 인덱스 ($savedIndex), 기본값(1) 설정');
        }
      }
    } catch (e) {
      // 모든 복원 시도 실패 시 기본값 설정
      _setSelectedVehicleIndex(1);
      await _syncSelectedVehicleIndex(1);
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 차량 인덱스 복원 완전 실패, 기본값(1) 설정: $e');
      }
    }
  }
  
  /// 선택된 차량 인덱스를 양쪽 서비스에 동기화
  Future<void> _syncSelectedVehicleIndex(int vehicleIndex) async {
    try {
      await Future.wait([
        HomeWidgetService.saveSelectedVehicleIndex(vehicleIndex),
        _preferencesService.saveSelectedVehicleIndex(vehicleIndex),
      ]);
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 차량 인덱스 동기화 완료: $vehicleIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationProvider] 차량 인덱스 동기화 실패: $e');
      }
    }
  }
}
