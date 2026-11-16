import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ycity_plus/database/database_helper.dart';
import 'package:ycity_plus/models/parking_history.dart';
import 'package:ycity_plus/services/parking_history_service.dart';

const _dong = '103';
const _ho = '4705';
const _serial = 'test-serial';
const _recordCount = 60; // 예전 조회 상한(50)보다 많게

final _service = ParkingHistoryService();

/// 이번 달 1일부터 2시간 주차 기록을 [_recordCount] 개 쌓는다 (B1 40개, B2 20개)
Future<void> _seedCompletedHistory() async {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  for (var i = 0; i < _recordCount; i++) {
    final entry = monthStart.add(Duration(hours: i * 3));
    await _service.addManualParkingHistory(
      dong: _dong,
      ho: _ho,
      serialNumber: _serial,
      floor: i < 40 ? 'B1' : 'B2',
      entryTime: entry,
      exitTime: entry.add(const Duration(hours: 2)),
    );
  }
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

  test('주차 통계는 모든 기록을 센다', () async {
    await _seedCompletedHistory();

    final stats = await _service.getParkingStatistics(
        dong: _dong, ho: _ho, serialNumber: _serial);

    expect(stats.totalParkingCount, _recordCount);
  });

  test('주차 통계의 층별 횟수가 층별 사용 통계와 같다', () async {
    await _seedCompletedHistory();

    final stats = await _service.getParkingStatistics(
        dong: _dong, ho: _ho, serialNumber: _serial);
    final floorUsage = await _service.getFloorUsageStatistics(
        dong: _dong, ho: _ho, serialNumber: _serial);

    expect(stats.floorUsageCount, floorUsage);
  });

  test('이번 달 주차 기록은 개수 제한 없이 모두 가져온다', () async {
    await _seedCompletedHistory();

    final month = await _service.getThisMonthParkingHistory(
        dong: _dong, ho: _ho, serialNumber: _serial);

    expect(month, hasLength(_recordCount));
  });

  test('아직 출차하지 않은 기록만 있어도 주차 횟수와 층을 센다', () {
    final parked = ParkingHistory.createEntry(
      dong: _dong,
      ho: _ho,
      serialNumber: _serial,
      floor: 'B3',
      entryTime: DateTime.now().subtract(const Duration(hours: 3)),
    );

    final stats = ParkingStatistics.fromHistory([parked]);

    expect(stats.totalParkingCount, 1);
    expect(stats.floorUsageCount, {'B3': 1});
    expect(stats.mostUsedFloor, 'B3');
  });
}
