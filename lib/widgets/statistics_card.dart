import 'package:flutter/material.dart';
import '../models/parking_history.dart';

/// 재사용 가능한 통계 카드 위젯
class StatisticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatisticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey.shade900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey.shade600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 층별 사용 현황 카드 위젯
class FloorUsageCard extends StatelessWidget {
  final String floor;
  final int count;
  final int maxCount;

  const FloorUsageCard({
    super.key,
    required this.floor,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = maxCount > 0 ? count / maxCount : 0.0;
    final color = _getFloorColor(floor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        floor,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$floor 주차',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
              Text(
                '$count회',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFloorColor(String floor) {
    switch (floor.toUpperCase()) {
      case 'B1':
        return const Color(0xFF6366F1);
      case 'B2':
        return const Color(0xFF8B5CF6);
      case 'B3':
        return const Color(0xFFF59E0B);
      case 'B4':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

/// 통계 화면용 유틸리티 클래스
class StatisticsUtils {
  static List<StatisticsCard> buildStatisticsCards(
    ParkingStatistics statistics,
  ) {
    return [
      StatisticsCard(
        title: '총 주차 횟수',
        value: '${statistics.totalParkingCount}회',
        icon: Icons.local_parking_rounded,
        color: const Color(0xFF6366F1),
        subtitle: '전체 기간',
      ),
      StatisticsCard(
        title: '평균 주차 시간',
        value: _formatDuration(statistics.averageParkingTime),
        icon: Icons.access_time_rounded,
        color: const Color(0xFF8B5CF6),
        subtitle: '주차 시간 평균',
      ),
      StatisticsCard(
        title: '최장 주차 시간',
        value: _formatDuration(statistics.longestParkingTime),
        icon: Icons.schedule_rounded,
        color: const Color(0xFFF59E0B),
        subtitle: '최대 주차 기록',
      ),
      StatisticsCard(
        title: '총 주차 시간',
        value: _formatDuration(statistics.totalParkingTime),
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFFEC4899),
        subtitle: '누적 주차 시간',
      ),
    ];
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}일 ${duration.inHours % 24}시간';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes % 60}분';
    } else {
      return '${duration.inMinutes}분';
    }
  }
}
