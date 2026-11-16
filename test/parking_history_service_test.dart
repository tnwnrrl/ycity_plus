import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ycity_plus/database/database_helper.dart';
import 'package:ycity_plus/models/parking_floor_info.dart';
import 'package:ycity_plus/models/parking_history.dart';
import 'package:ycity_plus/services/parking_history_service.dart';

const _dong = '101';
const _ho = '4304';
const _serial = 'test-serial';

ParkingFloorInfo _event(int vehicleIndex, String floor, DateTime at) {
  return ParkingFloorInfo(
    dong: _dong,
    ho: _ho,
    serialNumber: _serial,
    floor: floor,
    lastUpdated: at,
    vehicleIndex: vehicleIndex,
  );
}

Future<List<ParkingHistory>> _allHistory() {
  return ParkingHistoryService().getParkingHistory(
    dong: _dong,
    ho: _ho,
    serialNumber: _serial,
    limit: null,
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 테스트 파일들이 동시에 돌아도 DB 파일이 겹치지 않도록 파일마다 임시 폴더 사용
    final dir = await Directory.systemTemp.createTemp('ycity_plus_test_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    await DatabaseHelper().closeDatabase();
    await deleteDatabase(join(await getDatabasesPath(), 'ycity_plus.db'));
  });

  tearDownAll(() async {
    await DatabaseHelper().closeDatabase();
  });

  final service = ParkingHistoryService();
  final entry = DateTime.now().subtract(const Duration(hours: 5));
  final nextPoll = entry.add(const Duration(minutes: 3));

  test('차량 2대가 다른 층에 있으면 갱신이 반복돼도 각자 주차 기록 하나만 유지한다', () async {
    // 앱은 갱신마다 차량별 이벤트를 동시에 던진다
    await Future.wait([
      service.handleParkingEvent(_event(1, 'B1', entry)),
      service.handleParkingEvent(_event(2, 'B3', entry)),
    ]);
    await Future.wait([
      service.handleParkingEvent(_event(1, 'B1', nextPoll)),
      service.handleParkingEvent(_event(2, 'B3', nextPoll)),
    ]);

    final history = await _allHistory();
    expect(history, hasLength(2));
    expect(history.every((h) => h.isCurrentlyParked), isTrue);
    expect(history.map((h) => h.floor).toSet(), {'B1', 'B3'});
    expect(history.every((h) => h.entryTime == entry), isTrue);
  });

  test('한 차량이 출차해도 다른 차량의 주차 기록은 끝내지 않는다', () async {
    await service.handleParkingEvent(_event(1, 'B1', entry));
    await service.handleParkingEvent(_event(2, 'B3', entry));

    await service.handleParkingEvent(_event(2, '출차됨', nextPoll));

    final history = await _allHistory();
    final parked = history.where((h) => h.isCurrentlyParked).toList();
    expect(parked, hasLength(1));
    expect(parked.single.floor, 'B1');
    expect(parked.single.vehicleIndex, 1);
  });

  test('같은 차량의 입차 이벤트가 동시에 들어와도 기록은 하나만 만든다', () async {
    await Future.wait([
      service.handleParkingEvent(_event(1, 'B2', entry)),
      service.handleParkingEvent(_event(1, 'B2', entry)),
    ]);

    expect(await _allHistory(), hasLength(1));
  });

  test('v2 DB 를 열면 기존 주차 기록이 1번 차량 기록으로 보존된다', () async {
    final path = join(await getDatabasesPath(), 'ycity_plus.db');
    final v2 = await openDatabase(path, version: 2, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE user_info (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dong TEXT NOT NULL, ho TEXT NOT NULL, serial_number TEXT NOT NULL,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          UNIQUE(dong, ho, serial_number)
        )
      ''');
      await db.execute('''
        CREATE TABLE parking_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dong TEXT NOT NULL, ho TEXT NOT NULL, serial_number TEXT NOT NULL,
          floor TEXT NOT NULL, entry_time TEXT NOT NULL, exit_time TEXT,
          parking_duration_minutes INTEGER,
          status TEXT NOT NULL DEFAULT 'parked', notes TEXT,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )
      ''');
    });
    await v2.insert('parking_history', {
      'dong': _dong,
      'ho': _ho,
      'serial_number': _serial,
      'floor': 'B2',
      'entry_time': entry.toIso8601String(),
      'status': 'parked',
      'created_at': entry.toIso8601String(),
      'updated_at': entry.toIso8601String(),
    });
    await v2.close();

    // 업그레이드 후에도 기존 기록이 1번 차량의 현재 주차로 이어진다
    expect(await service.handleParkingEvent(_event(1, 'B2', nextPoll)), isTrue);

    final history = await _allHistory();
    expect(history, hasLength(1));
    expect(history.single.vehicleIndex, 1);
    expect(history.single.isCurrentlyParked, isTrue);
    expect(history.single.entryTime, entry);
  });

  test('차량이 다른 층으로 옮기면 이전 기록을 끝내고 새 기록을 만든다', () async {
    await service.handleParkingEvent(_event(1, 'B1', entry));
    final moved = entry.add(const Duration(hours: 2));
    await service.handleParkingEvent(_event(1, 'B4', moved));

    final history = await _allHistory();
    expect(history, hasLength(2));
    final previous = history.singleWhere((h) => h.floor == 'B1');
    expect(previous.isCurrentlyParked, isFalse);
    expect(previous.exitTime, moved);
    expect(history.singleWhere((h) => h.floor == 'B4').entryTime, moved);
  });
}
