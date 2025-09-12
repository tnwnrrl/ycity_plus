import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  // SharedPreferences 초기화 (개선된 에러 처리)
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _log('PreferencesService 초기화 완료');
    } catch (e) {
      _log('PreferencesService 초기화 중 오류 발생: $e');
      // 초기화 실패 시 재시도
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        _prefs = await SharedPreferences.getInstance();
        _log('PreferencesService 재시도 초기화 성공');
      } catch (retryError) {
        _log('PreferencesService 재시도 초기화 실패: $retryError');
        rethrow;
      }
    }
  }

  // 키 상수 정의
  static const String _keyDong = 'user_dong';
  static const String _keyHo = 'user_ho';
  static const String _keySerialNumber = 'user_serial_number';
  static const String _keyLastSavedTime = 'last_saved_time';
  static const String _keyLastParkedFloor = 'last_parked_floor';
  static const String _keyLastParkedTime = 'last_parked_time';
  
  // 다중 차량 지원을 위한 키들
  static const String _keySelectedVehicleIndex = 'selected_vehicle_index';
  static const String _keyVehicleCount = 'vehicle_count';
  static const String _keyMultipleVehicleMode = 'multiple_vehicle_mode';

  // 에러 메시지 상수
  static const String _saveErrorPrefix = '저장 중 오류 발생';
  static const String _loadErrorPrefix = '불러오기 중 오류 발생';

  // 동 정보 저장/불러오기
  Future<void> saveDong(String dong) async {
    try {
      await _prefs?.setString(_keyDong, dong);
      _log('동 정보 저장: $dong');
    } catch (e) {
      _log('$_saveErrorPrefix(동): $e');
    }
  }

  String? getDong() {
    try {
      return _prefs?.getString(_keyDong);
    } catch (e) {
      _log('$_loadErrorPrefix(동): $e');
      return null;
    }
  }

  // 호 정보 저장/불러오기
  Future<void> saveHo(String ho) async {
    try {
      await _prefs?.setString(_keyHo, ho);
      _log('호 정보 저장: $ho');
    } catch (e) {
      _log('$_saveErrorPrefix(호): $e');
    }
  }

  String? getHo() {
    try {
      return _prefs?.getString(_keyHo);
    } catch (e) {
      _log('$_loadErrorPrefix(호): $e');
      return null;
    }
  }

  // 시리얼넘버 저장/불러오기
  Future<void> saveSerialNumber(String serialNumber) async {
    try {
      await _prefs?.setString(_keySerialNumber, serialNumber);
      _log('시리얼넘버 저장: $serialNumber');
    } catch (e) {
      _log('$_saveErrorPrefix(시리얼넘버): $e');
    }
  }

  String? getSerialNumber() {
    try {
      return _prefs?.getString(_keySerialNumber);
    } catch (e) {
      _log('$_loadErrorPrefix(시리얼넘버): $e');
      return null;
    }
  }

  // 마지막 저장 시간 저장/불러오기
  Future<void> saveLastSavedTime() async {
    try {
      await _prefs?.setString(
          _keyLastSavedTime, DateTime.now().toIso8601String());
      _log('마지막 저장 시간 업데이트');
    } catch (e) {
      _log('마지막 저장 시간 저장 중 오류 발생: $e');
    }
  }

  DateTime? getLastSavedTime() {
    try {
      final timeString = _prefs?.getString(_keyLastSavedTime);
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
      return null;
    } catch (e) {
      _log('마지막 저장 시간 불러오기 중 오류 발생: $e');
      return null;
    }
  }

  // 모든 사용자 정보 한번에 저장
  Future<void> saveAllUserInfo({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    try {
      await Future.wait([
        saveDong(dong),
        saveHo(ho),
        saveSerialNumber(serialNumber),
        saveLastSavedTime(),
      ]);
      _log('모든 사용자 정보 저장 완료');
    } catch (e) {
      _log('사용자 정보 저장 중 오류 발생: $e');
      rethrow;
    }
  }

  // 모든 사용자 정보 한번에 불러오기
  Map<String, String?> getAllUserInfo() {
    try {
      return {
        'dong': getDong(),
        'ho': getHo(),
        'serialNumber': getSerialNumber(),
      };
    } catch (e) {
      _log('사용자 정보 불러오기 중 오류 발생: $e');
      return {
        'dong': null,
        'ho': null,
        'serialNumber': null,
      };
    }
  }

  // 저장된 정보가 있는지 확인
  bool hasUserInfo() {
    try {
      final dong = getDong();
      final ho = getHo();
      final serialNumber = getSerialNumber();

      return dong != null &&
          ho != null &&
          serialNumber != null &&
          dong.isNotEmpty &&
          ho.isNotEmpty &&
          serialNumber.isNotEmpty;
    } catch (e) {
      _log('사용자 정보 존재 여부 확인 중 오류 발생: $e');
      return false;
    }
  }

  // 특정 필드가 저장되어 있는지 확인
  bool hasDong() => getDong()?.isNotEmpty ?? false;
  bool hasHo() => getHo()?.isNotEmpty ?? false;
  bool hasSerialNumber() => getSerialNumber()?.isNotEmpty ?? false;

  // 마지막 주차 층 정보 저장/불러오기
  Future<void> saveLastParkedFloor(String floor) async {
    try {
      await Future.wait([
        _prefs?.setString(_keyLastParkedFloor, floor) ?? Future.value(),
        _prefs?.setString(
                _keyLastParkedTime, DateTime.now().toIso8601String()) ??
            Future.value(),
      ]);
      _log('마지막 주차 층 정보 저장: $floor');
    } catch (e) {
      _log('마지막 주차 층 정보 저장 중 오류 발생: $e');
    }
  }

  String? getLastParkedFloor() {
    try {
      return _prefs?.getString(_keyLastParkedFloor);
    } catch (e) {
      _log('마지막 주차 층 정보 불러오기 중 오류 발생: $e');
      return null;
    }
  }

  DateTime? getLastParkedTime() {
    try {
      final timeString = _prefs?.getString(_keyLastParkedTime);
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
      return null;
    } catch (e) {
      _log('마지막 주차 시간 불러오기 중 오류 발생: $e');
      return null;
    }
  }

  // 마지막 주차 정보가 있는지 확인
  bool hasLastParkedFloor() {
    return getLastParkedFloor()?.isNotEmpty ?? false;
  }

  // 선택된 차량 인덱스 저장/불러오기 (다중 차량 지원)
  Future<void> saveSelectedVehicleIndex(int vehicleIndex) async {
    try {
      await _prefs?.setInt(_keySelectedVehicleIndex, vehicleIndex);
      _log('선택된 차량 인덱스 저장: $vehicleIndex');
    } catch (e) {
      _log('$_saveErrorPrefix(차량 인덱스): $e');
    }
  }

  int getSelectedVehicleIndex() {
    try {
      return _prefs?.getInt(_keySelectedVehicleIndex) ?? 1; // 기본값: 1 (첫 번째 차량)
    } catch (e) {
      _log('$_loadErrorPrefix(차량 인덱스): $e');
      return 1; // 오류 시 기본값 반환
    }
  }

  // 차량 개수 저장/불러오기
  Future<void> saveVehicleCount(int count) async {
    try {
      await _prefs?.setInt(_keyVehicleCount, count);
      _log('차량 개수 저장: $count');
    } catch (e) {
      _log('$_saveErrorPrefix(차량 개수): $e');
    }
  }

  int getVehicleCount() {
    try {
      return _prefs?.getInt(_keyVehicleCount) ?? 0; // 기본값: 0
    } catch (e) {
      _log('$_loadErrorPrefix(차량 개수): $e');
      return 0; // 오류 시 기본값 반환
    }
  }

  // 다중 차량 모드 상태 저장/불러오기
  Future<void> saveMultipleVehicleMode(bool isMultipleMode) async {
    try {
      await _prefs?.setBool(_keyMultipleVehicleMode, isMultipleMode);
      _log('다중 차량 모드 저장: $isMultipleMode');
    } catch (e) {
      _log('$_saveErrorPrefix(다중 차량 모드): $e');
    }
  }

  bool getMultipleVehicleMode() {
    try {
      return _prefs?.getBool(_keyMultipleVehicleMode) ?? false; // 기본값: false
    } catch (e) {
      _log('$_loadErrorPrefix(다중 차량 모드): $e');
      return false; // 오류 시 기본값 반환
    }
  }

  // 선택된 차량 인덱스가 유효한지 확인
  bool isValidVehicleIndex(int vehicleIndex) {
    final vehicleCount = getVehicleCount();
    return vehicleIndex >= 1 && vehicleIndex <= vehicleCount;
  }

  // 다중 차량 관련 정보 모두 저장
  Future<void> saveMultipleVehicleInfo({
    required int selectedVehicleIndex,
    required int vehicleCount,
    required bool isMultipleMode,
  }) async {
    try {
      await Future.wait([
        saveSelectedVehicleIndex(selectedVehicleIndex),
        saveVehicleCount(vehicleCount),
        saveMultipleVehicleMode(isMultipleMode),
      ]);
      _log('다중 차량 정보 저장 완료: 선택=$selectedVehicleIndex, 개수=$vehicleCount, 다중모드=$isMultipleMode');
    } catch (e) {
      _log('다중 차량 정보 저장 중 오류 발생: $e');
      rethrow;
    }
  }

  // 다중 차량 관련 정보 불러오기
  Map<String, dynamic> getMultipleVehicleInfo() {
    try {
      return {
        'selectedVehicleIndex': getSelectedVehicleIndex(),
        'vehicleCount': getVehicleCount(),
        'isMultipleMode': getMultipleVehicleMode(),
      };
    } catch (e) {
      _log('다중 차량 정보 불러오기 중 오류 발생: $e');
      return {
        'selectedVehicleIndex': 1,
        'vehicleCount': 0,
        'isMultipleMode': false,
      };
    }
  }

  // 모든 저장된 정보 삭제 (다중 차량 정보 포함)
  Future<void> clearAllUserInfo() async {
    try {
      await Future.wait([
        _prefs?.remove(_keyDong) ?? Future.value(),
        _prefs?.remove(_keyHo) ?? Future.value(),
        _prefs?.remove(_keySerialNumber) ?? Future.value(),
        _prefs?.remove(_keyLastSavedTime) ?? Future.value(),
        _prefs?.remove(_keyLastParkedFloor) ?? Future.value(),
        _prefs?.remove(_keyLastParkedTime) ?? Future.value(),
        // 다중 차량 정보도 삭제
        _prefs?.remove(_keySelectedVehicleIndex) ?? Future.value(),
        _prefs?.remove(_keyVehicleCount) ?? Future.value(),
        _prefs?.remove(_keyMultipleVehicleMode) ?? Future.value(),
      ]);
      _log('모든 사용자 정보 삭제 완료 (다중 차량 정보 포함)');
    } catch (e) {
      _log('사용자 정보 삭제 중 오류 발생: $e');
    }
  }

  // 유효한 동 번호 목록 (성능 최적화를 위한 상수)
  static const List<String> _validDongNumbers = [
    '101',
    '102',
    '103',
    '104',
    '105',
    '106'
  ];

  List<String> getValidDongNumbers() => _validDongNumbers;

  // 동 번호 유효성 검사 (최적화)
  bool isValidDong(String? dong) {
    if (dong == null || dong.isEmpty) return false;
    return _validDongNumbers.contains(dong);
  }

  // 호수 유효성 검사
  bool isValidHo(String? ho) {
    if (ho == null || ho.isEmpty) return false;
    final hoNumber = int.tryParse(ho);
    return hoNumber != null && hoNumber > 0;
  }

  // 시리얼넘버 유효성 검사
  bool isValidSerialNumber(String? serialNumber) {
    return serialNumber != null && serialNumber.trim().isNotEmpty;
  }

  // 모든 입력값 유효성 검사
  bool isAllInputValid(String? dong, String? ho, String? serialNumber) {
    return isValidDong(dong) &&
        isValidHo(ho) &&
        isValidSerialNumber(serialNumber);
  }

  // 데이터 백업 (Map 형태로 반환)
  Map<String, dynamic> backupPreferences() {
    try {
      return {
        'dong': getDong(),
        'ho': getHo(),
        'serialNumber': getSerialNumber(),
        'lastSavedTime': getLastSavedTime()?.toIso8601String(),
        'backupTime': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _log('설정 백업 중 오류 발생: $e');
      return {};
    }
  }

  // 데이터 복원
  Future<bool> restorePreferences(Map<String, dynamic> data) async {
    try {
      if (data['dong'] != null) await saveDong(data['dong']);
      if (data['ho'] != null) await saveHo(data['ho']);
      if (data['serialNumber'] != null) {
        await saveSerialNumber(data['serialNumber']);
      }

      _log('설정 복원 완료');
      return true;
    } catch (e) {
      _log('설정 복원 중 오류 발생: $e');
      return false;
    }
  }

  // 정수 값 저장/불러오기 (for timestamp, counters, etc.)
  Future<void> setInt(String key, int value) async {
    try {
      await _prefs?.setInt(key, value);
      _log('정수 값 저장: $key = $value');
    } catch (e) {
      _log('정수 값 저장 중 오류 발생 ($key): $e');
    }
  }

  int? getInt(String key) {
    try {
      return _prefs?.getInt(key);
    } catch (e) {
      _log('정수 값 불러오기 중 오류 발생 ($key): $e');
      return null;
    }
  }

  // 디버그 로깅
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[PreferencesService] $message');
    }
  }

  // 서비스 상태 정보 (다중 차량 정보 포함)
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _prefs != null,
      'hasUserInfo': hasUserInfo(),
      'lastSavedTime': getLastSavedTime()?.toIso8601String(),
      'dong': getDong(),
      'ho': getHo(),
      'serialNumberLength': getSerialNumber()?.length ?? 0,
      // 다중 차량 상태 정보
      'selectedVehicleIndex': getSelectedVehicleIndex(),
      'vehicleCount': getVehicleCount(),
      'isMultipleVehicleMode': getMultipleVehicleMode(),
      'hasLastParkedFloor': hasLastParkedFloor(),
      'lastParkedFloor': getLastParkedFloor(),
    };
  }
}
