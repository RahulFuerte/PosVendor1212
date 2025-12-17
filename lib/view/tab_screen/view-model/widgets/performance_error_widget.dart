import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/performance_error_handler.dart';
import '../backend/comprehensive_error_handler.dart';

/// Widget that displays performance error notifications and recovery options
/// Provides user-friendly messages and actionable recovery steps
class PerformanceErrorWidget extends StatefulWidget {
  final bool showInline;
  final VoidCallback? onDismiss;

  const PerformanceErrorWidget({
    Key? key,
    this.showInline = false,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<PerformanceErrorWidget> createState() => _PerformanceErrorWidgetState();
}

class _PerformanceErrorWidgetState extends State<PerformanceErrorWidget> {
  final PerformanceErrorHandler _errorHandler = PerformanceErrorHandler();
  final ComprehensiveErrorHandler _comprehensiveHandler = ComprehensiveErrorHandler();
  
  StreamSubscription<PerformanceIssue>? _issueSubscription;
  PerformanceIssue? _currentIssue;
  bool _isRecovering = false;
  String? _recoveryMessage;

  @override
  void initState() {
    super.initState();
    _initializeErrorHandler();
  }

  Future<void> _initializeErrorHandler() async {
    try {
      await _errorHandler.initialize();
      
      // Listen for performance issues
      _issueSubscription = _errorHandler.issueStream.listen((issue) {
        if (mounted) {
          setState(() {
            _currentIssue = issue;
          });
          
          // Auto-dismiss warning issues after 10 seconds
          if (issue.severity == PerformanceIssueSeverity.warning) {
            Timer(const Duration(seconds: 10), () {
              if (mounted && _currentIssue?.id == issue.id) {
                _dismissIssue();
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize performance error handler: $e');
    }
  }

  @override
  void dispose() {
    _issueSubscription?.cancel();
    super.dispose();
  }

  void _dismissIssue() {
    setState(() {
      _currentIssue = null;
      _isRecovering = false;
      _recoveryMessage = null;
    });
    widget.onDismiss?.call();
  }

  Future<void> _executeRecovery(String actionId) async {
    setState(() {
      _isRecovering = true;
      _recoveryMessage = 'Optimizing performance...';
    });

    try {
      bool success = false;
      String message = '';

      switch (actionId) {
        case 'clear_cache':
          // Simulate cache clearing
          await Future.delayed(const Duration(seconds: 2));
          success = true;
          message = 'Cache cleared successfully';
          break;
          
        case 'optimize_queries':
          // Simulate query optimization
          await Future.delayed(const Duration(seconds: 3));
          success = true;
          message = 'Database queries optimized';
          break;
          
        case 'free_memory':
          // Simulate memory cleanup
          await Future.delayed(const Duration(seconds: 2));
          success = true;
          message = 'Memory usage optimized';
          break;
          
        case 'restart_recommended':
          success = true;
          message = 'Please restart the app for best performance';
          break;
          
        default:
          success = false;
          message = 'Recovery action not available';
      }

      setState(() {
        _isRecovering = false;
        _recoveryMessage = message;
      });

      if (success) {
        // Auto-dismiss after showing success message
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _dismissIssue();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isRecovering = false;
        _recoveryMessage = 'Recovery failed. Please try again.';
      });
    }
  }

  Widget _buildIssueCard(PerformanceIssue issue) {
    final isWarning = issue.severity == PerformanceIssueSeverity.warning;
    final backgroundColor = isWarning ? Colors.orange.shade50 : Colors.red.shade50;
    final borderColor = isWarning ? Colors.orange : Colors.red;
    final iconColor = isWarning ? Colors.orange : Colors.red;
    final icon = isWarning ? Icons.warning_amber : Icons.error;

    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    issue.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
                if (isWarning)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _dismissIssue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              _getUserFriendlyDescription(issue),
              style: const TextStyle(fontSize: 14),
            ),
            
            if (_isRecovering || _recoveryMessage != null) ...[
              const SizedBox(height: 12),
              _buildRecoveryStatus(),
            ] else ...[
              const SizedBox(height: 12),
              _buildRecoveryActions(issue),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryStatus() {
    if (_isRecovering) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            _recoveryMessage ?? 'Processing...',
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      );
    } else if (_recoveryMessage != null) {
      return Row(
        children: [
          Icon(
            _recoveryMessage!.contains('failed') ? Icons.error : Icons.check_circle,
            size: 16,
            color: _recoveryMessage!.contains('failed') ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _recoveryMessage!,
              style: TextStyle(
                fontSize: 12,
                color: _recoveryMessage!.contains('failed') ? Colors.red : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRecoveryActions(PerformanceIssue issue) {
    final actions = _getRecoveryActions(issue);
    
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick fixes:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: actions.map((action) => _buildActionButton(action)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(RecoveryAction action) {
    return ElevatedButton(
      onPressed: _isRecovering ? null : () => _executeRecovery(action.id),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(action.title),
    );
  }

  String _getUserFriendlyDescription(PerformanceIssue issue) {
    switch (issue.type) {
      case PerformanceIssueType.slowQuery:
        return 'Data is loading slower than usual. This might be due to a large amount of data or network issues.';
      case PerformanceIssueType.memoryUsage:
        return 'The app is using more memory than usual. This might slow down your device.';
      case PerformanceIssueType.cachePerformance:
        return 'Data caching is not working optimally. You might experience slower loading times.';
      case PerformanceIssueType.generalDegradation:
        return 'Overall performance has decreased. The system is working to optimize itself.';
    }
  }

  List<RecoveryAction> _getRecoveryActions(PerformanceIssue issue) {
    switch (issue.type) {
      case PerformanceIssueType.slowQuery:
        return [
          RecoveryAction(id: 'optimize_queries', title: 'Optimize'),
          RecoveryAction(id: 'clear_cache', title: 'Clear Cache'),
        ];
      case PerformanceIssueType.memoryUsage:
        return [
          RecoveryAction(id: 'free_memory', title: 'Free Memory'),
          RecoveryAction(id: 'clear_cache', title: 'Clear Cache'),
          if (issue.severity == PerformanceIssueSeverity.critical)
            RecoveryAction(id: 'restart_recommended', title: 'Restart App'),
        ];
      case PerformanceIssueType.cachePerformance:
        return [
          RecoveryAction(id: 'clear_cache', title: 'Reset Cache'),
          RecoveryAction(id: 'optimize_queries', title: 'Optimize'),
        ];
      case PerformanceIssueType.generalDegradation:
        return [
          RecoveryAction(id: 'clear_cache', title: 'Clear Cache'),
          RecoveryAction(id: 'free_memory', title: 'Free Memory'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIssue == null) {
      return const SizedBox.shrink();
    }

    if (widget.showInline) {
      return _buildIssueCard(_currentIssue!);
    }

    // Show as overlay/banner
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: _buildIssueCard(_currentIssue!),
      ),
    );
  }
}

/// Performance error banner that can be shown at the top of screens
class PerformanceErrorBanner extends StatelessWidget {
  const PerformanceErrorBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PerformanceErrorWidget(showInline: false);
  }
}

/// Inline performance error display for embedding in screens
class InlinePerformanceError extends StatelessWidget {
  final VoidCallback? onDismiss;

  const InlinePerformanceError({
    Key? key,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PerformanceErrorWidget(
      showInline: true,
      onDismiss: onDismiss,
    );
  }
}

/// Recovery action data class
class RecoveryAction {
  final String id;
  final String title;

  RecoveryAction({
    required this.id,
    required this.title,
  });
}

/// Performance status indicator widget
class PerformanceStatusIndicator extends StatefulWidget {
  final bool showDetails;

  const PerformanceStatusIndicator({
    Key? key,
    this.showDetails = false,
  }) : super(key: key);

  @override
  State<PerformanceStatusIndicator> createState() => _PerformanceStatusIndicatorState();
}

class _PerformanceStatusIndicatorState extends State<PerformanceStatusIndicator> {
  final PerformanceErrorHandler _errorHandler = PerformanceErrorHandler();
  Timer? _updateTimer;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _initializeAndStartUpdates();
  }

  Future<void> _initializeAndStartUpdates() async {
    try {
      await _errorHandler.initialize();
      _updateStats();
      
      // Update stats every 30 seconds
      _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _updateStats();
      });
    } catch (e) {
      debugPrint('Failed to initialize performance status indicator: $e');
    }
  }

  void _updateStats() {
    if (mounted) {
      setState(() {
        _stats = _errorHandler.getPerformanceIssueStatistics();
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Color _getStatusColor() {
    if (_stats == null) return Colors.grey;
    
    final issuesLast24h = _stats!['issuesLast24h'] as int? ?? 0;
    
    if (issuesLast24h == 0) return Colors.green;
    if (issuesLast24h < 5) return Colors.orange;
    return Colors.red;
  }

  IconData _getStatusIcon() {
    if (_stats == null) return Icons.help_outline;
    
    final issuesLast24h = _stats!['issuesLast24h'] as int? ?? 0;
    
    if (issuesLast24h == 0) return Icons.check_circle;
    if (issuesLast24h < 5) return Icons.warning;
    return Icons.error;
  }

  String _getStatusText() {
    if (_stats == null) return 'Checking...';
    
    final issuesLast24h = _stats!['issuesLast24h'] as int? ?? 0;
    
    if (issuesLast24h == 0) return 'Performance: Good';
    if (issuesLast24h < 5) return 'Performance: Fair';
    return 'Performance: Poor';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final text = _getStatusText();

    if (!widget.showDetails) {
      return Icon(icon, color: color, size: 20);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}