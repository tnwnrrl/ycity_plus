import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/user_info.dart';
import '../models/parking_history.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // 디버그 로깅 메서드
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DatabaseHelper] $message');
    }
  }

  // 데이터베이스 싱글톤 인스턴스 가져오기
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 데이터베이스 초기화
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ycity_plus.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // 테이블 생성
  Future<void> _onCreate(Database db, int version) async {
    // 사용자 정보 테이블
    await db.execute('''
      CREATE TABLE user_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dong TEXT NOT NULL,
        ho TEXT NOT NULL,
        serial_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(dong, ho, serial_number)
      )
    ''');

    // 주차 이력 테이블
    await db.execute('''
      CREATE TABLE parking_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dong TEXT NOT NULL,
        ho TEXT NOT NULL,
        serial_number TEXT NOT NULL,
        floor TEXT NOT NULL,
        entry_time TEXT NOT NULL,
        exit_time TEXT,
        parking_duration_minutes INTEGER,
        status TEXT NOT NULL DEFAULT 'parked',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 인덱스 생성 (검색 성능 향상)
    await db.execute('CREATE INDEX idx_dong ON user_info(dong)');
    await db.execute('CREATE INDEX idx_ho ON user_info(ho)');
    await db
        .execute('CREATE INDEX idx_serial_number ON user_info(serial_number)');

    // 주차 이력 인덱스
    await db.execute(
        'CREATE INDEX idx_parking_user ON parking_history(dong, ho, serial_number)');
    await db.execute(
        'CREATE INDEX idx_parking_entry_time ON parking_history(entry_time)');
    await db
        .execute('CREATE INDEX idx_parking_status ON parking_history(status)');
    await db
        .execute('CREATE INDEX idx_parking_floor ON parking_history(floor)');
  }

  // 데이터베이스 업그레이드
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 버전 1에서 2로 업그레이드: 주차 이력 테이블 추가
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE parking_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dong TEXT NOT NULL,
          ho TEXT NOT NULL,
          serial_number TEXT NOT NULL,
          floor TEXT NOT NULL,
          entry_time TEXT NOT NULL,
          exit_time TEXT,
          parking_duration_minutes INTEGER,
          status TEXT NOT NULL DEFAULT 'parked',
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // 주차 이력 인덱스 생성
      await db.execute(
          'CREATE INDEX idx_parking_user ON parking_history(dong, ho, serial_number)');
      await db.execute(
          'CREATE INDEX idx_parking_entry_time ON parking_history(entry_time)');
      await db.execute(
          'CREATE INDEX idx_parking_status ON parking_history(status)');
      await db
          .execute('CREATE INDEX idx_parking_floor ON parking_history(floor)');

      _log('주차 이력 테이블 및 인덱스 생성 완료');
    }
  }

  // CREATE - 사용자 정보 삽입
  Future<int> insertUserInfo(UserInfo userInfo) async {
    try {
      final db = await database;
      return await db.insert(
        'user_info',
        userInfo.toMapForInsert(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _log('사용자 정보 삽입 중 오류 발생: $e');
      rethrow;
    }
  }

  // READ - 모든 사용자 정보 조회
  Future<List<UserInfo>> getAllUserInfo() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'user_info',
        orderBy: 'updated_at DESC', // 최근 업데이트순으로 정렬
      );

      return maps.map((map) => UserInfo.fromMap(map)).toList();
    } catch (e) {
      _log('사용자 정보 조회 중 오류 발생: $e');
      return [];
    }
  }

  // UPDATE - 사용자 정보 업데이트
  Future<int> updateUserInfo(UserInfo userInfo) async {
    try {
      final db = await database;
      return await db.update(
        'user_info',
        userInfo.toMapForUpdate(),
        where: 'id = ?',
        whereArgs: [userInfo.id],
      );
    } catch (e) {
      _log('사용자 정보 업데이트 중 오류 발생: $e');
      rethrow;
    }
  }

  // DELETE - 특정 ID의 사용자 정보 삭제
  Future<int> deleteUserInfo(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'user_info',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _log('사용자 정보 삭제 중 오류 발생: $e');
      rethrow;
    }
  }

  // DELETE - 모든 사용자 정보 삭제
  Future<int> deleteAllUserInfo() async {
    try {
      final db = await database;
      return await db.delete('user_info');
    } catch (e) {
      _log('모든 사용자 정보 삭제 중 오류 발생: $e');
      rethrow;
    }
  }

  // === 주차 이력 관련 메서드 ===

  // 주차 이력 추가
  Future<int> insertParkingHistory(ParkingHistory history) async {
    try {
      final db = await database;
      return await db.insert(
        'parking_history',
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _log('주차 이력 추가 중 오류 발생: $e');
      rethrow;
    }
  }

  // 특정 사용자의 주차 이력 조회
  Future<List<ParkingHistory>> getParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;

      String whereClause = 'dong = ? AND ho = ? AND serial_number = ?';
      List<dynamic> whereArgs = [dong, ho, serialNumber];

      // 날짜 범위 필터링
      if (startDate != null) {
        whereClause += ' AND entry_time >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        whereClause += ' AND entry_time <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'parking_history',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'entry_time DESC',
        limit: limit,
      );

      return maps.map((map) => ParkingHistory.fromMap(map)).toList();
    } catch (e) {
      _log('주차 이력 조회 중 오류 발생: $e');
      return [];
    }
  }

  // 현재 주차 중인 이력 조회
  Future<ParkingHistory?> getCurrentParkingHistory({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'parking_history',
        where:
            'dong = ? AND ho = ? AND serial_number = ? AND status = ? AND exit_time IS NULL',
        whereArgs: [dong, ho, serialNumber, 'parked'],
        orderBy: 'entry_time DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return ParkingHistory.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      _log('현재 주차 이력 조회 중 오류 발생: $e');
      return null;
    }
  }

  // 주차 이력 업데이트 (출차 처리 등)
  Future<int> updateParkingHistory(ParkingHistory history) async {
    try {
      final db = await database;
      return await db.update(
        'parking_history',
        history.toMap(),
        where: 'id = ?',
        whereArgs: [history.id],
      );
    } catch (e) {
      _log('주차 이력 업데이트 중 오류 발생: $e');
      rethrow;
    }
  }

  // 주차 이력 삭제
  Future<int> deleteParkingHistory(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'parking_history',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _log('주차 이력 삭제 중 오류 발생: $e');
      rethrow;
    }
  }

  // 주차 통계 조회 (층별 사용 횟수 등)
  Future<Map<String, int>> getFloorUsageStatistics({
    required String dong,
    required String ho,
    required String serialNumber,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;

      String whereClause =
          'dong = ? AND ho = ? AND serial_number = ? AND floor != ?';
      List<dynamic> whereArgs = [dong, ho, serialNumber, '출차됨'];

      if (startDate != null) {
        whereClause += ' AND entry_time >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        whereClause += ' AND entry_time <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT floor, COUNT(*) as count
        FROM parking_history
        WHERE $whereClause
        GROUP BY floor
        ORDER BY count DESC
      ''', whereArgs);

      final Map<String, int> result = {};
      for (final map in maps) {
        result[map['floor'] as String] = map['count'] as int;
      }

      return result;
    } catch (e) {
      _log('층별 사용 통계 조회 중 오류 발생: $e');
      return {};
    }
  }

  // 데이터베이스 연결 종료
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
