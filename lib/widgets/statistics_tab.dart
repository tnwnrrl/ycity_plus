import 'package:flutter/material.dart';
import '../models/parking_history.dart';
import 'statistics_card.dart';

/// 재사용 가능한 통계 탭 위젯
class StatisticsTab extends StatelessWidget {
  final ParkingStatistics statistics;
  final Map<String, int> floorUsage;
  final Future<void> Function()? onRefresh;

  const StatisticsTab({
    super.key,
    required this.statistics,
    required this.floorUsage,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 통계 카드 생성
    final statisticsCards = StatisticsUtils.buildStatisticsCards(statistics);

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: const Color(0xFF6366F1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 통계 카드 그리드
            _buildStatisticsGrid(context, statisticsCards),

            const SizedBox(height: 24),

            // 층별 사용 현황
            _buildFloorUsageSection(context),

            const SizedBox(height: 24),

            // 최근 이력 요약
            if (statistics.recentHistory.isNotEmpty)
              _buildRecentHistorySection(context),

            const SizedBox(height: 24),

            // 데이터 안내
            _buildDataNotice(context),

            const SizedBox(height: 80), // FAB 공간
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(
    BuildContext context,
    List<StatisticsCard> cards,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주차 통계',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        ),
      ],
    );
  }

  Widget _buildFloorUsageSection(BuildContext context) {
    if (floorUsage.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedFloors = floorUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sortedFloors.isNotEmpty ? sortedFloors.first.value : 1;

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 20,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '층별 이용 현황',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 층별 사용 현황 리스트
          ...sortedFloors.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FloorUsageCard(
                  floor: entry.key,
                  count: entry.value,
                  maxCount: maxCount,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecentHistorySection(BuildContext context) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '최근 주차 이력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 최근 3개 이력만 표시
          ...statistics.recentHistory.take(3).map((history) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.3)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color:
                          _getFloorColor(history.floor).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        history.floor,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getFloorColor(history.floor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${history.floor} 주차',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          history.entryTimeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    history.parkingDurationText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getFloorColor(history.floor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataNotice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '통계는 자동으로 수집된 주차 이력을 바탕으로 계산됩니다.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey.shade700,
              ),
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
        return Colors.grey.shade500;
    }
  }
}
