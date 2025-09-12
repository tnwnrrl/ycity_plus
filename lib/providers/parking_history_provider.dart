import 'package:flutter/foundation.dart';
import '../models/parking_history.dart';
import '../models/user_info.dart';
import '../services/parking_history_service.dart';

/// 주차 이력 상태 관리 Provider
class ParkingHistoryProvider extends ChangeNotifier {
  final ParkingHistoryService _parkingHistoryService;

  // 상태 변수들
  List<ParkingHistory> _parkingHistory = [];
  ParkingStatistics? _statistics;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;

  // 생성자
  ParkingHistoryProvider({
    ParkingHistoryService? parkingHistoryService,
  }) : _parkingHistoryService =
            parkingHistoryService ?? ParkingHistoryService();

  // Getters
  List<ParkingHistory> get parkingHistory => List.unmodifiable(_parkingHistory);
  ParkingStatistics? get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasHistory => _parkingHistory.isNotEmpty;

  /// 주차 이력 로드
  Future<void> loadParkingHistory(UserInfo userInfo) async {
    _setLoading(true);

    try {
      final history = await _parkingHistoryService.getParkingHistory(
        dong: userInfo.dong,
        ho: userInfo.ho,
        serialNumber: userInfo.serialNumber,
      );

      _parkingHistory = history;
      _setLastUpdated(DateTime.now());
      _clearError();

      // 통계 계산
      await _calculateStatistics(userInfo);

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 주차 이력 로드 완료: ${history.length}건');
      }
    } catch (e) {
      _setError('주차 이력 로드 실패: $e');

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 주차 이력 로드 오류: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// 통계 계산
  Future<void> _calculateStatistics(UserInfo userInfo) async {
    try {
      final stats = await _parkingHistoryService.getParkingStatistics(
        dong: userInfo.dong,
        ho: userInfo.ho,
        serialNumber: userInfo.serialNumber,
      );

      _statistics = stats;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 통계 계산 완료: $stats');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 통계 계산 오류: $e');
      }
    }
  }

  /// 주차 이력 새로고침
  Future<void> refreshParkingHistory(UserInfo userInfo) async {
    return loadParkingHistory(userInfo);
  }

  /// 특정 기간의 주차 이력 조회
  Future<void> loadParkingHistoryByDateRange({
    required UserInfo userInfo,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _setLoading(true);

    try {
      // 날짜 범위 필터링은 로컬에서 처리
      final allHistory = await _parkingHistoryService.getParkingHistory(
        dong: userInfo.dong,
        ho: userInfo.ho,
        serialNumber: userInfo.serialNumber,
      );

      final filteredHistory = allHistory.where((history) {
        return history.entryTime
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            history.entryTime.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      _parkingHistory = filteredHistory;
      _setLastUpdated(DateTime.now());
      _clearError();

      if (kDebugMode) {
        debugPrint(
            '[ParkingHistoryProvider] 기간별 주차 이력 로드 완료: ${filteredHistory.length}건');
      }
    } catch (e) {
      _setError('기간별 주차 이력 로드 실패: $e');

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 기간별 주차 이력 로드 오류: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// 수동 주차 이력 추가 (현재 서비스에서 지원하지 않음)
  Future<bool> addManualParkingHistory({
    required UserInfo userInfo,
    required String floor,
    required DateTime entryTime,
    DateTime? exitTime,
    String? notes,
  }) async {
    try {
      // 현재 ParkingHistoryService에는 수동 추가 기능이 없으므로
      // 향후 구현 예정으로 false 반환
      _setError('수동 주차 이력 추가 기능은 향후 지원 예정입니다');

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 수동 주차 이력 추가 기능 미지원');
      }

      return false;
    } catch (e) {
      _setError('수동 주차 이력 추가 실패: $e');

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 수동 주차 이력 추가 오류: $e');
      }

      return false;
    }
  }

  /// 주차 이력 삭제
  Future<bool> deleteParkingHistory(int historyId, UserInfo userInfo) async {
    try {
      final success =
          await _parkingHistoryService.deleteParkingHistory(historyId);

      if (success) {
        // 로컬 리스트에서 제거
        _parkingHistory.removeWhere((history) => history.id == historyId);

        // 통계 재계산
        await _calculateStatistics(userInfo);

        if (kDebugMode) {
          debugPrint('[ParkingHistoryProvider] 주차 이력 삭제 완료: $historyId');
        }
      }

      return success;
    } catch (e) {
      _setError('주차 이력 삭제 실패: $e');

      if (kDebugMode) {
        debugPrint('[ParkingHistoryProvider] 주차 이력 삭제 오료: $e');
      }

      return false;
    }
  }

  /// 마지막 주차 층 정보 조회 (출차하지 않은 가장 최근 주차 이력)
  String? getLastParkedFloor() {
    if (_parkingHistory.isEmpty) {
      return null;
    }

    // 현재 주차 중인 이력 찾기 (status가 parked이고 exitTime이 null인 것)
    final currentParking = _parkingHistory
        .where((history) =>
            history.status == ParkingStatus.parked && history.exitTime == null)
        .toList();

    if (currentParking.isNotEmpty) {
      // 가장 최근 주차 이력의 층 정보 반환
      currentParking.sort((a, b) => b.entryTime.compareTo(a.entryTime));
      return currentParking.first.floor;
    }

    return null;
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 오류 상태 설정
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// 오류 상태 초기화
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// 마지막 업데이트 시간 설정
  void _setLastUpdated(DateTime dateTime) {
    _lastUpdated = dateTime;
    notifyListeners();
  }

  /// 상태 초기화
  void clearState() {
    _parkingHistory.clear();
    _statistics = null;
    _isLoading = false;
    _error = null;
    _lastUpdated = null;
    notifyListeners();
  }

  /// 현재 주차 중인 이력 가져오기
  ParkingHistory? get currentParkingSession {
    try {
      return _parkingHistory.firstWhere(
        (history) =>
            history.status == ParkingStatus.parked && history.exitTime == null,
      );
    } catch (e) {
      return null;
    }
  }

  /// 특정 층의 주차 횟수
  int getParkingCountByFloor(String floor) {
    return _parkingHistory.where((history) => history.floor == floor).length;
  }

  /// 월별 주차 횟수
  Map<String, int> getMonthlyParkingCount() {
    final monthlyCount = <String, int>{};

    for (final history in _parkingHistory) {
      final monthKey =
          '${history.entryTime.year}-${history.entryTime.month.toString().padLeft(2, '0')}';
      monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
    }

    return monthlyCount;
  }

  /// 최근 주차 이력 (최대 10개)
  List<ParkingHistory> get recentParkingHistory {
    final sorted = List<ParkingHistory>.from(_parkingHistory);
    sorted.sort((a, b) => b.entryTime.compareTo(a.entryTime));
    return sorted.take(10).toList();
  }

  /// 평균 주차 시간 (분)
  double get averageParkingTimeInMinutes {
    final completedSessions =
        _parkingHistory.where((history) => history.exitTime != null).toList();

    if (completedSessions.isEmpty) return 0.0;

    final totalMinutes = completedSessions
        .map((history) => history.parkingDurationMinutes)
        .fold(0, (sum, minutes) => sum + minutes);

    return totalMinutes / completedSessions.length;
  }

  /// 가장 자주 사용하는 층
  String? get mostUsedFloor {
    if (_parkingHistory.isEmpty) return null;

    final floorCount = <String, int>{};
    for (final history in _parkingHistory) {
      floorCount[history.floor] = (floorCount[history.floor] ?? 0) + 1;
    }

    return floorCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
