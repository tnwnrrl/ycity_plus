import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/parking_floor_info.dart';
import '../models/vehicle_service_error.dart';
import 'preferences_service.dart';
import 'parking_history_service.dart';

// 성능 최적화를 위한 상수들
class _Constants {
  static const String baseUrl = 'http://122.199.183.213/rtlsTag/main/action.do';
  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration cacheExpiry = Duration(minutes: 3);
  static const int maxRetries = 1;
  static const int maxCacheSize = 50; // LRU cache size limit

  // HTTP 헤더 템플릿 (연결 재사용 지원)
  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'YCITY+/4.0.3 (iOS; Mobile)',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ko-KR,ko;q=0.9',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive', // Enable connection reuse
  };

  // 유효한 층 코드들
  static const List<String> validFloorCodes = ['B1', 'B2', 'B3', 'B4'];
}

class VehicleLocationService {
  // 싱글톤 패턴
  static final VehicleLocationService _instance =
      VehicleLocationService._internal();
  factory VehicleLocationService() => _instance;
  VehicleLocationService._internal();

  // 성능 최적화: LRU 캐싱 시스템
  final Map<String, ParkingFloorInfo> _cache = <String, ParkingFloorInfo>{};
  final Map<String, DateTime> _cacheTimestamps = <String, DateTime>{};
  final List<String> _cacheOrder = <String>[]; // LRU order tracking
  
  // 다중 차량 캐싱 시스템
  final Map<String, List<ParkingFloorInfo>> _multipleCache = <String, List<ParkingFloorInfo>>{};
  final Map<String, DateTime> _multipleCacheTimestamps = <String, DateTime>{};
  final List<String> _multipleCacheOrder = <String>[]; // LRU order tracking for multiple vehicles

  // HTTP 클라이언트 재사용 (성능 최적화)
  http.Client? _httpClient;
  DateTime? _clientCreatedAt;

  // Cache key generation optimization
  static String _buildCacheKey(String dong, String ho, String serialNumber) =>
      '${dong}_${ho}_$serialNumber';

  // HTTP 클라이언트 생성 및 재사용 관리
  http.Client _getHttpClient() {
    final now = DateTime.now();

    // 클라이언트가 없거나 1시간 이상 된 경우 새로 생성 (연결 품질 유지)
    if (_httpClient == null ||
        _clientCreatedAt == null ||
        now.difference(_clientCreatedAt!).inHours >= 1) {
      _httpClient?.close(); // 기존 클라이언트 정리
      _httpClient = _createHttpClient();
      _clientCreatedAt = now;

      if (kDebugMode) {
        debugPrint('[VehicleLocationService] HTTP 클라이언트 생성/갱신');
      }
    }

    return _httpClient!;
  }

  // LRU 캐시 관리
  void _updateCacheOrder(String key) {
    _cacheOrder.remove(key); // 기존 위치에서 제거
    _cacheOrder.add(key); // 끝에 추가 (most recently used)
  }

