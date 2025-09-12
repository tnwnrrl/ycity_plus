import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/android_resolution_warning_service.dart';
import '../widgets/android_resolution_fix_dialog.dart';

class VehicleLocationScreen extends StatefulWidget {
  final String dong;
  final String ho;
  final String serialNumber;

  const VehicleLocationScreen({
    super.key,
    required this.dong,
    required this.ho,
    required this.serialNumber,
  });

  @override
  State<VehicleLocationScreen> createState() => _VehicleLocationScreenState();
}

class _VehicleLocationScreenState extends State<VehicleLocationScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();

    // 웹뷰 초기화 전에 해상도 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndroidResolutionIssue();
    });
  }

  void _initializeWebView() {
    final url = _generateVehicleLocationUrl();

    // 웹뷰 초기화 전에 상태를 미리 설정하여 에러 화면 깜빡임 방지
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isControllerInitialized = false;
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (kDebugMode) {
              debugPrint('[VehicleLocationScreen] 페이지 로딩 시작: $url');
            }
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _errorMessage = '';
              });
            }
          },
          onPageFinished: (String url) {
            if (kDebugMode) {
              debugPrint('[VehicleLocationScreen] 페이지 로딩 완료: $url');
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              debugPrint('[VehicleLocationScreen] 웹뷰 에러: ${error.description}');
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = '페이지 로드 중 오류가 발생했습니다: ${error.description}';
              });
            }
          },
          // HTTP 에러도 처리 (404, 500 등)
          onNavigationRequest: (NavigationRequest request) {
            if (kDebugMode) {
              debugPrint('[VehicleLocationScreen] 네비게이션 요청: ${request.url}');
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // 컨트롤러 초기화 완료 표시
    setState(() {
      _isControllerInitialized = true;
    });
  }

  String _generateVehicleLocationUrl() {
    // URL 형식: http://122.199.183.213/rtlsTag/main/action.do?method=main.Main&dongId={동}&hoId={호}&serialId={시리얼넘버}
    final baseUrl = 'http://122.199.183.213/rtlsTag/main/action.do';
    final params = {
      'method': 'main.Main',
      'dongId': widget.dong,
      'hoId': widget.ho,
      'serialId': widget.serialNumber,
    };

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$baseUrl?$queryString';
  }

  void _reload() {
    if (kDebugMode) {
      debugPrint('[VehicleLocationScreen] 페이지 새로고침 시작');
    }

    // 새로고침 시에도 상태 미리 설정하여 에러 화면 깜빡임 방지
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final url = _generateVehicleLocationUrl();
    _controller?.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '차량 위치',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${widget.dong}동 ${widget.ho}호',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
              tooltip: '새로고침',
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 로딩 표시줄 (더 세련되게)
          if (_isLoading)
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF374151)
                    : Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),

          // WebView 또는 에러 화면
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildWebViewContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 웹뷰 콘텐츠 빌더 - 에러 화면 깜빡임 방지
  Widget _buildWebViewContent() {
    // 에러 상태일 때만 에러 화면 표시
    if (_hasError) {
      return _buildErrorWidget();
    }

    // 컨트롤러가 초기화되지 않았으면 로딩 화면 표시
    if (!_isControllerInitialized || _controller == null) {
      return _buildLoadingWidget();
    }

    // 정상 상태일 때 웹뷰 표시
    return WebViewWidget(controller: _controller!);
  }

  /// 로딩 위젯 (에러 화면 깜빡임 방지용)
  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            SizedBox(height: 16),
            Text(
              '차량 위치를 불러오는 중...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            '로드 실패',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.grey.shade800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            '차량 위치 페이지를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          // Error Details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '오류 세부 정보',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Action Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('뒤로 가기'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade600,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Android QHD+ 해상도 문제 체크 및 경고 표시
  void _checkAndroidResolutionIssue() {
    // Android 기기에서 QHD+ 해상도 체크
    if (AndroidResolutionWarningService.shouldShowAndroidQHDWarning(context)) {
      final appState = context.read<AppStateProvider>();

      if (!appState.androidResolutionWarningDismissed) {
        if (kDebugMode) {
          final resolution =
              AndroidResolutionWarningService.getCurrentResolution(context);
          debugPrint('[VehicleLocationScreen] QHD+ 해상도 감지됨: $resolution');
          debugPrint('[VehicleLocationScreen] 해상도 경고 다이얼로그 표시');
        }

        // 경고 다이얼로그 표시
        _showAndroidResolutionWarning();
        return;
      } else {
        if (kDebugMode) {
          debugPrint('[VehicleLocationScreen] QHD+ 해상도이지만 사용자가 경고를 해제함');
        }
      }
    } else {
      if (kDebugMode) {
        final resolution =
            AndroidResolutionWarningService.getCurrentResolution(context);
        debugPrint('[VehicleLocationScreen] 안전한 해상도: $resolution');
      }
    }

    // 경고 표시하지 않거나 이미 해제한 경우 웹뷰 초기화
    _initializeWebView();
  }

  /// Android 해상도 경고 다이얼로그 표시
  void _showAndroidResolutionWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AndroidResolutionFixDialog(),
    ).then((_) {
      // 다이얼로그 닫힌 후 웹뷰 초기화
      if (mounted) {
        _initializeWebView();
      }
    });
  }
}
