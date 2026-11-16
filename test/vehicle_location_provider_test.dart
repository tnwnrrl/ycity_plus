import 'package:flutter_test/flutter_test.dart';
import 'package:ycity_plus/models/parking_floor_info.dart';
import 'package:ycity_plus/models/user_info.dart';
import 'package:ycity_plus/models/vehicle_service_error.dart';
import 'package:ycity_plus/providers/vehicle_location_provider.dart';
import 'package:ycity_plus/services/preferences_service.dart';
import 'package:ycity_plus/services/vehicle_location_service.dart';

final _user = UserInfo(dong: '103', ho: '4705', serialNumber: 'test-serial');

ParkingFloorInfo _floor(String floor, int vehicleIndex) => ParkingFloorInfo(
      dong: _user.dong,
      ho: _user.ho,
      serialNumber: _user.serialNumber,
      floor: floor,
      lastUpdated: DateTime.now(),
      vehicleIndex: vehicleIndex,
    );

/// 서버 대신 정해진 결과를 돌려주고 호출 횟수를 센다
class _FakeVehicleLocationService implements VehicleLocationService {
  _FakeVehicleLocationService(this.multipleResult);

  final VehicleServiceResult<List<ParkingFloorInfo>> multipleResult;
  int multipleCalls = 0;
  int singleCalls = 0;

  @override
  Future<VehicleServiceResult<List<ParkingFloorInfo>>>
      getMultipleVehicleLocationInfoWithErrorHandling({
    required String dong,
    required String ho,
    required String serialNumber,
    bool useCache = true,
  }) async {
    multipleCalls++;
    return multipleResult;
  }

  @override
  Future<VehicleServiceResult<ParkingFloorInfo>>
      getVehicleLocationInfoWithErrorHandling({
    required String dong,
    required String ho,
    required String serialNumber,
    bool useCache = true,
  }) async {
    singleCalls++;
    return VehicleServiceResult.success(_floor('B1', 1));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePreferencesService implements PreferencesService {
  int _selected = 1;

  @override
  Future<void> saveMultipleVehicleInfo({
    required int selectedVehicleIndex,
    required int vehicleCount,
    required bool isMultipleMode,
  }) async {}

  @override
  Future<void> saveSelectedVehicleIndex(int vehicleIndex) async {
    _selected = vehicleIndex;
  }

  @override
  int getSelectedVehicleIndex() => _selected;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('차량이 한 대면 위치 조회 시 서버에 한 번만 요청한다', () async {
    final service = _FakeVehicleLocationService(
        VehicleServiceResult.success([_floor('B2', 1)]));
    final provider = VehicleLocationProvider(
      vehicleLocationService: service,
      preferencesService: _FakePreferencesService(),
    );

    await provider.fetchLocation(userInfo: _user);

    expect(service.multipleCalls, 1);
    expect(service.singleCalls, 0);
    expect(provider.currentFloorInfo?.floor, 'B2');
  });

  test('다중 차량 조회가 실패하면 단일 차량 조회로 한 번 더 시도한다', () async {
    final service = _FakeVehicleLocationService(VehicleServiceResult.failure(
        VehicleServiceError(
            type: VehicleServiceErrorType.unknown, message: 'fail')));
    final provider = VehicleLocationProvider(
      vehicleLocationService: service,
      preferencesService: _FakePreferencesService(),
    );

    await provider.fetchLocation(userInfo: _user);

    expect(service.singleCalls, 1);
    expect(provider.currentFloorInfo?.floor, 'B1');
    expect(provider.locationError, isNull);
  });
}
