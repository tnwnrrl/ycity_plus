import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/parking_floor_info.dart';
import 'parking_history_service.dart';

/// 위젯 백그라운드 조회(Android WorkManager·위젯, iOS 위젯)가 본 층 변화 하나
class BackgroundParkingEvent {
  final DateTime time;
  final String userKey;
  final int vehicleIndex;
  final String floor;

  const BackgroundParkingEvent({
    required this.time,
    required this.userKey,
    required this.vehicleIndex,
    required this.floor,
  });
}

/// 앱이 꺼져 있는 동안 위젯이 쌓아 둔 층 변화를 주차 기록에 반영하는 서비스
///
/// 네이티브 코드는 위젯 공유 저장소의 [queueKey] 에 JSON 배열
/// `[{"t": 밀리초, "u": 사용자 키, "v": 차량 순서, "f": 층}]` 을 덧붙이기만 하고,
/// 앱은 어디까지 반영했는지를 [cursorKey] 에만 쓴다. 한 값을 양쪽이 같이 고쳐 쓰지 않으므로
/// 서로의 쓰기를 덮어쓰지 않는다.
class BackgroundParkingEventService {
  static const String queueKey = 'flutter.parking_event_queue';
  static const String cursorKey = 'flutter.parking_event_cursor';

  final ParkingHistoryService _historyService;
  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;

  BackgroundParkingEventService({
    ParkingHistoryService? historyService,
    Future<String?> Function(String key)? read,
    Future<void> Function(String key, String value)? write,
  })  : _historyService = historyService ?? ParkingHistoryService(),
        _read = read ?? ((key) => HomeWidget.getWidgetData<String>(key)),
        _write = write ??
            ((key, value) async {
              await HomeWidget.saveWidgetData<String>(key, value);
            });

  /// 네이티브 코드와 같은 형식의 사용자 키
  static String userKeyOf(String dong, String ho, String serialNumber) =>
      '$dong|$ho|$serialNumber';

  /// 대기열 JSON 해석 (형식이 어긋난 항목은 건너뜀)
  static List<BackgroundParkingEvent> parseQueue(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final events = <BackgroundParkingEvent>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final t = item['t'];
        final u = item['u'];
        final v = item['v'];
        final f = item['f'];
        if (t is! int || u is! String || v is! int || f is! String) continue;
        events.add(BackgroundParkingEvent(
          time: DateTime.fromMillisecondsSinceEpoch(t),
          userKey: u,
          vehicleIndex: v,
          floor: f,
        ));
      }
      return events;
    } catch (e) {
      _log('대기열 해석 실패: $e');
      return [];
    }
  }

  /// 아직 반영하지 않은 이벤트를 시간 순으로 주차 기록에 반영하고, 반영한 개수를 돌려준다
  Future<int> importEvents({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    try {
      final cursor = int.tryParse(await _read(cursorKey) ?? '') ?? 0;
      final pending = parseQueue(await _read(queueKey))
          .where((e) => e.time.millisecondsSinceEpoch > cursor)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      if (pending.isEmpty) return 0;

      final userKey = userKeyOf(dong, ho, serialNumber);
      final mine = pending.where((e) => e.userKey == userKey).toList();
      for (final event in mine) {
        await _historyService.handleParkingEvent(ParkingFloorInfo(
          dong: dong,
          ho: ho,
          serialNumber: serialNumber,
          floor: event.floor,
          lastUpdated: event.time,
          vehicleIndex: event.vehicleIndex,
        ));
      }

      // 다른 사용자 이벤트까지 포함해 읽은 데까지 커서를 옮긴다
      await _write(
          cursorKey, '${pending.last.time.millisecondsSinceEpoch}');
      _log('백그라운드 이벤트 ${mine.length}건 반영 (대기 ${pending.length}건)');
      return mine.length;
    } catch (e) {
      _log('백그라운드 이벤트 반영 실패: $e');
      return 0;
    }
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[BackgroundParkingEventService] $message');
    }
  }
}
