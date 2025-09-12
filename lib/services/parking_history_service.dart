import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/parking_history.dart';
import '../models/parking_floor_info.dart';

/// 주차 이력 관리 서비스
class ParkingHistoryService {
  static final ParkingHistoryService _instance =
      ParkingHistoryService._internal();
  factory ParkingHistoryService() => _instance;
  ParkingHistoryService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // 현재 주차 상태 캐시
  ParkingHistory? _currentParkingHistory;

  /// 현재 주차 중인 이력
  ParkingHistory? get currentParkingHistory => _currentParkingHistory;

  /// 현재 주차 중인지 확인
  bool get isCurrentlyParked =>
      _currentParkingHistory?.isCurrentlyParked ?? false;

  /// 서비스 초기화
  Future<void> initialize() async {
    try {
      _log('ParkingHistoryService 초기화 시작');
      // 초기화 시에는 현재 주차 상태를 로드하지 않음 (필요시 별도 호출)
      _log('ParkingHistoryService 초기화 완료');
    } catch (e) {
      _log('ParkingHistoryService 초기화 중 오류 발생: $e');
    }
  }

  /// 현재 주차 상태 로드
  Future<void> loadCurrentParkingStatus({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    try {
      _currentParkingHistory = await _databaseHelper.getCurrentParkingHistory(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
      );

      if (_currentParkingHistory != null) {
        _log('현재 주차 중인 이력 로드: ${_currentParkingHistory!.floor}층');
      } else {
        _log('현재 주차 중인 이력 없음');
      }
    } catch (e) {
      _log('현재 주차 상태 로드 중 오류 발생: $e');
      _currentParkingHistory = null;
    }
  }

  /// 새로운 주차 이벤트 처리
  Future<bool> handleParkingEvent(ParkingFloorInfo floorInfo) async {
    try {
      // 출차됨 상태 처리
      if (floorInfo.floor == '출차됨') {
        return await _handleDepartureEvent(floorInfo);
      }

      // 실제 층 정보가 있는 경우 입차 처리
      if (_isValidFloor(floorInfo.floor)) {
        return await _handleArrivalEvent(floorInfo);
      }

      _log('알 수 없는 층 정보: ${floorInfo.floor}');
      return false;
    } catch (e) {
      _log('주차 이벤트 처리 중 오류 발생: $e');
      return false;
    }
  }

  /// 입차 이벤트 처리
  Future<bool> _handleArrivalEvent(ParkingFloorInfo floorInfo) async {
    try {
      // 기존에 주차 중인 이력이 있으면 먼저 출차 처리
      if (_currentParkingHistory != null &&
          _currentParkingHistory!.isCurrentlyParked) {
        // 같은 층에 이미 주차 중이면 무시
        if (_currentParkingHistory!.floor == floorInfo.floor) {
          _log('이미 ${floorInfo.floor}층에 주차 중 - 중복 입차 이벤트 무시');
          return true;
        }

        // 다른 층으로 이동한 경우 기존 주차 완료 처리
        await _finalizeParkingHistory(_currentParkingHistory!);
      }

      // 새로운 주차 이력 생성
      final newHistory = ParkingHistory.createEntry(
        dong: floorInfo.dong,
        ho: floorInfo.ho,
        serialNumber: floorInfo.serialNumber,
        floor: floorInfo.floor,
        entryTime: floorInfo.lastUpdated,
        notes: '자동 감지된 입차',
      );

      final id = await _databaseHelper.insertParkingHistory(newHistory);
      if (id > 0) {
        _currentParkingHistory = newHistory.copyWith(id: id);
        _log('새로운 주차 이력 생성: ${floorInfo.floor}층 (ID: $id)');
        return true;
      }

      return false;
    } catch (e) {
      _log('입차 이벤트 처리 중 오류 발생: $e');
      return false;
    }
  }

  /// 출차 이벤트 처리
  Future<bool> _handleDepartureEvent(ParkingFloorInfo floorInfo) async {
    try {
      if (_currentParkingHistory == null ||
          !_currentParkingHistory!.isCurrentlyParked) {
        _log('출차 이벤트 감지되었으나 주차 중인 이력이 없음');
        return true; // 오류는 아니므로 true 반환
      }

      // 현재 주차 이력을 출차 완료로 업데이트
      await _finalizeParkingHistory(_currentParkingHistory!,
          exitTime: floorInfo.lastUpdated);
      return true;
    } catch (e) {
      _log('출차 이벤트 처리 중 오류 발생: $e');
      return false;
    }
  }

  /// 주차 이력 완료 처리 (출차 시간 기록) - 1시간 미만 필터링 포함
  Future<void> _finalizeParkingHistory(ParkingHistory history,
      {DateTime? exitTime}) async {
    try {
      final completedHistory = history.markAsExited(
        exitTime: exitTime,
        notes: '자동 감지된 출차',
      );

      // 1시간 미만 주차는 노이즈 데이터로 간주하여 삭제
      final parkingDurationMinutes = completedHistory.parkingDurationMinutes;
      const minValidParkingMinutes = 60; // 1시간 = 60분

      if (parkingDurationMinutes < minValidParkingMinutes) {
        _log(
            '짧은 주차 감지 ($parkingDurationMinutes분) - 노이즈 데이터로 간주하여 이력 삭제: ${history.floor}층');

        // DB에서 해당 이력 삭제
        await _databaseHelper.deleteParkingHistory(history.id!);
        _log('짧은 주차 이력 삭제 완료: ${history.floor}층 ($parkingDurationMinutes분)');
      } else {
        // 1시간 이상 주차는 정상 처리
        final updatedRows =
            await _databaseHelper.updateParkingHistory(completedHistory);
        if (updatedRows > 0) {
          _log(
              '주차 이력 완료 처리: ${history.floor}층, 주차시간: ${completedHistory.parkingDurationText}');
        }
      }

      _currentParkingHistory = null; // 현재 주차 상태 초기화
    } catch (e) {
      _log('주차 이력 완료 처리 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 주차 이력 조회
  Future<List<ParkingHistory>> getParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
    int? limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _databaseHelper.getParkingHistory(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _log('주차 이력 조회 중 오류 발생: $e');
      return [];
    }
  }

  /// 주차 통계 조회
  Future<ParkingStatistics> getParkingStatistics({
    required String dong,
    required String ho,
    required String serialNumber,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final history = await getParkingHistory(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        startDate: startDate,
        endDate: endDate,
      );

      return ParkingStatistics.fromHistory(history);
    } catch (e) {
      _log('주차 통계 조회 중 오류 발생: $e');
      return ParkingStatistics.empty();
    }
  }

  /// 기존 1시간 미만 주차 이력 정리 (유지보수용)
  Future<int> cleanupShortParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    try {
      _log('1시간 미만 주차 이력 정리 시작');

      // 모든 완료된 주차 이력 조회
      final allHistory = await getParkingHistory(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
      );

      int deletedCount = 0;
      const minValidParkingMinutes = 60; // 1시간 = 60분

      for (final history in allHistory) {
        // 출차 완료된 이력만 체크
        if (history.status == ParkingStatus.exited &&
            history.parkingDurationMinutes < minValidParkingMinutes) {
          await _databaseHelper.deleteParkingHistory(history.id!);
          deletedCount++;

          _log(
              '짧은 주차 이력 삭제: ${history.floor}층 (${history.parkingDurationMinutes}분)');
        }
      }

      _log('1시간 미만 주차 이력 정리 완료: $deletedCount개 삭제');
      return deletedCount;
    } catch (e) {
      _log('1시간 미만 주차 이력 정리 중 오류 발생: $e');
      return 0;
    }
  }

  /// 층별 사용 통계 조회
  Future<Map<String, int>> getFloorUsageStatistics({
    required String dong,
    required String ho,
    required String serialNumber,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _databaseHelper.getFloorUsageStatistics(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _log('층별 사용 통계 조회 중 오류 발생: $e');
      return {};
    }
  }

  /// 특정 주차 이력 삭제
  Future<bool> deleteParkingHistory(int id) async {
    try {
      final deletedRows = await _databaseHelper.deleteParkingHistory(id);
      if (deletedRows > 0) {
        _log('주차 이력 삭제 완료: ID $id');

        // 삭제된 이력이 현재 주차 이력이면 초기화
        if (_currentParkingHistory?.id == id) {
          _currentParkingHistory = null;
        }

        return true;
      }
      return false;
    } catch (e) {
      _log('주차 이력 삭제 중 오류 발생: $e');
      return false;
    }
  }

  /// 수동으로 주차 이력 추가
  Future<bool> addManualParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
    required String floor,
    required DateTime entryTime,
    DateTime? exitTime,
    String? notes,
  }) async {
    try {
      ParkingHistory history = ParkingHistory.createEntry(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        floor: floor,
        entryTime: entryTime,
        notes: notes ?? '수동 입력',
      );

      // 출차 시간이 있으면 완료된 이력으로 생성
      if (exitTime != null) {
        history =
            history.markAsExited(exitTime: exitTime, notes: notes ?? '수동 입력');
      }

      final id = await _databaseHelper.insertParkingHistory(history);
      if (id > 0) {
        _log('수동 주차 이력 추가 완료: $floor층 (ID: $id)');

        // 현재 주차 중인 이력이면 캐시 업데이트
        if (exitTime == null) {
          _currentParkingHistory = history.copyWith(id: id);
        }

        return true;
      }
      return false;
    } catch (e) {
      _log('수동 주차 이력 추가 중 오류 발생: $e');
      return false;
    }
  }

  /// 유효한 층인지 확인
  bool _isValidFloor(String floor) {
    const validFloors = ['B1', 'B2', 'B3', 'B4'];
    return validFloors.contains(floor.toUpperCase());
  }

  /// 주차 이력이 있는지 확인
  Future<bool> hasAnyParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    try {
      final history = await getParkingHistory(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        limit: 1,
      );
      return history.isNotEmpty;
    } catch (e) {
      _log('주차 이력 존재 여부 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// 오늘의 주차 이력 조회
  Future<List<ParkingHistory>> getTodayParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getParkingHistory(
      dong: dong,
      ho: ho,
      serialNumber: serialNumber,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// 이번 달 주차 이력 조회
  Future<List<ParkingHistory>> getThisMonthParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    return await getParkingHistory(
      dong: dong,
      ho: ho,
      serialNumber: serialNumber,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
  }

  /// 디버그 로깅
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ParkingHistoryService] $message');
    }
  }

  /// 서비스 정리
  Future<void> dispose() async {
    try {
      _currentParkingHistory = null;
      _log('ParkingHistoryService 정리 완료');
    } catch (e) {
      _log('ParkingHistoryService 정리 중 오류 발생: $e');
    }
  }
}
