/// 차량 위치 서비스 에러 타입 정의
enum VehicleServiceErrorType {
  network, // 네트워크 연결 오류
  timeout, // 요청 시간 초과
  parsing, // HTML 파싱 오류
  server, // 서버 오류 (4xx, 5xx)
  validation, // 입력값 검증 오류
  unknown, // 알 수 없는 오류
}

/// 차량 위치 서비스 에러 모델
class VehicleServiceError {
  final VehicleServiceErrorType type;
  final String message;
  final String? details;
  final int? statusCode;
  final bool isRecoverable;

  const VehicleServiceError({
    required this.type,
    required this.message,
    this.details,
    this.statusCode,
    this.isRecoverable = true,
  });

  /// 네트워크 오류 생성
  factory VehicleServiceError.network({
    String? details,
  }) {
    return VehicleServiceError(
      type: VehicleServiceErrorType.network,
      message: '네트워크 연결을 확인해주세요',
      details: details,
      isRecoverable: true,
    );
  }

  /// 타임아웃 오류 생성
  factory VehicleServiceError.timeout({
    String? details,
  }) {
    return VehicleServiceError(
      type: VehicleServiceErrorType.timeout,
      message: '요청 시간이 초과되었습니다',
      details: details,
      isRecoverable: true,
    );
  }

  /// 파싱 오류 생성
  factory VehicleServiceError.parsing({
    String? details,
  }) {
    return VehicleServiceError(
      type: VehicleServiceErrorType.parsing,
      message: '데이터 처리 중 오류가 발생했습니다',
      details: details,
      isRecoverable: true,
    );
  }

  /// 서버 오류 생성
  factory VehicleServiceError.server({
    required int statusCode,
    String? details,
  }) {
    String message;
    bool recoverable;

    switch (statusCode) {
      case 400:
        message = '잘못된 요청입니다';
        recoverable = false;
        break;
      case 401:
        message = '인증이 필요합니다';
        recoverable = false;
        break;
      case 403:
        message = '접근이 거부되었습니다';
        recoverable = false;
        break;
      case 404:
        message = '차량 정보를 찾을 수 없습니다';
        recoverable = true;
        break;
      case 500:
        message = '서버 내부 오류가 발생했습니다';
        recoverable = true;
        break;
      case 502:
      case 503:
        message = '서버가 일시적으로 사용할 수 없습니다';
        recoverable = true;
        break;
      default:
        message = '서버 오류가 발생했습니다 ($statusCode)';
        recoverable = statusCode < 500;
    }

    return VehicleServiceError(
      type: VehicleServiceErrorType.server,
      message: message,
      details: details,
      statusCode: statusCode,
      isRecoverable: recoverable,
    );
  }

  /// 검증 오류 생성
  factory VehicleServiceError.validation({
    required String field,
    String? details,
  }) {
    return VehicleServiceError(
      type: VehicleServiceErrorType.validation,
      message: '$field을(를) 확인해주세요',
      details: details,
      isRecoverable: false,
    );
  }

  /// 알 수 없는 오류 생성
  factory VehicleServiceError.unknown({
    String? details,
  }) {
    return VehicleServiceError(
      type: VehicleServiceErrorType.unknown,
      message: '알 수 없는 오류가 발생했습니다',
      details: details,
      isRecoverable: true,
    );
  }

  /// 사용자 친화적 메시지
  String get userMessage {
    switch (type) {
      case VehicleServiceErrorType.network:
        return '인터넷 연결을 확인하고 다시 시도해주세요';
      case VehicleServiceErrorType.timeout:
        return '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요';
      case VehicleServiceErrorType.parsing:
        return '데이터를 불러오는 중 문제가 발생했습니다';
      case VehicleServiceErrorType.server:
        if (statusCode == 404) {
          return '등록된 차량 정보를 찾을 수 없습니다';
        }
        return message;
      case VehicleServiceErrorType.validation:
        return '입력 정보를 다시 확인해주세요';
      case VehicleServiceErrorType.unknown:
        return '일시적인 오류가 발생했습니다. 다시 시도해주세요';
    }
  }

  /// 권장 액션
  String get recommendedAction {
    switch (type) {
      case VehicleServiceErrorType.network:
        return '와이파이 또는 모바일 데이터 연결 상태를 확인하세요';
      case VehicleServiceErrorType.timeout:
        return '네트워크 상태를 확인하고 잠시 후 다시 시도하세요';
      case VehicleServiceErrorType.parsing:
        return '앱을 다시 시작하거나 업데이트를 확인하세요';
      case VehicleServiceErrorType.server:
        if (isRecoverable) {
          return '잠시 후 다시 시도하세요';
        }
        return '고객센터에 문의하세요';
      case VehicleServiceErrorType.validation:
        return '동, 호수, 시리얼 번호를 정확히 입력했는지 확인하세요';
      case VehicleServiceErrorType.unknown:
        return '문제가 계속되면 앱을 다시 시작해보세요';
    }
  }

  /// 에러 아이콘
  String get icon {
    switch (type) {
      case VehicleServiceErrorType.network:
        return '🌐';
      case VehicleServiceErrorType.timeout:
        return '⏱️';
      case VehicleServiceErrorType.parsing:
        return '📊';
      case VehicleServiceErrorType.server:
        return '🔧';
      case VehicleServiceErrorType.validation:
        return '⚠️';
      case VehicleServiceErrorType.unknown:
        return '❓';
    }
  }

  @override
  String toString() {
    return 'VehicleServiceError(type: $type, message: $message, details: $details, statusCode: $statusCode, recoverable: $isRecoverable)';
  }
}

/// 서비스 결과 래퍼
class VehicleServiceResult<T> {
  final T? data;
  final VehicleServiceError? error;
  final bool isSuccess;

  const VehicleServiceResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  /// 성공 결과 생성
  factory VehicleServiceResult.success(T data) {
    return VehicleServiceResult._(
      data: data,
      isSuccess: true,
    );
  }

  /// 실패 결과 생성
  factory VehicleServiceResult.failure(VehicleServiceError error) {
    return VehicleServiceResult._(
      error: error,
      isSuccess: false,
    );
  }

  /// 데이터가 있는지 확인
  bool get hasData => data != null;

  /// 에러가 있는지 확인
  bool get hasError => error != null;

  /// 복구 가능한 에러인지 확인
  bool get isRecoverableError => error?.isRecoverable ?? false;
}
