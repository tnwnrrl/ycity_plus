class UserInfo {
  int? id;
  String dong;
  String ho;
  String serialNumber;
  DateTime? createdAt;
  DateTime? updatedAt;

  UserInfo({
    this.id,
    required this.dong,
    required this.ho,
    required this.serialNumber,
    this.createdAt,
    this.updatedAt,
  });

  // SQLite에서 데이터를 가져올 때 사용
  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      id: map['id'],
      dong: map['dong'],
      ho: map['ho'],
      serialNumber: map['serial_number'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  // SQLite에 데이터를 저장할 때 사용
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dong': dong,
      'ho': ho,
      'serial_number': serialNumber,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // 업데이트용 - created_at 제외하고 updated_at만 현재 시간으로 설정
  Map<String, dynamic> toMapForUpdate() {
    return {
      'dong': dong,
      'ho': ho,
      'serial_number': serialNumber,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // 신규 생성용 - created_at과 updated_at을 현재 시간으로 설정
  Map<String, dynamic> toMapForInsert() {
    final now = DateTime.now().toIso8601String();
    return {
      'dong': dong,
      'ho': ho,
      'serial_number': serialNumber,
      'created_at': now,
      'updated_at': now,
    };
  }

  // 동 번호 유효성 검사 (101-106)
  bool isValidDong() {
    final dongNumber = int.tryParse(dong);
    return dongNumber != null && dongNumber >= 101 && dongNumber <= 106;
  }

  // 호수 유효성 검사 (숫자만)
  bool isValidHo() {
    final hoNumber = int.tryParse(ho);
    return hoNumber != null && hoNumber > 0;
  }

  // 시리얼넘버 유효성 검사 (비어있지 않음)
  bool isValidSerialNumber() {
    return serialNumber.trim().isNotEmpty;
  }

  // 전체 유효성 검사
  bool isValid() {
    return isValidDong() && isValidHo() && isValidSerialNumber();
  }

  @override
  String toString() {
    return 'UserInfo(id: $id, dong: $dong, ho: $ho, serialNumber: $serialNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserInfo &&
        other.dong == dong &&
        other.ho == ho &&
        other.serialNumber == serialNumber;
  }

  @override
  int get hashCode {
    return dong.hashCode ^ ho.hashCode ^ serialNumber.hashCode;
  }

  // 복사본 생성
  UserInfo copyWith({
    int? id,
    String? dong,
    String? ho,
    String? serialNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserInfo(
      id: id ?? this.id,
      dong: dong ?? this.dong,
      ho: ho ?? this.ho,
      serialNumber: serialNumber ?? this.serialNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
