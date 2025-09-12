class ParkingFloorInfo {
  final String dong;
  final String ho;
  final String serialNumber;
  final String floor;
  final DateTime lastUpdated;
  final bool isDefault;
  final int vehicleIndex; // 차량 순서 (1, 2, 3, ...)
  final String displayName; // 표시명 ("차량 1", "차량 2", ...)

  const ParkingFloorInfo({
    required this.dong,
    required this.ho,
    required this.serialNumber,
    required this.floor,
    required this.lastUpdated,
    this.isDefault = false,
    this.vehicleIndex = 1, // 기본값은 첫 번째 차량
    String? displayName,
  }) : displayName = displayName ?? '차량 $vehicleIndex';

  /// 층 정보가 유효한지 확인
  bool get isValidFloor {
    return ['B1', 'B2', 'B3', 'B4'].contains(floor.toUpperCase());
  }

  /// 층 정보 표시 텍스트 (예상 표시 제거)
  String get displayText {
    return floor;
  }

  /// 주차 위치 상태 표시 텍스트
  String get statusText {
    if (floor == '출차됨') {
      return '출차됨';
    }
    if (isDefault) {
      return '마지막 주차 위치';
    }
    return '현재 차량 위치';
  }

  /// 층 정보 색상 (UI용)
  String get floorColorKey {
    if (floor == '출차됨') {
      return 'grey';
    }
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

  /// 업데이트 시간 포맷팅
  String get formattedUpdateTime {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${lastUpdated.month}/${lastUpdated.day} ${lastUpdated.hour}:${lastUpdated.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 복사본 생성
  ParkingFloorInfo copyWith({
    String? dong,
    String? ho,
    String? serialNumber,
    String? floor,
    DateTime? lastUpdated,
    bool? isDefault,
    int? vehicleIndex,
    String? displayName,
  }) {
    return ParkingFloorInfo(
      dong: dong ?? this.dong,
      ho: ho ?? this.ho,
      serialNumber: serialNumber ?? this.serialNumber,
      floor: floor ?? this.floor,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isDefault: isDefault ?? this.isDefault,
      vehicleIndex: vehicleIndex ?? this.vehicleIndex,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  String toString() {
    return 'ParkingFloorInfo(dong: $dong, ho: $ho, serialNumber: $serialNumber, floor: $floor, vehicleIndex: $vehicleIndex, displayName: $displayName, lastUpdated: $lastUpdated, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParkingFloorInfo &&
        other.dong == dong &&
        other.ho == ho &&
        other.serialNumber == serialNumber &&
        other.floor == floor &&
        other.lastUpdated == lastUpdated &&
        other.isDefault == isDefault &&
        other.vehicleIndex == vehicleIndex &&
        other.displayName == displayName;
  }

  @override
  int get hashCode {
    return Object.hash(
      dong,
      ho,
      serialNumber,
      floor,
      lastUpdated,
      isDefault,
      vehicleIndex,
      displayName,
    );
  }
}
