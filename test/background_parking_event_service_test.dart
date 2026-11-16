import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ycity_plus/database/database_helper.dart';
import 'package:ycity_plus/models/parking_floor_info.dart';
import 'package:ycity_plus/models/parking_history.dart';
import 'package:ycity_plus/services/background_parking_event_service.dart';
import 'package:ycity_plus/services/parking_history_service.dart';

const _dong = '101';
const _ho = '4304';
const _serial = 'test-serial';
final _userKey = BackgroundParkingEventService.userKeyOf(_dong, _ho, _serial);

/// 위젯 공유 저장소 대신 쓰는 메모리 저장소
class _MemoryStore {
  final values = <String, String>{};
  Future<String?> read(String key) async => values[key];
  Future<void> write(String key, String value) async => values[key] = value;
}

Map<String, Object> _queued(DateTime at, int vehicle, String floor,
        {String? userKey}) =>
    {
      't': at.millisecondsSinceEpoch,
      'u': userKey ?? _userKey,
      'v': vehicle,
      'f': floor,
    };

Future<List<ParkingHistory>> _allHistory() => ParkingHistoryService()
    .getParkingHistory(dong: _dong, ho: _ho, serialNumber: _serial);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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

  // 대기열은 밀리초 단위로 저장되므로 기준 시각도 밀리초로 맞춘다
  final base = DateTime.fromMillisecondsSinceEpoch(DateTime.now()
      .subtract(const Duration(hours: 10))
      .millisecondsSinceEpoch);
  final t1 = base;
  final t2 = base.add(const Duration(hours: 3));
  final t3 = base.add(const Duration(hours: 4));

  late _MemoryStore store;
  late BackgroundParkingEventService service;

  setUp(() {
    store = _MemoryStore();
    service = BackgroundParkingEventService(read: store.read, write: store.write);
  });

  Future<int> import() =>
      service.importEvents(dong: _dong, ho: _ho, serialNumber: _serial);

  test('백그라운드에서 본 입차·출차를 실제 시각으로 주차 기록에 반영한다', () async {
    store.values[BackgroundParkingEventService.queueKey] = jsonEncode([
      _queued(t1, 1, 'B1'),
      _queued(t2, 1, '출차됨'),
      _queued(t3, 1, 'B2'),
    ]);

    expect(await import(), 3);

    final history = await _allHistory();
    expect(history, hasLength(2));
    final b1 = history.singleWhere((h) => h.floor == 'B1');
    expect(b1.entryTime, t1);
    expect(b1.exitTime, t2);
    final b2 = history.singleWhere((h) => h.floor == 'B2');
    expect(b2.entryTime, t3);
    expect(b2.isCurrentlyParked, isTrue);
  });

  test('한 번 반영한 이벤트는 다시 반영하지 않는다', () async {
    store.values[BackgroundParkingEventService.queueKey] =
        jsonEncode([_queued(t1, 1, 'B1'), _queued(t2, 1, '출차됨')]);

    await import();
    expect(await import(), 0);

    expect(await _allHistory(), hasLength(1));
    expect(store.values[BackgroundParkingEventService.cursorKey],
        '${t2.millisecondsSinceEpoch}');
  });

  test('다른 사용자의 이벤트는 반영하지 않고 건너뛴다', () async {
    store.values[BackgroundParkingEventService.queueKey] = jsonEncode([
      _queued(t1, 1, 'B1', userKey: '999|999|other'),
      _queued(t2, 1, 'B3'),
    ]);

    expect(await import(), 1);

    final history = await _allHistory();
    expect(history.single.floor, 'B3');
    expect(store.values[BackgroundParkingEventService.cursorKey],
        '${t2.millisecondsSinceEpoch}');
  });

  test('대기열이 깨져 있어도 아무것도 반영하지 않고 넘어간다', () async {
    store.values[BackgroundParkingEventService.queueKey] = '{not json';

    expect(await import(), 0);
    expect(await _allHistory(), isEmpty);
  });

  test('이미 기록된 입차보다 오래된 이벤트는 무시한다', () async {
    // 앱이 실시간으로 B1 입차를 기록한 뒤
    await ParkingHistoryService().handleParkingEvent(ParkingFloorInfo(
      dong: _dong,
      ho: _ho,
      serialNumber: _serial,
      floor: 'B1',
      lastUpdated: t2,
    ));
    // 그보다 앞선 시각의 출차가 대기열에서 들어와도
    store.values[BackgroundParkingEventService.queueKey] =
        jsonEncode([_queued(t1, 1, '출차됨')]);

    await import();

    final history = await _allHistory();
    expect(history.single.isCurrentlyParked, isTrue);
    expect(history.single.entryTime, t2);
  });
}