  void _evictLRUCache() {
    while (_cache.length >= _Constants.maxCacheSize) {
      if (_cacheOrder.isEmpty) break;

      final oldestKey = _cacheOrder.removeAt(0);
      _cache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);

      if (kDebugMode) {
        debugPrint('[VehicleLocationService] LRU 캐시 삭제: $oldestKey');
      }
    }
  }

  // Preferences 서비스 (마지막 주차 층 저장용)
  final PreferencesService _preferencesService = PreferencesService();

  // 주차 이력 서비스 (자동 주차 이벤트 추적)
  final ParkingHistoryService _parkingHistoryService = ParkingHistoryService();

  // HTTP 클라이언트 생성을 위한 설정

  /// HTTP 클라이언트 생성 (간단한 기본 클라이언트)
  http.Client _createHttpClient() {
    try {
      final httpClient = HttpClient();
      
      // 기본 연결 설정
      httpClient.connectionTimeout = _Constants.requestTimeout;
      httpClient.idleTimeout = const Duration(seconds: 30);

      return IOClient(httpClient);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[VehicleLocationService] HTTP client creation failed, using default: $e');
      }
      return http.Client();
    }
  }

  /// 다중 차량 위치 정보를 가져와서 층 정보 파싱 (새로운 API)
  Future<VehicleServiceResult<List<ParkingFloorInfo>>>
      getMultipleVehicleLocationInfoWithErrorHandling({
    required String dong,
    required String ho,
    required String serialNumber,
    bool useCache = true,
  }) async {
    // 입력 검증
    final validationError = _validateInput(dong, ho, serialNumber);
    if (validationError != null) {
      return VehicleServiceResult.failure(validationError);
    }

    final cacheKey = _buildCacheKey(dong, ho, serialNumber);

    // 다중 차량 캐시 확인
    if (useCache && _isValidMultipleCache(cacheKey)) {
      _updateCacheOrder(cacheKey);
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 다중 차량 캐시된 데이터 반환: $cacheKey');
      }
      return VehicleServiceResult.success(_getMultipleCacheData(cacheKey));
    }

    if (kDebugMode) {
      debugPrint(
          '[VehicleLocationService] 다중 차량 위치 정보 요청 시작: dong=$dong, ho=$ho, serial=$serialNumber');
    }

    // 네트워크 요청 시도
    for (int attempt = 0; attempt <= _Constants.maxRetries; attempt++) {
      try {
        final url = _buildRequestUrl(
          dong: dong,
          ho: ho,
          serialNumber: serialNumber,
        );

        if (kDebugMode) {
          debugPrint(
              '[VehicleLocationService] 다중 차량 시도 ${attempt + 1}/${_Constants.maxRetries + 1}, HTTP URL: ${url.replaceAll(RegExp(r'serialId=[^&]*'), 'serialId=***')}');
        }

        final result = await _makeSecureRequestWithErrorHandling(url);

        if (result.isSuccess && result.data != null) {
          final response = result.data!;
          final htmlContent = response.body;

          if (kDebugMode) {
            debugPrint(
                '[VehicleLocationService] HTTP 응답 성공, HTML 길이: ${htmlContent.length}');
          }

          final parseResult = _parseMultipleFloorInfoWithErrorHandling(
            htmlContent,
            dong,
            ho,
            serialNumber,
          );

          if (parseResult.isSuccess && parseResult.data != null) {
            final floorInfoList = parseResult.data!;

            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 다중 차량 파싱 결과: ${floorInfoList.map((e) => '${e.displayName}: ${e.floor}').join(", ")}');
            }

            // 성공한 결과 캐싱
            _updateMultipleCache(cacheKey, floorInfoList);

            // 주차 이력 서비스에 각 차량 이벤트 전달 (백그라운드 실행)
            for (final floorInfo in floorInfoList) {
              if (!floorInfo.isDefault) {
                // 첫 번째 차량의 층 정보를 마지막 주차 층으로 저장
                if (floorInfo.vehicleIndex == 1) {
                  await _preferencesService.saveLastParkedFloor(floorInfo.floor);
                  if (kDebugMode) {
                    debugPrint(
                        '[VehicleLocationService] 마지막 주차 층 저장: ${floorInfo.floor}');
                  }
                }
              }
              _trackParkingEvent(floorInfo);
            }

            return VehicleServiceResult.success(floorInfoList);
          } else {
            // 파싱 실패 - 다음 시도 또는 폴백
            if (attempt == _Constants.maxRetries) {
              return parseResult; // 파싱 에러 반환
            }
          }
        } else {
          // 네트워크 요청 실패 - 다음 시도
          if (attempt == _Constants.maxRetries) {
            return VehicleServiceResult.failure(result.error!); // 네트워크 에러 반환
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VehicleLocationService] 다중 차량 시도 ${attempt + 1} 실패: $e');
        }

        // 마지막 시도였다면 에러 반환
        if (attempt == _Constants.maxRetries) {
          return VehicleServiceResult.failure(
            _classifyError(e),
          );
        }

        // 지수 백오프
        final delayMs =
            (500 * (attempt + 1)) + (DateTime.now().millisecond % 100);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    // 폴백: 출차됨 상태로 반환 (마지막 수단)
    final fallbackInfo = ParkingFloorInfo(
      dong: dong,
      ho: ho,
      serialNumber: serialNumber,
      floor: '출차됨',
      lastUpdated: DateTime.now(),
      isDefault: false,
      vehicleIndex: 1,
      displayName: '차량 1',
    );

    _updateMultipleCache(cacheKey, [fallbackInfo], const Duration(minutes: 1));
    return VehicleServiceResult.success([fallbackInfo]);
  }

  /// 차량 위치 정보를 가져와서 층 정보 파싱 (개선된 에러 처리) - 단일 차량 호환성
  Future<VehicleServiceResult<ParkingFloorInfo>>
      getVehicleLocationInfoWithErrorHandling({
    required String dong,
    required String ho,
    required String serialNumber,
    bool useCache = true,
  }) async {
    // 입력 검증
    final validationError = _validateInput(dong, ho, serialNumber);
    if (validationError != null) {
      return VehicleServiceResult.failure(validationError);
    }

    final cacheKey = _buildCacheKey(dong, ho, serialNumber);

    // 캐시 확인 및 LRU 업데이트
    if (useCache && _isValidCache(cacheKey)) {
      _updateCacheOrder(cacheKey);
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 캐시된 데이터 반환: $cacheKey');
      }
      return VehicleServiceResult.success(_cache[cacheKey]!);
    }

    if (kDebugMode) {
      debugPrint(
          '[VehicleLocationService] 차량 위치 정보 요청 시작: dong=$dong, ho=$ho, serial=$serialNumber');
    }

    // 네트워크 요청 시도
    for (int attempt = 0; attempt <= _Constants.maxRetries; attempt++) {
      try {
        final url = _buildRequestUrl(
          dong: dong,
          ho: ho,
          serialNumber: serialNumber,
        );

        if (kDebugMode) {
          debugPrint(
              '[VehicleLocationService] 시도 ${attempt + 1}/${_Constants.maxRetries + 1}, HTTP URL: ${url.replaceAll(RegExp(r'serialId=[^&]*'), 'serialId=***')}');
        }

        final result = await _makeSecureRequestWithErrorHandling(url);

        if (result.isSuccess && result.data != null) {
          final response = result.data!;
          final htmlContent = response.body;

          if (kDebugMode) {
            debugPrint(
                '[VehicleLocationService] HTTP 응답 성공, HTML 길이: ${htmlContent.length}');
          }

          final parseResult = _parseFloorInfoWithErrorHandling(
            htmlContent,
            dong,
            ho,
            serialNumber,
          );

          if (parseResult.isSuccess && parseResult.data != null) {
            final floorInfo = parseResult.data!;

            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 파싱 결과: $floorInfo');
            }

            // 성공한 결과 캐싱 및 마지막 주차 층 저장
            _updateCache(cacheKey, floorInfo);

            // 실제 층 정보가 있으면 마지막 주차 층으로 저장
            if (!floorInfo.isDefault) {
              await _preferencesService.saveLastParkedFloor(floorInfo.floor);
              if (kDebugMode) {
                debugPrint(
                    '[VehicleLocationService] 마지막 주차 층 저장: ${floorInfo.floor}');
              }
            }

            // 주차 이력 서비스에 이벤트 전달 (백그라운드 실행)
            _trackParkingEvent(floorInfo);

            // 다중 차량 API 사용하여 첫 번째 차량 반환
            final multipleResult = await getMultipleVehicleLocationInfoWithErrorHandling(
              dong: dong,
              ho: ho, 
              serialNumber: serialNumber,
              useCache: useCache,
            );
            
            if (multipleResult.isSuccess && multipleResult.data!.isNotEmpty) {
              return VehicleServiceResult.success(multipleResult.data!.first);
            }
            
            return VehicleServiceResult.failure(multipleResult.error!);
          } else {
            // 파싱 실패 - 다음 시도 또는 폴백
            if (attempt == _Constants.maxRetries) {
              return parseResult; // 파싱 에러 반환
            }
          }
        } else {
          // 네트워크 요청 실패 - 다음 시도
          if (attempt == _Constants.maxRetries) {
            return VehicleServiceResult.failure(result.error!); // 네트워크 에러 반환
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VehicleLocationService] 시도 ${attempt + 1} 실패: $e');
        }

        // 마지막 시도였다면 에러 반환
        if (attempt == _Constants.maxRetries) {
          return VehicleServiceResult.failure(
            _classifyError(e),
          );
        }

        // 지수 백오프
        final delayMs =
            (500 * (attempt + 1)) + (DateTime.now().millisecond % 100);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    // 폴백: 출차됨 상태로 반환 (마지막 수단)
    final fallbackInfo = ParkingFloorInfo(
      dong: dong,
      ho: ho,
      serialNumber: serialNumber,
      floor: '출차됨',
      lastUpdated: DateTime.now(),
      isDefault: false,
    );

    _updateCache(cacheKey, fallbackInfo, const Duration(minutes: 1));
    return VehicleServiceResult.success(fallbackInfo);
  }

  /// 기존 메서드 호환성 유지 (deprecated)
  @Deprecated(
      'Use getVehicleLocationInfoWithErrorHandling instead for better error handling')
  Future<ParkingFloorInfo?> getVehicleLocationInfo({
    required String dong,
    required String ho,
    required String serialNumber,
    bool useCache = true,
  }) async {
    final cacheKey = _buildCacheKey(dong, ho, serialNumber);

    // 캐시 확인 및 LRU 업데이트
    if (useCache && _isValidCache(cacheKey)) {
      _updateCacheOrder(cacheKey); // LRU 순서 업데이트
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 캐시된 데이터 반환: $cacheKey');
      }
      return _cache[cacheKey];
    }

    if (kDebugMode) {
      debugPrint(
          '[VehicleLocationService] 차량 위치 정보 요청 시작: dong=$dong, ho=$ho, serial=$serialNumber');
    }

    // HTTP 요청 시도
    for (int attempt = 0; attempt <= _Constants.maxRetries; attempt++) {
      try {
        final url = _buildRequestUrl(
          dong: dong,
          ho: ho,
          serialNumber: serialNumber,
        );

        if (kDebugMode) {
          debugPrint(
              '[VehicleLocationService] 시도 ${attempt + 1}/${_Constants.maxRetries + 1}, HTTP URL: ${url.replaceAll(RegExp(r'serialId=[^&]*'), 'serialId=***')}');
        }

        final response = await _makeSecureRequest(url);

        if (response.statusCode == 200) {
          final htmlContent = response.body;

          if (kDebugMode) {
            debugPrint(
                '[VehicleLocationService] HTTP 응답 성공, HTML 길이: ${htmlContent.length}');
          }

          final floorInfo =
              _parseFloorInfo(htmlContent, dong, ho, serialNumber);

          if (kDebugMode) {
            debugPrint('[VehicleLocationService] 파싱 결과: $floorInfo');
          }

          // 성공한 결과 캐싱 및 마지막 주차 층 저장
          if (floorInfo != null) {
            _updateCache(cacheKey, floorInfo);

            // 실제 층 정보가 있으면 마지막 주차 층으로 저장
            if (!floorInfo.isDefault) {
              await _preferencesService.saveLastParkedFloor(floorInfo.floor);
              if (kDebugMode) {
                debugPrint(
                    '[VehicleLocationService] 마지막 주차 층 저장: ${floorInfo.floor}');
              }
            }

            // 주차 이력 서비스에 이벤트 전달 (백그라운드 실행)
            _trackParkingEvent(floorInfo);
          }

          return floorInfo;
        } else {
          if (kDebugMode) {
            debugPrint(
                '[VehicleLocationService] HTTP 요청 실패: ${response.statusCode}');
          }

          // If this was the last attempt, return null
          if (attempt == _Constants.maxRetries) {
            return null;
          }
        }
      } catch (e) {
        final sanitizedError = _sanitizeErrorMessage(e.toString());

        if (kDebugMode) {
          debugPrint(
              '[VehicleLocationService] 시도 ${attempt + 1} 실패: $sanitizedError');
        }

        // If this was the last attempt, return null
        if (attempt == _Constants.maxRetries) {
          if (kDebugMode) {
            debugPrint('[VehicleLocationService] 모든 시도 실패, 기본값으로 폴백');
          }

          // Return vehicle recognition failed info as fallback
          final fallbackInfo = ParkingFloorInfo(
            dong: dong,
            ho: ho,
            serialNumber: serialNumber,
            floor: '출차됨',
            lastUpdated: DateTime.now(),
            isDefault: false,
          );

          // 실패 정보도 캐싱 (짧은 시간)
          _updateCache(cacheKey, fallbackInfo, Duration(minutes: 1));
          return fallbackInfo;
        }

        // Exponential backoff with jitter for better performance
        final delayMs =
            (500 * (attempt + 1)) + (DateTime.now().millisecond % 100);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return null; // Should never reach here
  }

  /// 요청 URL 생성 (HTTP 직접 사용)
  String _buildRequestUrl({
    required String dong,
    required String ho,
    required String serialNumber,
  }) {
    // SECURITY: Input validation
    final cleanDong = _sanitizeInput(dong);
    final cleanHo = _sanitizeInput(ho);
    final cleanSerialNumber = _sanitizeInput(serialNumber);

    final params = {
      'method': 'main.Main',
      'dongId': cleanDong,
      'hoId': cleanHo,
      'serialId': cleanSerialNumber,
    };

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '${_Constants.baseUrl}?$queryString';
  }

  /// 보안 HTTP 요청 실행 (클라이언트 재사용)
  Future<http.Response> _makeSecureRequest(String url) async {
    final client = _getHttpClient(); // 재사용 가능한 클라이언트 가져오기

    // 최적화된 헤더 (상수에서 참조)
    final headers = Map<String, String>.from(_Constants.defaultHeaders);

    final response = await client.get(Uri.parse(url), headers: headers).timeout(
          _Constants.requestTimeout,
          onTimeout: () => throw TimeoutException(
            'Request timeout after ${_Constants.requestTimeout.inSeconds}s',
            _Constants.requestTimeout,
          ),
        );

    return response;
  }

  /// 입력값 안전화 (XSS 및 Injection 방지)
  String _sanitizeInput(String input) {
    if (input.isEmpty) return input;

    // Remove potentially dangerous characters
    String cleaned = input
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('&', '')
        .replaceAll(RegExp(r'[^\w\d가-힣\.\-\s]'), '')
        .trim();

    // 동 번호에서 "동" 제거 (예: "103동" → "103")
    if (cleaned.endsWith('동')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }

    return cleaned;
  }

  /// 에러 메시지 안전화 (민감한 정보 제거)
  String _sanitizeErrorMessage(String error) {
    if (error.isEmpty) return 'Unknown error';

    // Remove sensitive information from error messages
    return error
        .replaceAll(RegExp(r'serialId=[^&\s]*'), 'serialId=***')
        .replaceAll(RegExp(r'122\.199\.183\.213'), '***.***.***.**')
        .replaceAll(RegExp(r'password[=:][^&\s]*', caseSensitive: false),
            'password=***')
        .replaceAll(
            RegExp(r'token[=:][^&\s]*', caseSensitive: false), 'token=***')
        .replaceAll(RegExp(r'key[=:][^&\s]*', caseSensitive: false), 'key=***')
        .trim();
  }

  /// HTML에서 층 정보 파싱
  ParkingFloorInfo? _parseFloorInfo(
      String htmlContent, String dong, String ho, String serialNumber) {
    try {
      final document = html_parser.parse(htmlContent);

      // 다양한 선택자로 층 정보 찾기 시도
      String? floorInfo = _extractFloorFromDocument(document);

      if (floorInfo != null) {
        return ParkingFloorInfo(
          dong: dong,
          ho: ho,
          serialNumber: serialNumber,
          floor: floorInfo,
          lastUpdated: DateTime.now(),
        );
      }

      // HTML에서 층 정보를 찾지 못한 경우 출차됨으로 표시
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] HTML에서 층 정보를 찾지 못함, 출차됨으로 표시');
      }

      return ParkingFloorInfo(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        floor: '출차됨',
        lastUpdated: DateTime.now(),
        isDefault: false,
      );
    } catch (e) {
      final sanitizedError = _sanitizeErrorMessage(e.toString());

      if (kDebugMode) {
        debugPrint('[VehicleLocationService] HTML 파싱 중 오류: $sanitizedError');
      }

      // 파싱 실패 시 출차됨으로 표시
      return ParkingFloorInfo(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        floor: '출차됨',
        lastUpdated: DateTime.now(),
        isDefault: false,
      );
    }
  }

  /// HTML 문서에서 층 정보 추출 (최적화된 선택자 순서)
  String? _extractFloorFromDocument(dom.Document document) {
    // 우선순위가 높은 선택자부터 시도 (성능 최적화)
    final prioritySelectors = [
      // 가장 확률 높은 패턴부터
      'td', // 테이블 셀에서 B1-B4 찾기
      'span', // span 태그에서 찾기
      'div', // div 태그에서 찾기

      // 특정 클래스/ID
      '[class*="floor"]',
      '[class*="level"]',
      '[class*="parking"]',
      '[id*="floor"]',
      '[id*="level"]',
      '[id*="parking"]',

      // 기타
      'th',
      'p',
    ];

    for (final selector in prioritySelectors) {
      try {
        final elements = document.querySelectorAll(selector);
        for (final element in elements) {
          final text = element.text.trim();
          final floor = _extractFloorFromText(text);
          if (floor != null) {
            if (kDebugMode) {
              debugPrint(
                  '[VehicleLocationService] 층 정보 발견: $floor (선택자: $selector, 텍스트: $text)');
            }
            return floor;
          }
        }
      } catch (e) {
        // 선택자 오류 무시하고 다음 시도
        continue;
      }
    }

    // 전체 텍스트에서 패턴 매칭
    final bodyText = document.body?.text ?? '';
    return _extractFloorFromText(bodyText);
  }

  /// HTML 문서에서 다중 차량의 층 정보 추출 (순서 독립적)
  List<String> _extractMultipleFloorsFromDocument(dom.Document document) {
    try {
      // 전체 텍스트를 분석해서 차량별 패턴을 찾기
      final bodyText = document.body?.text ?? '';
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] HTML 전체 텍스트 분석 시작');
        debugPrint('[VehicleLocationService] HTML 전체 텍스트 길이: ${bodyText.length}');
        // HTML 텍스트 전체 출력 (디버깅용)
        final preview = bodyText.length > 1000 ? '${bodyText.substring(0, 1000)}...' : bodyText;
        debugPrint('[VehicleLocationService] HTML 텍스트 미리보기:\n$preview');
      }
      
      // 차량 번호와 위치 정보를 Map으로 매핑 (순서 독립적)
      final vehicleLocationMap = <int, String>{};
      final lines = bodyText.split('\n');
      String? currentVehicleNumber;
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 총 라인 수: ${lines.length}');
      }
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        if (kDebugMode && line.isNotEmpty) {
          debugPrint('[VehicleLocationService] 라인 $i: "$line"');
        }
        
        // 차량 번호 패턴 찾기 (단독 숫자)
        if (RegExp(r'^\s*[1-9]\s*$').hasMatch(line)) {
          currentVehicleNumber = line.trim();
          if (kDebugMode) {
            debugPrint('[VehicleLocationService] 차량 번호 발견: $currentVehicleNumber (라인 $i)');
          }
        }
        // 차량 번호가 있는 상태에서 층 정보 또는 상태 찾기
        else if (currentVehicleNumber != null && line.isNotEmpty) {
          String floorInfo;
          
          if (kDebugMode) {
            debugPrint('[VehicleLocationService] 차량 $currentVehicleNumber의 상태 라인 분석: "$line"');
          }
          
          // B1-B4 층 정보 확인
          if (RegExp(r'B[1-4]').hasMatch(line)) {
            final match = RegExp(r'B[1-4]').firstMatch(line);
            floorInfo = match?.group(0) ?? '';
            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 차량 $currentVehicleNumber: B층 정보 감지 "$floorInfo"');
            }
          }
          // "서비스 지역에 없음" 상태 확인
          else if (line.contains('서비스 지역에 없음') || 
                   line.contains('서비스지역') || 
                   line.contains('지역에 없음')) {
            floorInfo = '출차됨';
            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 차량 $currentVehicleNumber: 출차 상태 감지');
            }
          }
          // 기타 "출차됨" 관련 키워드
          else if (line.contains('출차됨') || 
                   line.contains('출차') || 
                   line.contains('없음')) {
            floorInfo = '출차됨';
            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 차량 $currentVehicleNumber: 출차 키워드 감지');
            }
          }
          // 다른 층 정보 패턴
          else {
            final extractedFloor = _extractFloorFromText(line);
            floorInfo = extractedFloor ?? '';
            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 차량 $currentVehicleNumber: 기타 패턴 추출 결과 "$floorInfo"');
            }
          }
          
          if (floorInfo.isNotEmpty) {
            final vehicleNum = int.tryParse(currentVehicleNumber);
            if (vehicleNum != null) {
              vehicleLocationMap[vehicleNum] = floorInfo;
              if (kDebugMode) {
                debugPrint('[VehicleLocationService] 차량 $vehicleNum: $floorInfo → Map에 저장');
              }
            }
          } else {
            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 차량 $currentVehicleNumber: 빈 결과로 인해 무시됨');
            }
          }
          
          currentVehicleNumber = null; // 다음 차량을 위해 초기화
        }
      }
      
      // Map을 차량 번호 순으로 정렬하여 일관된 순서 보장
      if (vehicleLocationMap.isNotEmpty) {
        final sortedVehicles = vehicleLocationMap.keys.toList()..sort();
        final floors = sortedVehicles.map((vehicleNum) => vehicleLocationMap[vehicleNum]!).toList();
        
        if (kDebugMode) {
          debugPrint('[VehicleLocationService] 정렬된 다중 차량 감지: ${floors.join(', ')} (차량 번호 순: ${sortedVehicles.join(', ')})');
        }
        
        // 다중 차량인 경우만 반환 (2대 이상)
        if (floors.length > 1) {
          return floors;
        }
      }
      
      // 기존 방식으로 폴백
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 단일 차량 또는 다중 차량 감지 실패, 폴백 방식 사용');
      }
      return _extractMultipleFloorsFromTextFallback(bodyText);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 다중 차량 추출 중 오류: $e');
      }
      // 전체 텍스트에서 패턴 매칭 시도
      final bodyText = document.body?.text ?? '';
      return _extractMultipleFloorsFromTextFallback(bodyText);
    }
  }
  
  /// 기존 방식의 다중 차량 추출 (폴백용)
  List<String> _extractMultipleFloorsFromTextFallback(String text) {
    final floors = <String>[];
    
    if (kDebugMode) {
      debugPrint('[VehicleLocationService] 폴백 방식 시작 - 다중 숫자 패턴 검색');
    }
    
    // 먼저 단일 층 정보가 명확히 있는지 확인
    final singleFloor = _extractFloorFromText(text);
    if (singleFloor != null) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 폴백: 단일 층 정보 발견 "$singleFloor", 다중 차량 생성 중단');
      }
      return [singleFloor]; // 단일 차량으로 반환
    }
    
    // 다중 숫자 패턴 감지 (더 엄격한 패턴)
    // 차량 번호 근처에 층 정보가 있는 경우만 인정
    final multipleNumberPattern = RegExp(r'([1-9])\s*[\s,/]\s*([1-9])(?=.*B[1-4]|.*층|.*주차)');
    final multipleMatches = multipleNumberPattern.allMatches(text);
    
    if (kDebugMode) {
      debugPrint('[VehicleLocationService] 다중 숫자 패턴 매치 수: ${multipleMatches.length}');
    }
    
    for (final match in multipleMatches) {
      final matchedText = match.group(0) ?? '';
      final numbers = RegExp(r'[1-9]').allMatches(matchedText);
      
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 폴백: 다중 숫자 패턴 매치 "$matchedText"');
      }
      
      for (final numMatch in numbers) {
        final number = numMatch.group(0) ?? '';
        if (number.isNotEmpty && int.tryParse(number) != null) {
          final floor = 'B$number';
          if (kDebugMode) {
            debugPrint('[VehicleLocationService] 폴백: 숫자 "$number" → 층 "$floor" 생성');
          }
          if (_Constants.validFloorCodes.contains(floor) && !floors.contains(floor)) {
            floors.add(floor);
            if (kDebugMode) {
              debugPrint('[VehicleLocationService] 폴백: 층 "$floor" 추가됨 (총 ${floors.length}개)');
            }
          }
        }
      }
      
      if (floors.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[VehicleLocationService] 폴백: 다중 차량 생성됨 ${floors.join(", ")}');
        }
        return floors;
      }
    }

    // 여기까지 와서 아무것도 찾지 못한 경우 빈 배열 반환
    if (kDebugMode) {
      debugPrint('[VehicleLocationService] 폴백: 다중 차량 패턴 찾지 못함, 빈 결과 반환');
    }

    return floors;
  }


  /// 텍스트에서 층 정보 추출 (개선된 패턴 매칭)
  String? _extractFloorFromText(String text) {
    if (text.isEmpty) return null;

    // 텍스트 정규화 (공백, 줄바꿈 제거)
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // B1, B2, B3, B4 패턴 찾기 (개선된 패턴)
    final floorPatterns = [
      RegExp(r'\bB[1-4]\b', caseSensitive: false),
      RegExp(r'B[1-4](?=\s|$|[^\d])',
          caseSensitive: false), // B4 뒤에 숫자가 오지 않는 경우
      RegExp(r'지하\s*[1-4]\s*층?', caseSensitive: false),
      RegExp(r'[^A-Z]B[1-4][^0-9]', caseSensitive: false), // 앞뒤로 다른 문자가 있는 경우
      RegExp(r'^B[1-4]', caseSensitive: false), // 텍스트 시작 부분
      RegExp(r'B[1-4]$', caseSensitive: false), // 텍스트 끝 부분
    ];

    for (final pattern in floorPatterns) {
      final matches = pattern.allMatches(normalizedText);
      for (final match in matches) {
        String found = match.group(0)!.toUpperCase().trim();

        // 매치된 문자열에서 B1-B4 추출
        final extractPattern = RegExp(r'B[1-4]', caseSensitive: false);
        final extractMatch = extractPattern.firstMatch(found);

        if (extractMatch != null) {
          final floorCode = extractMatch.group(0)!.toUpperCase();

          // 유효한 층 코드인지 확인
          if (_Constants.validFloorCodes.contains(floorCode)) {
            if (kDebugMode) {
              debugPrint(
                  '[VehicleLocationService] 층 정보 추출 성공: $floorCode (원본: $found)');
            }
            return floorCode;
          }
        }
      }
    }

    // 추가 패턴: 숫자만으로 층 정보 찾기 (1,2,3,4)
    final numberPattern =
        RegExp(r'(?:지하|basement|B)\s*([1-4])', caseSensitive: false);
    final numberMatch = numberPattern.firstMatch(normalizedText);
    if (numberMatch != null) {
      final floorNum = numberMatch.group(1)!;
      final result = 'B$floorNum';
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 숫자 패턴으로 층 정보 추출: $result');
      }
      return result;
    }

    return null;
  }

  /// 캐시 유효성 검사 (LRU 지원)
  bool _isValidCache(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final timestamp = _cacheTimestamps[key]!;
    final isExpired =
        DateTime.now().difference(timestamp) > _Constants.cacheExpiry;

    if (isExpired) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      _cacheOrder.remove(key);
      return false;
    }

    return true;
  }

  /// 캐시 업데이트 (LRU 관리 포함)
  void _updateCache(String key, ParkingFloorInfo info,
      [Duration? customExpiry]) {
    final now = DateTime.now();

    // LRU 캐시 크기 관리
    _evictLRUCache(); // 필요시 오래된 항목 제거

    _cache[key] = info;
    _cacheTimestamps[key] = now;
    _updateCacheOrder(key); // LRU 순서 업데이트

    if (kDebugMode) {
      debugPrint('[VehicleLocationService] 캐시 업데이트: $key → ${info.floor}');
    }
  }
  
  /// 다중 차량 캐시 유효성 검사
  bool _isValidMultipleCache(String key) {
    if (!_multipleCache.containsKey(key) || !_multipleCacheTimestamps.containsKey(key)) {
      return false;
    }

    final timestamp = _multipleCacheTimestamps[key]!;
    final isExpired = DateTime.now().difference(timestamp) > _Constants.cacheExpiry;

    if (isExpired) {
      _multipleCache.remove(key);
      _multipleCacheTimestamps.remove(key);
      _multipleCacheOrder.remove(key);
      return false;
    }

    return true;
  }
  
  /// 다중 차량 캐시 데이터 가져오기
  List<ParkingFloorInfo> _getMultipleCacheData(String key) {
    return _multipleCache[key] ?? [];
  }
  
  /// 다중 차량 캐시 업데이트 (LRU 관리 포함)
  void _updateMultipleCache(String key, List<ParkingFloorInfo> infoList,
      [Duration? customExpiry]) {
    final now = DateTime.now();

    // LRU 캐시 크기 관리
    _evictLRUMultipleCache();

    _multipleCache[key] = List.from(infoList); // 복사본 저장
    _multipleCacheTimestamps[key] = now;
    _updateMultipleCacheOrder(key);

    if (kDebugMode) {
      debugPrint('[VehicleLocationService] 다중 차량 캐시 업데이트: $key → ${infoList.map((e) => '${e.displayName}: ${e.floor}').join(", ")}');
    }
  }
  
  /// 다중 차량 LRU 캐시 순서 업데이트
  void _updateMultipleCacheOrder(String key) {
    _multipleCacheOrder.remove(key); // 기존 위치에서 제거
    _multipleCacheOrder.add(key); // 끝에 추가 (most recently used)
  }
  
  /// 다중 차량 LRU 캐시 관리
  void _evictLRUMultipleCache() {
    while (_multipleCache.length >= _Constants.maxCacheSize) {
      if (_multipleCacheOrder.isEmpty) break;

      final oldestKey = _multipleCacheOrder.removeAt(0);
      _multipleCache.remove(oldestKey);
      _multipleCacheTimestamps.remove(oldestKey);

      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 다중 차량 LRU 캐시 삭제: $oldestKey');
      }
    }
  }

  /// 다중 차량 캐시된 데이터 즉시 반환 (UI 응답성 향상)
  List<ParkingFloorInfo>? getCachedMultipleLocationInfo({
    required String dong,
    required String ho,
    required String serialNumber,
  }) {
    final cacheKey = _buildCacheKey(dong, ho, serialNumber);

    // 다중 차량 캐시된 데이터가 있으면 반환
    if (_isValidMultipleCache(cacheKey)) {
      return _multipleCache[cacheKey];
    }

    // 다중 차량 캐시에 없으면 단일 차량 캐시 확인
    final singleCachedInfo = getCachedLocationInfo(
      dong: dong,
      ho: ho,
      serialNumber: serialNumber,
    );
    
    if (singleCachedInfo != null) {
      return [singleCachedInfo]; // 단일 차량을 리스트로 반환
    }

    return null;
  }

  /// 캐시된 데이터 즉시 반환 (UI 응답성 향상) - 단일 차량 호환성
  ParkingFloorInfo? getCachedLocationInfo({
    required String dong,
    required String ho,
    required String serialNumber,
  }) {
    final cacheKey = _buildCacheKey(dong, ho, serialNumber);

    // 단일 차량 캐시된 데이터가 있으면 반환
    if (_isValidCache(cacheKey)) {
      return _cache[cacheKey];
    }
    
    // 다중 차량 캐시된 데이터에서 첫 번째 차량 반환
    if (_isValidMultipleCache(cacheKey)) {
      final multipleInfo = _multipleCache[cacheKey];
      if (multipleInfo != null && multipleInfo.isNotEmpty) {
        return multipleInfo.first;
      }
    }

    // 캐시에 없으면 마지막 주차 층 확인
    final lastParkedFloor = _preferencesService.getLastParkedFloor();
    final lastParkedTime = _preferencesService.getLastParkedTime();

    if (lastParkedFloor != null && lastParkedFloor.isNotEmpty) {
      return ParkingFloorInfo(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        floor: lastParkedFloor,
        lastUpdated: lastParkedTime ?? DateTime.now(),
        isDefault: true, // 마지막 주차 위치로 표시
      );
    }

    // 마지막 주차 층도 없으면 null 반환 (UI에서 카드 숨김)
    return null;
  }

  /// 병렬 요청 지원 (여러 차량 동시 조회)
  Future<List<VehicleServiceResult<ParkingFloorInfo>>>
      getMultipleVehicleLocationInfo(
    List<Map<String, String>> vehicleInfos,
  ) async {
    final futures =
        vehicleInfos.map((info) => getVehicleLocationInfoWithErrorHandling(
              dong: info['dong']!,
              ho: info['ho']!,
              serialNumber: info['serialNumber']!,
            ));

    return Future.wait(futures);
  }

  /// 주차 이벤트 추적 (백그라운드 실행)
  void _trackParkingEvent(ParkingFloorInfo floorInfo) {
    // 백그라운드에서 실행하여 메인 요청을 블로킹하지 않음
    Future.microtask(() async {
      try {
        // 주차 이력 서비스 초기화 (필요한 경우)
        await _parkingHistoryService.loadCurrentParkingStatus(
          dong: floorInfo.dong,
          ho: floorInfo.ho,
          serialNumber: floorInfo.serialNumber,
        );

        // 주차 이벤트 처리
        final success =
            await _parkingHistoryService.handleParkingEvent(floorInfo);

        if (kDebugMode) {
          if (success) {
            debugPrint(
                '[VehicleLocationService] 주차 이벤트 처리 성공: ${floorInfo.floor}');
          } else {
            debugPrint(
                '[VehicleLocationService] 주차 이벤트 처리 실패: ${floorInfo.floor}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VehicleLocationService] 주차 이벤트 추적 중 오류: $e');
        }
        // 주차 이력 추적 실패는 메인 기능에 영향을 주지 않으므로 무시
      }
    });
  }

  /// 서비스 정리 (리소스 해제)
  Future<void> dispose() async {
    try {
      // HTTP 클라이언트 정리
      _httpClient?.close();
      _httpClient = null;
      _clientCreatedAt = null;

      // 캐시 정리
      _cache.clear();
      _cacheTimestamps.clear();
      _cacheOrder.clear();
      
      // 다중 차량 캐시 정리
      _multipleCache.clear();
      _multipleCacheTimestamps.clear();
      _multipleCacheOrder.clear();

      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 서비스 정리 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] 서비스 정리 중 오류: $e');
      }
    }
  }

  /// 캐시 통계 정보 (디버깅용)
  Map<String, dynamic> getCacheStats() {
    return {
      'singleCacheSize': _cache.length,
      'multipleCacheSize': _multipleCache.length,
      'maxCacheSize': _Constants.maxCacheSize,
      'singleCacheUtilization':
          '${(_cache.length / _Constants.maxCacheSize * 100).toStringAsFixed(1)}%',
      'multipleCacheUtilization':
          '${(_multipleCache.length / _Constants.maxCacheSize * 100).toStringAsFixed(1)}%',
      'clientAge': _clientCreatedAt != null
          ? DateTime.now().difference(_clientCreatedAt!).inMinutes
          : 0,
    };
  }

  // === 개선된 에러 처리 헬퍼 메서드들 ===

  /// 입력값 검증
  VehicleServiceError? _validateInput(
      String dong, String ho, String serialNumber) {
    if (dong.trim().isEmpty) {
      return VehicleServiceError.validation(field: '동 번호');
    }
    if (ho.trim().isEmpty) {
      return VehicleServiceError.validation(field: '호수');
    }
    if (serialNumber.trim().isEmpty) {
      return VehicleServiceError.validation(field: '시리얼 번호');
    }

    // 동/호수 형식 검증 (숫자만 허용)
    if (!RegExp(r'^\d+$').hasMatch(dong.trim())) {
      return VehicleServiceError.validation(
        field: '동 번호',
        details: '숫자만 입력해주세요',
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(ho.trim())) {
      return VehicleServiceError.validation(
        field: '호수',
        details: '숫자만 입력해주세요',
      );
    }

    return null;
  }

  /// 개선된 HTTP 요청 (에러 처리 포함)
  Future<VehicleServiceResult<http.Response>>
      _makeSecureRequestWithErrorHandling(String url) async {
    try {
      final client = _getHttpClient();
      final headers = Map<String, String>.from(_Constants.defaultHeaders);

      final response =
          await client.get(Uri.parse(url), headers: headers).timeout(
        _Constants.requestTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Request timeout after ${_Constants.requestTimeout.inSeconds}s',
            _Constants.requestTimeout,
          );
        },
      );

      // 상태 코드 확인
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return VehicleServiceResult.success(response);
      } else {
        return VehicleServiceResult.failure(
          VehicleServiceError.server(
            statusCode: response.statusCode,
            details: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          ),
        );
      }
    } catch (e) {
      return VehicleServiceResult.failure(_classifyError(e));
    }
  }

  /// 개선된 HTML 파싱 (에러 처리 포함) - 다중 차량 지원
  VehicleServiceResult<List<ParkingFloorInfo>> _parseMultipleFloorInfoWithErrorHandling(
    String htmlContent,
    String dong,
    String ho,
    String serialNumber,
  ) {
    try {
      if (htmlContent.isEmpty) {
        return VehicleServiceResult.failure(
          VehicleServiceError.parsing(
            details: 'Empty HTML content',
          ),
        );
      }

      final document = html_parser.parse(htmlContent);
      final floors = _extractMultipleFloorsFromDocument(document);
      final now = DateTime.now();
      
      if (floors.isNotEmpty) {
        // 다중 차량 데이터를 ParkingFloorInfo 리스트로 변환
        final parkingInfoList = <ParkingFloorInfo>[];
        
        for (int i = 0; i < floors.length; i++) {
          final vehicleIndex = i + 1;
          final parkingInfo = ParkingFloorInfo(
            dong: dong,
            ho: ho,
            serialNumber: serialNumber,
            floor: floors[i],
            lastUpdated: now,
            vehicleIndex: vehicleIndex,
            displayName: '차량 $vehicleIndex',
          );
          parkingInfoList.add(parkingInfo);
        }
        
        if (kDebugMode) {
          debugPrint('[VehicleLocationService] 다중 차량 파싱 성공: ${floors.join(", ")}');
        }
        
        return VehicleServiceResult.success(parkingInfoList);
      }

      // HTML에서 층 정보를 찾지 못한 경우 출차됨으로 표시
      if (kDebugMode) {
        debugPrint('[VehicleLocationService] HTML에서 층 정보를 찾지 못함, 출차됨으로 표시');
      }

      final exitedInfo = ParkingFloorInfo(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        floor: '출차됨',
        lastUpdated: now,
        isDefault: false,
        vehicleIndex: 1,
        displayName: '차량 1',
      );

      return VehicleServiceResult.success([exitedInfo]);
    } catch (e) {
      final sanitizedError = _sanitizeErrorMessage(e.toString());

      if (kDebugMode) {
        debugPrint('[VehicleLocationService] HTML 파싱 중 오류: $sanitizedError');
      }

      return VehicleServiceResult.failure(
        VehicleServiceError.parsing(
          details: sanitizedError,
        ),
      );
    }
  }

  /// 개선된 HTML 파싱 (에러 처리 포함) - 단일 차량 호환성 유지
  VehicleServiceResult<ParkingFloorInfo> _parseFloorInfoWithErrorHandling(
    String htmlContent,
    String dong,
    String ho,
    String serialNumber,
  ) {
    final multipleResult = _parseMultipleFloorInfoWithErrorHandling(
      htmlContent, dong, ho, serialNumber);
    
    if (multipleResult.isSuccess && multipleResult.data != null) {
      // 다중 차량 결과에서 첫 번째 차량만 반환 (기존 API 호환성)
      final firstVehicle = multipleResult.data!.first;
      return VehicleServiceResult.success(firstVehicle);
    }
    
    return VehicleServiceResult.failure(multipleResult.error!);
  }

  /// 에러 분류 및 사용자 친화적 에러 생성
  VehicleServiceError _classifyError(dynamic error) {
    if (error is SocketException) {
      return VehicleServiceError.network(
        details: 'Network connection failed: ${error.message}',
      );
    }

    if (error is TimeoutException) {
      return VehicleServiceError.timeout(
        details: 'Request timed out: ${error.message}',
      );
    }

    if (error is HttpException) {
      return VehicleServiceError.server(
        statusCode: 500,
        details: 'HTTP error: ${error.message}',
      );
    }

    if (error is FormatException) {
      return VehicleServiceError.parsing(
        details: 'Data format error: ${error.message}',
      );
    }

    return VehicleServiceError.unknown(
      details: error.toString(),
    );
  }

  /// 에러 복구 시도 (향후 사용 예정)
  // ignore: unused_element
  Future<bool> _attemptErrorRecovery(VehicleServiceError error) async {
    switch (error.type) {
      case VehicleServiceErrorType.network:
        // 네트워크 연결 확인
        try {
          final result = await InternetAddress.lookup('google.com');
          return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (e) {
          return false;
        }

      case VehicleServiceErrorType.timeout:
        // 짧은 대기 후 재시도 가능
        await Future.delayed(const Duration(milliseconds: 500));
        return true;

      case VehicleServiceErrorType.server:
        // 5xx 에러는 재시도 가능, 4xx는 불가능
        return error.isRecoverable;

      case VehicleServiceErrorType.parsing:
        // 캐시 클리어 후 재시도
        _cache.clear();
        _cacheTimestamps.clear();
        _cacheOrder.clear();
        
        // 다중 차량 캐시도 클리어
        _multipleCache.clear();
        _multipleCacheTimestamps.clear();
        _multipleCacheOrder.clear();
        return true;

      default:
        return false;
    }
  }
}
