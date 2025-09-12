// Parking history model for tracking vehicle parking patterns

/// 주차 이력 모델
class ParkingHistory {
  final int? id;
  final String dong;
  final String ho;
  final String serialNumber;
  final String floor;
  final DateTime entryTime;
  final DateTime? exitTime;
  final Duration? parkingDuration;
  final ParkingStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ParkingHistory({
    this.id,
    required this.dong,
    required this.ho,
    required this.serialNumber,
    required this.floor,
    required this.entryTime,
    this.exitTime,
    this.parkingDuration,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 현재 주차 중인 이력 생성
  factory ParkingHistory.createEntry({
    required String dong,
    required String ho,
    required String serialNumber,
    required String floor,
    DateTime? entryTime,
    String? notes,
  }) {
    final now = DateTime.now();
    return ParkingHistory(
      dong: dong,
      ho: ho,
      serialNumber: serialNumber,
      floor: floor,
      entryTime: entryTime ?? now,
      status: ParkingStatus.parked,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 출차 처리
  ParkingHistory markAsExited({DateTime? exitTime, String? notes}) {
    final actualExitTime = exitTime ?? DateTime.now();
    final duration = actualExitTime.difference(entryTime);

    return copyWith(
      exitTime: actualExitTime,
      parkingDuration: duration,
      status: ParkingStatus.exited,
      notes: notes ?? this.notes,
      updatedAt: DateTime.now(),
    );
  }

  /// 데이터베이스에서 생성
  factory ParkingHistory.fromMap(Map<String, dynamic> map) {
    return ParkingHistory(
      id: map['id'] as int?,
      dong: map['dong'] as String,
      ho: map['ho'] as String,
      serialNumber: map['serial_number'] as String,
      floor: map['floor'] as String,
      entryTime: DateTime.parse(map['entry_time'] as String),
      exitTime: map['exit_time'] != null
          ? DateTime.parse(map['exit_time'] as String)
          : null,
      parkingDuration: map['parking_duration_minutes'] != null
          ? Duration(minutes: map['parking_duration_minutes'] as int)
          : null,
      status: ParkingStatus.fromString(map['status'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// 데이터베이스 저장용 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dong': dong,
      'ho': ho,
      'serial_number': serialNumber,
      'floor': floor,
      'entry_time': entryTime.toIso8601String(),
      'exit_time': exitTime?.toIso8601String(),
      'parking_duration_minutes': parkingDuration?.inMinutes,
      'status': status.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 복사 (일부 변경)
  ParkingHistory copyWith({
    int? id,
    String? dong,
    String? ho,
    String? serialNumber,
    String? floor,
    DateTime? entryTime,
    DateTime? exitTime,
    Duration? parkingDuration,
    ParkingStatus? status,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ParkingHistory(
      id: id ?? this.id,
      dong: dong ?? this.dong,
      ho: ho ?? this.ho,
      serialNumber: serialNumber ?? this.serialNumber,
      floor: floor ?? this.floor,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      parkingDuration: parkingDuration ?? this.parkingDuration,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 현재 주차 중인지 확인
  bool get isCurrentlyParked =>
      status == ParkingStatus.parked && exitTime == null;

  /// 주차 시간 계산 (현재 주차 중이면 현재 시간까지)
  Duration get actualParkingDuration {
    if (parkingDuration != null) return parkingDuration!;
    if (exitTime != null) return exitTime!.difference(entryTime);
    return DateTime.now().difference(entryTime);
  }

  /// 주차 시간 (분 단위)
  int get parkingDurationMinutes => actualParkingDuration.inMinutes;

  /// 주차 시간 표시용 문자열
  String get parkingDurationText {
    final duration = actualParkingDuration;
    if (duration.inDays > 0) {
      return '${duration.inDays}일 ${duration.inHours % 24}시간';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes % 60}분';
    } else {
      return '${duration.inMinutes}분';
    }
  }

  /// 입차 시간 표시용 문자열
  String get entryTimeText {
    final now = DateTime.now();
    final diff = now.difference(entryTime);

    if (diff.inDays > 0) {
      return '${entryTime.month}/${entryTime.day} ${entryTime.hour.toString().padLeft(2, '0')}:${entryTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${entryTime.hour.toString().padLeft(2, '0')}:${entryTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 상태 표시용 문자열
  String get statusText {
    switch (status) {
      case ParkingStatus.parked:
        return '주차 중';
      case ParkingStatus.exited:
        return '출차 완료';
      case ParkingStatus.unknown:
        return '상태 불명';
    }
  }

  /// 색상 키 (UI용)
  String get colorKey {
    if (floor == '출차됨') return 'grey';

    switch (floor.toUpperCase()) {
      case 'B1':
        return 'blue';
      case 'B2':
        return 'green';
      case 'B3':
        return 'orange';
      case 'B4':
        return 'purple';
      default:
        return 'grey';
    }
  }

  @override
  String toString() {
    return 'ParkingHistory(id: $id, floor: $floor, entry: $entryTime, status: $status, duration: $parkingDurationText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingHistory &&
        other.id == id &&
        other.dong == dong &&
        other.ho == ho &&
        other.serialNumber == serialNumber &&
        other.floor == floor &&
        other.entryTime == entryTime &&
        other.exitTime == exitTime &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      dong,
      ho,
      serialNumber,
      floor,
      entryTime,
      exitTime,
      status,
    );
  }
}

/// 주차 상태 열거형
enum ParkingStatus {
  parked('parked', '주차 중'),
  exited('exited', '출차 완료'),
  unknown('unknown', '상태 불명');

  const ParkingStatus(this.name, this.displayName);
  final String name;
  final String displayName;

  /// 문자열에서 상태 생성
  static ParkingStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'parked':
        return ParkingStatus.parked;
      case 'exited':
        return ParkingStatus.exited;
      default:
        return ParkingStatus.unknown;
    }
  }
}

/// 주차 통계 모델
class ParkingStatistics {
  final int totalParkingCount;
  final Duration totalParkingTime;
  final Duration averageParkingTime;
  final Duration longestParkingTime;
  final Duration shortestParkingTime;
  final Map<String, int> floorUsageCount;
  final String mostUsedFloor;
  final List<ParkingHistory> recentHistory;

  const ParkingStatistics({
    required this.totalParkingCount,
    required this.totalParkingTime,
    required this.averageParkingTime,
    required this.longestParkingTime,
    required this.shortestParkingTime,
    required this.floorUsageCount,
    required this.mostUsedFloor,
    required this.recentHistory,
  });

  /// 빈 통계 생성
  factory ParkingStatistics.empty() {
    return const ParkingStatistics(
      totalParkingCount: 0,
      totalParkingTime: Duration.zero,
      averageParkingTime: Duration.zero,
      longestParkingTime: Duration.zero,
      shortestParkingTime: Duration.zero,
      floorUsageCount: {},
      mostUsedFloor: '',
      recentHistory: [],
    );
  }

  /// 이력 목록에서 통계 계산
  factory ParkingStatistics.fromHistory(List<ParkingHistory> history) {
    if (history.isEmpty) return ParkingStatistics.empty();

    final completedHistory =
        history.where((h) => h.parkingDuration != null).toList();
    if (completedHistory.isEmpty) return ParkingStatistics.empty();

    // 총 주차 시간 계산
    final totalTime =
        completedHistory.map((h) => h.parkingDuration!).reduce((a, b) => a + b);

    // 평균 주차 시간
    final avgTime = Duration(
      milliseconds: totalTime.inMilliseconds ~/ completedHistory.length,
    );

    // 최장/최단 주차 시간
    final durations = completedHistory.map((h) => h.parkingDuration!).toList();
    durations.sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));
    final shortest = durations.first;
    final longest = durations.last;

    // 층별 사용 횟수
    final floorCount = <String, int>{};
    for (final h in history) {
      if (h.floor != '출차됨') {
        floorCount[h.floor] = (floorCount[h.floor] ?? 0) + 1;
      }
    }

    // 가장 많이 사용한 층
    String mostUsed = '';
    int maxCount = 0;
    floorCount.forEach((floor, count) {
      if (count > maxCount) {
        maxCount = count;
        mostUsed = floor;
      }
    });

    // 최근 이력 (최대 10개)
    final recent = history.take(10).toList();

    return ParkingStatistics(
      totalParkingCount: history.length,
      totalParkingTime: totalTime,
      averageParkingTime: avgTime,
      longestParkingTime: longest,
      shortestParkingTime: shortest,
      floorUsageCount: floorCount,
      mostUsedFloor: mostUsed,
      recentHistory: recent,
    );
  }

  /// 총 주차 시간 표시용 문자열
  String get totalParkingTimeText {
    if (totalParkingTime.inDays > 0) {
      return '${totalParkingTime.inDays}일 ${totalParkingTime.inHours % 24}시간';
    } else if (totalParkingTime.inHours > 0) {
      return '${totalParkingTime.inHours}시간 ${totalParkingTime.inMinutes % 60}분';
    } else {
      return '${totalParkingTime.inMinutes}분';
    }
  }

  /// 평균 주차 시간 표시용 문자열
  String get averageParkingTimeText {
    if (averageParkingTime.inHours > 0) {
      return '${averageParkingTime.inHours}시간 ${averageParkingTime.inMinutes % 60}분';
    } else {
      return '${averageParkingTime.inMinutes}분';
    }
  }
}
