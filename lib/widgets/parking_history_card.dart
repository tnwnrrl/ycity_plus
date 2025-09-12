import 'package:flutter/material.dart';
import '../models/parking_history.dart';

/// 재사용 가능한 주차 이력 카드 위젯
class ParkingHistoryCard extends StatelessWidget {
  final ParkingHistory parking;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ParkingHistoryCard({
    super.key,
    required this.parking,
    required this.index,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getFloorColor(parking.floor).withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 층 정보 아이콘
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color:
                        _getFloorColor(parking.floor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      parking.floor,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _getFloorColor(parking.floor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 주차 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${parking.floor} 주차',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.white : Colors.grey.shade900,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: parking.exitTime != null
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : const Color(0xFF6366F1)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              parking.exitTime != null ? '출차 완료' : '주차 중',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: parking.exitTime != null
                                    ? Colors.green.shade700
                                    : const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        '입차',
                        _formatDateTime(parking.entryTime),
                        Icons.login_rounded,
                      ),
                      if (parking.exitTime != null) ...[
                        const SizedBox(height: 4),
                        _buildDetailRow(
                          context,
                          '출차',
                          _formatDateTime(parking.exitTime!),
                          Icons.logout_rounded,
                        ),
                      ],
                      if (parking.parkingDurationMinutes > 0) ...[
                        const SizedBox(height: 4),
                        _buildDetailRow(
                          context,
                          '주차 시간',
                          _formatDuration(parking.parkingDurationMinutes),
                          Icons.access_time_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.grey.shade500,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Color _getFloorColor(String floor) {
    switch (floor.toUpperCase()) {
      case 'B1':
        return const Color(0xFF6366F1); // Indigo
      case 'B2':
        return const Color(0xFF8B5CF6); // Violet
      case 'B3':
        return const Color(0xFFF59E0B); // Amber
      case 'B4':
        return const Color(0xFFEC4899); // Pink
      case '출차됨':
        return Colors.grey.shade500;
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // 오늘
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // 어제
      return '어제 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // 그 외
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes분';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      if (remainingMinutes == 0) {
        return '$hours시간';
      } else {
        return '$hours시간 $remainingMinutes분';
      }
    }
  }
}
