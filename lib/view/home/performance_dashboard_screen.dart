import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/backend/performance_analytics_dashboard.dart';
import '../tab_screen/view-model/constants/constants.dart';

class PerformanceDashboardScreen extends StatefulWidget {
  const PerformanceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<PerformanceDashboardScreen> createState() =>
      _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState extends State<PerformanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  final PerformanceAnalyticsDashboard _dashboard =
      PerformanceAnalyticsDashboard();
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await _dashboard.initialize();
      final data = await _dashboard.getDashboardData();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Performance',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'tabfont',
            fontSize: 19,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontFamily: 'fontmain', fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.query_stats, size: 18), text: 'Queries'),
            Tab(icon: Icon(Icons.memory, size: 18), text: 'Memory'),
            Tab(icon: Icon(Icons.health_and_safety, size: 18), text: 'Health'),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryColor))
                : Icon(Icons.refresh, color: primaryColor),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.withOpacity(0.1),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildQueriesTab(),
                  _buildMemoryTab(),
                  _buildHealthTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final metrics = _data['realTimeMetrics'] ?? {};
    final trends = _data['performanceTrends'] ?? {};
    final healthScore = metrics['healthScore'] ?? 0;
    final status = metrics['systemStatus']?['status'] ?? 'Unknown';

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Health Score Card
          _buildHealthScoreCard(healthScore, status),
          const SizedBox(height: 16),

          // System Status
          _buildCard(
            'System Status',
            Icons.monitor_heart,
            _getStatusColor(status),
            [
              _buildStatusRow('Status', status, _getStatusColor(status)),
              _buildRow('Description',
                  metrics['systemStatus']?['description'] ?? 'N/A'),
              _buildRow('Active Alerts',
                  '${(metrics['activeAlerts'] as List?)?.length ?? 0}'),
            ],
          ),
          const SizedBox(height: 16),

          // Performance Trends
          _buildCard(
            'Performance Trends (7 Days)',
            Icons.trending_up,
            Colors.blue,
            [
              _buildTrendRow(
                  'Query Performance',
                  trends['queryPerformanceTrend']?['trend'] ?? 'N/A',
                  trends['queryPerformanceTrend']?['changePercent']),
              _buildTrendRow(
                  'Memory Usage',
                  trends['memoryUsageTrend']?['trend'] ?? 'N/A',
                  trends['memoryUsageTrend']?['changePercent']),
              _buildTrendRow(
                  'Alert Frequency',
                  trends['alertFrequencyTrend']?['trend'] ?? 'N/A',
                  trends['alertFrequencyTrend']?['changePercent']),
              _buildTrendRow(
                  'Health Score',
                  trends['healthScoreTrend']?['trend'] ?? 'N/A',
                  trends['healthScoreTrend']?['changePercent']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(int score, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            _getStatusColor(status).withOpacity(0.9),
            _getStatusColor(status).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'tabfont',
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'tabfont',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHealthDescription(score),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontFamily: 'fontmain',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueriesTab() {
    final queries = _data['queryAnalysis'] ?? {};
    final slowest = queries['slowestQueries'] as List? ?? [];
    final frequent = queries['mostFrequentQueries'] as List? ?? [];
    final overview = queries['overview'] ?? {};
    final distribution = queries['queryPerformanceDistribution'] ?? {};

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Query Overview
          _buildCard(
            'Query Overview',
            Icons.analytics,
            Colors.indigo,
            [
              _buildRow(
                  'Total Query Types', '${overview['totalQueryTypes'] ?? 0}'),
              _buildRow(
                  'Total Executions', '${overview['totalExecutions'] ?? 0}'),
              _buildRow('Avg Response Time',
                  '${(overview['averageResponseTime'] ?? 0).toStringAsFixed(1)} ms'),
              _buildRow('Slow Queries', '${overview['slowQueries'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 16),

          // Performance Distribution
          _buildCard(
            'Performance Distribution',
            Icons.pie_chart,
            Colors.purple,
            [
              _buildDistributionRow(
                  'Fast (<100ms)', distribution['fast'] ?? 0, Colors.green),
              _buildDistributionRow(
                  'Medium (100-500ms)', distribution['medium'] ?? 0, Colors.orange),
              _buildDistributionRow(
                  'Slow (500-1000ms)', distribution['slow'] ?? 0, Colors.deepOrange),
              _buildDistributionRow(
                  'Very Slow (>1000ms)', distribution['very_slow'] ?? 0, Colors.red),
            ],
          ),
          const SizedBox(height: 16),

          // Slowest Queries
          _buildSectionTitle('Slowest Queries (P95)', Icons.speed),
          const SizedBox(height: 8),
          if (slowest.isEmpty)
            _buildEmptyState('No query data available')
          else
            ...slowest.take(5).map((q) => _buildQueryCard(q, isSlowQuery: true)),

          const SizedBox(height: 16),

          // Most Frequent Queries
          _buildSectionTitle('Most Frequent Queries', Icons.repeat),
          const SizedBox(height: 8),
          if (frequent.isEmpty)
            _buildEmptyState('No query data available')
          else
            ...frequent.take(5).map((q) => _buildQueryCard(q, isSlowQuery: false)),
        ],
      ),
    );
  }

  Widget _buildQueryCard(Map<String, dynamic> q, {required bool isSlowQuery}) {
    final p95 = q['p95Ms'] ?? 0;
    final avg = q['averageMs'] ?? 0;
    final count = q['count'] ?? 0;
    final name = q['name'] ?? 'Unknown Query';

    Color getSpeedColor(int ms) {
      if (ms < 100) return primaryColor;
      if (ms < 500) return Colors.orange;
      if (ms < 1000) return Colors.deepOrange;
      return Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'tabfont',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getSpeedColor(isSlowQuery ? p95 : avg)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isSlowQuery ? p95 : avg}ms',
                  style: TextStyle(
                    color: getSpeedColor(isSlowQuery ? p95 : avg),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricChip('Avg', '$avg ms', primaryColor),
              const SizedBox(width: 6),
              _buildMetricChip('P95', '$p95 ms', Colors.purple),
              const SizedBox(width: 6),
              _buildMetricChip('Count', '$count', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildMemoryTab() {
    final memory = _data['memoryAnalysis'] ?? {};
    final overview = memory['overview'] ?? {};
    final breakdown = memory['memoryBreakdown'] ?? {};
    final cacheEfficiency = memory['cacheEfficiency'] ?? {};
    final suggestions = memory['memoryOptimizationSuggestions'] as List? ?? [];

    final currentUsage =
        double.tryParse(overview['currentUsageMB']?.toString() ?? '0') ?? 0;
    final peakUsage =
        double.tryParse(overview['peakUsageMB']?.toString() ?? '0') ?? 0;
    final utilization =
        double.tryParse(overview['utilizationPercent']?.toString() ?? '0') ?? 0;

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Memory Usage Card
          _buildMemoryUsageCard(currentUsage, peakUsage, utilization,
              overview['status'] ?? 'Unknown'),
          const SizedBox(height: 16),

          // Memory Breakdown
          _buildCard(
            'Memory Breakdown',
            Icons.donut_large,
            Colors.teal,
            [
              _buildRow('Total Memory', '${breakdown['totalMemory'] ?? 0} MB'),
              _buildRow('Image Cache',
                  '${(breakdown['imageCache'] ?? 0).toStringAsFixed(2)} MB'),
              _buildRow('Lazy Loading Cache',
                  '${(breakdown['lazyLoadingCache'] ?? 0).toStringAsFixed(2)} MB'),
            ],
          ),
          const SizedBox(height: 16),

          // Cache Efficiency
          _buildCard(
            'Cache Efficiency',
            Icons.speed,
            Colors.amber.shade700,
            [
              _buildProgressRow(
                  'Image Cache',
                  (cacheEfficiency['imageCacheEfficiency'] ?? 0).toDouble(),
                  Colors.green),
              _buildProgressRow(
                  'Lazy Loading',
                  (cacheEfficiency['lazyLoadingEfficiency'] ?? 0).toDouble(),
                  Colors.blue),
              _buildRow('Overall Health',
                  cacheEfficiency['overallCacheHealth'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),

          // Optimization Suggestions
          if (suggestions.isNotEmpty) ...[
            _buildSectionTitle('Optimization Suggestions', Icons.lightbulb),
            const SizedBox(height: 8),
            ...suggestions.map((s) => _buildSuggestionCard(s.toString())),
          ],
        ],
      ),
    );
  }

  Widget _buildMemoryUsageCard(
      double current, double peak, double utilization, String status) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMemoryGauge('Current', current, 200, primaryColor),
              _buildMemoryGauge('Peak', peak, 200, Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: utilization / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              utilization > 80
                  ? Colors.red
                  : utilization > 60
                      ? Colors.orange
                      : primaryColor,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Text(
            'Utilization: ${utilization.toStringAsFixed(1)}% - Status: $status',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontFamily: 'fontmain',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryGauge(
      String label, double value, double max, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: (value / max).clamp(0.0, 1.0),
                strokeWidth: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text('MB', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
      ],
    );
  }

  Widget _buildHealthTab() {
    final health = _data['healthAssessment'] ?? {};
    final recommendationsData = _data['recommendations'] ?? {};
    final alertAnalysis = _data['alertAnalysis'] ?? {};

    List recommendations = [];
    if (recommendationsData is Map) {
      recommendations =
          recommendationsData['performanceRecommendations'] as List? ??
              recommendationsData['prioritizedActions'] as List? ??
              [];
    } else if (recommendationsData is List) {
      recommendations = recommendationsData;
    }

    final alertOverview = alertAnalysis['overview'] ?? {};
    final alertsByLevel = alertAnalysis['alertsByLevel'] as Map? ?? {};

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Health Assessment Card
          _buildCard(
            'Health Assessment',
            Icons.health_and_safety,
            _getStatusColor(health['healthStatus'] ?? 'unknown'),
            [
              _buildStatusRow('Status', health['healthStatus'] ?? 'Unknown',
                  _getStatusColor(health['healthStatus'] ?? 'unknown')),
              _buildRow('Performance Grade', health['performanceGrade'] ?? 'N/A'),
              _buildRow('System Stability',
                  health['systemStability']?['stability'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),

          // Alert Summary
          _buildCard(
            'Alert Summary',
            Icons.notifications_active,
            Colors.orange,
            [
              _buildRow('Total Alerts', '${alertOverview['total'] ?? 0}'),
              _buildAlertRow(
                  'Critical', alertsByLevel['critical'] ?? 0, Colors.red),
              _buildAlertRow(
                  'Warning', alertsByLevel['warning'] ?? 0, Colors.orange),
              _buildAlertRow('Info', alertsByLevel['info'] ?? 0, Colors.blue),
            ],
          ),
          const SizedBox(height: 16),

          // Improvement Areas
          if ((health['improvementAreas'] as List?)?.isNotEmpty ?? false) ...[
            _buildSectionTitle('Improvement Areas', Icons.trending_up),
            const SizedBox(height: 8),
            ...(health['improvementAreas'] as List).map(
                (area) => _buildImprovementCard(area.toString())),
            const SizedBox(height: 16),
          ],

          // Recommendations
          _buildSectionTitle('Recommendations', Icons.lightbulb_outline),
          const SizedBox(height: 8),
          if (recommendations.isEmpty)
            _buildEmptyState('No recommendations at this time')
          else
            ...recommendations.take(5).map((r) => _buildRecommendationCard(r)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(dynamic r) {
    final Map<String, dynamic> rec = r is Map<String, dynamic> ? r : {};
    final title = rec['title'] ?? rec['category'] ?? 'Recommendation';
    final description = rec['description'] ?? rec['message'] ?? '';
    final priority = rec['priority']?.toString().split('.').last ?? 'medium';
    final impact = rec['estimatedImpact'] ?? 'Medium';

    Color getPriorityColor(String p) {
      switch (p.toLowerCase()) {
        case 'high':
          return Colors.red;
        case 'medium':
          return Colors.orange;
        default:
          return primaryColor;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getPriorityColor(priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: getPriorityColor(priority),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'tabfont',
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontFamily: 'fontmain',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flash_on, size: 14, color: primaryColor),
              const SizedBox(width: 4),
              Text(
                'Impact: $impact',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'fontmain',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildCard(
      String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'tabfont',
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontFamily: 'tabfont',
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontFamily: 'fontmain',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                fontFamily: 'fontmain',
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toUpperCase(),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendRow(String label, String trend, dynamic changePercent) {
    IconData icon;
    Color color;

    switch (trend.toLowerCase()) {
      case 'improving':
      case 'decreasing':
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case 'declining':
      case 'increasing':
        icon = Icons.trending_down;
        color = Colors.red;
        break;
      default:
        icon = Icons.trending_flat;
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
              if (changePercent != null) ...[
                const SizedBox(width: 4),
                Text(
                  '(${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%)',
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$count',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600)),
              Text('${(value * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.w500, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontFamily: 'fontmain',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(String suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(Icons.lightbulb, color: primaryColor, size: 20),
        title: Text(
          suggestion,
          style: const TextStyle(fontSize: 12, fontFamily: 'fontmain'),
        ),
      ),
    );
  }

  Widget _buildImprovementCard(String area) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(Icons.arrow_upward, color: primaryColor, size: 20),
        title: Text(
          area,
          style: const TextStyle(fontSize: 12, fontFamily: 'fontmain'),
        ),
      ),
    );
  }

  // Helper Methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getHealthDescription(int score) {
    if (score >= 90) return 'Excellent! System is performing optimally.';
    if (score >= 70) return 'Good performance with minor issues.';
    if (score >= 50) return 'Fair. Some areas need attention.';
    return 'Poor. Immediate attention required.';
  }
}
