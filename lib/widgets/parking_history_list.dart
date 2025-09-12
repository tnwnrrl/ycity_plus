import 'package:flutter/material.dart';
import '../models/parking_history.dart';
import 'parking_history_card.dart';

/// 재사용 가능한 주차 이력 리스트 위젯
class ParkingHistoryList extends StatelessWidget {
  final List<ParkingHistory> history;
  final String emptyMessage;
  final IconData emptyIcon;
  final Function(ParkingHistory)? onTap;
  final Function(ParkingHistory)? onLongPress;
  final bool showHeader;
  final String? headerTitle;

  const ParkingHistoryList({
    super.key,
    required this.history,
    this.emptyMessage = '주차 이력이 없습니다',
    this.emptyIcon = Icons.history_rounded,
    this.onTap,
    this.onLongPress,
    this.showHeader = false,
    this.headerTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader && headerTitle != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              headerTitle!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.grey.shade900,
              ),
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final parking = history[index];
              return ParkingHistoryCard(
                parking: parking,
                index: index,
                onTap: onTap != null ? () => onTap!(parking) : null,
                onLongPress:
                    onLongPress != null ? () => onLongPress!(parking) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Icon(
              emptyIcon,
              size: 32,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '주차 후 자동으로 기록됩니다',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 주차 이력 리스트 변형 - 요약 버전
class ParkingHistorySummaryList extends StatelessWidget {
  final List<ParkingHistory> history;
  final int maxItems;
  final VoidCallback? onSeeAll;
  final Function(ParkingHistory)? onTap;

  const ParkingHistorySummaryList({
    super.key,
    required this.history,
    this.maxItems = 5,
    this.onSeeAll,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayHistory = history.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '최근 주차 이력',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.grey.shade900,
                ),
              ),
              if (history.length > maxItems && onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '전체 보기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 리스트
        if (displayHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                '주차 이력이 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ...displayHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final parking = entry.value;
            return ParkingHistoryCard(
              parking: parking,
              index: index,
              onTap: onTap != null ? () => onTap!(parking) : null,
            );
          }),
      ],
    );
  }
}
