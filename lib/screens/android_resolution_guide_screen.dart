import 'package:flutter/material.dart';

/// Android 해상도 설정 단계별 가이드 화면
class AndroidResolutionGuideScreen extends StatelessWidget {
  const AndroidResolutionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('해상도 설정 가이드'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 메시지
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '해상도 변경 방법',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Android 기기의 해상도를 QHD+에서 FHD+ 이하로 변경하여 차량위치 표시 문제를 해결할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 단계별 가이드
            const Text(
              '단계별 설정 방법',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // 단계 1
            _buildGuideStep(
              stepNumber: 1,
              title: 'Android 설정 앱 열기',
              description: '홈 화면 또는 앱 서랍에서 "설정" 앱을 찾아 실행합니다.',
              icon: Icons.settings,
              iconColor: Colors.blue,
            ),

            // 단계 2
            _buildGuideStep(
              stepNumber: 2,
              title: '디스플레이 메뉴 이동',
              description: '설정 메뉴에서 "디스플레이" 또는 "화면" 항목을 선택합니다.',
              icon: Icons.display_settings,
              iconColor: Colors.green,
            ),

            // 단계 3
            _buildGuideStep(
              stepNumber: 3,
              title: '화면 해상도 선택',
              description:
                  '디스플레이 설정에서 "화면 해상도" 또는 "Screen resolution" 메뉴를 선택합니다.',
              icon: Icons.aspect_ratio,
              iconColor: Colors.orange,
            ),

            // 단계 4
            _buildGuideStep(
              stepNumber: 4,
              title: '권장 해상도 선택',
              description:
                  '현재 QHD+ (1440 x 3120)에서 FHD+ (1080 x 2340) 또는 HD+ (720 x 1560)로 변경합니다.',
              icon: Icons.radio_button_checked,
              iconColor: Colors.purple,
            ),

            // 단계 5
            _buildGuideStep(
              stepNumber: 5,
              title: '설정 적용',
              description: '"적용" 또는 "Apply" 버튼을 눌러 변경사항을 저장합니다.',
              icon: Icons.check_circle,
              iconColor: Colors.green,
            ),

            // 단계 6
            _buildGuideStep(
              stepNumber: 6,
              title: '앱으로 돌아가기',
              description: 'YCity+ 앱으로 돌아와서 차량위치가 정상적으로 표시되는지 확인합니다.',
              icon: Icons.arrow_back,
              iconColor: Colors.indigo,
            ),

            const SizedBox(height: 24),

            // 해상도 비교 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.compare,
                        color: Colors.grey[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '해상도 비교',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildResolutionCompare(
                      'QHD+', '1440 x 3120', '❌ 위치 오류 발생', Colors.red),
                  const SizedBox(height: 8),
                  _buildResolutionCompare(
                      'FHD+', '1080 x 2340', '✅ 권장 해상도', Colors.green),
                  const SizedBox(height: 8),
                  _buildResolutionCompare(
                      'HD+', '720 x 1560', '✅ 안전 해상도', Colors.blue),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 주의사항
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.amber[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '주의사항',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• 해상도 변경 후 일부 앱의 화면 크기가 달라 보일 수 있습니다.\n'
                    '• 배터리 사용량이 줄어들어 사용 시간이 늘어날 수 있습니다.\n'
                    '• 언제든지 다시 원래 해상도로 변경할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '확인했습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 단계별 가이드 위젯
  Widget _buildGuideStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 단계 번호 및 아이콘
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stepNumber.toString(),
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 단계 설명
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 해상도 비교 위젯
  Widget _buildResolutionCompare(
      String name, String resolution, String status, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            Icons.smartphone,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            '$name ($resolution)',
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            status,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
