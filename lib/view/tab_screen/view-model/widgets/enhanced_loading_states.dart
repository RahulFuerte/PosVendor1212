// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'ui_performance_components.dart';

/// Enhanced loading states with smooth transitions and performance optimizations
class EnhancedLoadingStates {
  
  /// Create a grid of skeleton items for food items
  static Widget buildFoodItemSkeletonGrid({
    required BuildContext context,
    int itemCount = 6,
    int? crossAxisCount,
    double childAspectRatio = 0.78,
  }) {
    final actualCrossAxisCount = crossAxisCount ?? GridLayoutHelper.calculateCrossAxisCount(context);
    
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: actualCrossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          delay: const Duration(milliseconds: 50),
          child: const FoodItemSkeleton(),
        );
      },
    );
  }

  /// Create a list of skeleton items for departments
  static Widget buildDepartmentSkeletonList({
    int itemCount = 5,
    Axis scrollDirection = Axis.vertical,
  }) {
    return ListView.builder(
      scrollDirection: scrollDirection,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: AnimatedListItem(
            index: index,
            delay: const Duration(milliseconds: 100),
            child: const DepartmentSkeleton(),
          ),
        );
      },
    );
  }

  /// Create a smooth loading overlay
  static Widget buildLoadingOverlay({
    required Widget child,
    required bool isLoading,
    String loadingMessage = 'Loading...',
    Color? overlayColor,
  }) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor ?? Colors.black.withOpacity(0.3),
            child: SmoothLoadingState(message: loadingMessage),
          ),
      ],
    );
  }

  /// Create a pull-to-refresh loading state
  static Widget buildPullToRefreshLoading() {
    return const SizedBox(
      height: 80,
      child: Center(
        child: SmoothLoadingState(
          message: 'Refreshing...',
          size: 30,
        ),
      ),
    );
  }

  /// Create a load more loading state for infinite scroll
  static Widget buildLoadMoreIndicator({
    bool isLoading = true,
    String message = 'Loading more...',
  }) {
    if (!isLoading) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced state management for loading states
class LoadingStateManager extends ChangeNotifier {
  final Map<String, bool> _loadingStates = {};
  final Map<String, String> _loadingMessages = {};
  final Map<String, Timer?> _loadingTimers = {};

  bool isLoading(String key) => _loadingStates[key] ?? false;
  String getLoadingMessage(String key) => _loadingMessages[key] ?? 'Loading...';

  void setLoading(String key, bool loading, {String? message}) {
    final wasLoading = _loadingStates[key] ?? false;
    _loadingStates[key] = loading;
    
    if (message != null) {
      _loadingMessages[key] = message;
    }

    // Cancel existing timer
    _loadingTimers[key]?.cancel();

    if (loading) {
      // Set a maximum loading time to prevent infinite loading
      _loadingTimers[key] = Timer(const Duration(seconds: 30), () {
        if (_loadingStates[key] == true) {
          _loadingStates[key] = false;
          _loadingMessages[key] = 'Loading timeout';
          notifyListeners();
        }
      });
    } else {
      _loadingTimers[key] = null;
    }

    if (wasLoading != loading) {
      notifyListeners();
    }
  }

  void clearLoading(String key) {
    _loadingStates.remove(key);
    _loadingMessages.remove(key);
    _loadingTimers[key]?.cancel();
    _loadingTimers.remove(key);
    notifyListeners();
  }

  void clearAllLoading() {
    _loadingStates.clear();
    _loadingMessages.clear();
    for (final timer in _loadingTimers.values) {
      timer?.cancel();
    }
    _loadingTimers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _loadingTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }
}

/// Smooth transition builder for state changes
class SmoothStateTransition extends StatefulWidget {
  final Widget child;
  final bool condition;
  final Widget Function(BuildContext context) loadingBuilder;
  final Duration duration;

  const SmoothStateTransition({
    Key? key,
    required this.child,
    required this.condition,
    required this.loadingBuilder,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<SmoothStateTransition> createState() => _SmoothStateTransitionState();
}

class _SmoothStateTransitionState extends State<SmoothStateTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Widget? _currentChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _currentChild = widget.condition ? widget.loadingBuilder(context) : widget.child;
    _controller.forward();
  }

  @override
  void didUpdateWidget(SmoothStateTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.condition != oldWidget.condition) {
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentChild = widget.condition ? widget.loadingBuilder(context) : widget.child;
          });
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: _currentChild,
    );
  }
}

/// Enhanced error state with retry functionality
class EnhancedErrorState extends StatelessWidget {
  final String message;
  final String? description;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? color;

  const EnhancedErrorState({
    Key? key,
    required this.message,
    this.description,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: color ?? Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color ?? Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state widget with smooth animations
class EnhancedEmptyState extends StatefulWidget {
  final String message;
  final String? description;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionText;

  const EnhancedEmptyState({
    Key? key,
    required this.message,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionText,
  }) : super(key: key);

  @override
  State<EnhancedEmptyState> createState() => _EnhancedEmptyStateState();
}

class _EnhancedEmptyStateState extends State<EnhancedEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.description!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (widget.onAction != null && widget.actionText != null) ...[
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: widget.onAction,
                        icon: const Icon(Icons.add),
                        label: Text(widget.actionText!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
