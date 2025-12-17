import 'package:flutter/material.dart';
import '../backend/performance_error_handler.dart';
import '../backend/performance_error_integration.dart';
import 'performance_error_widget.dart';

/// Example screen showing how to integrate performance error handling
/// Demonstrates proper usage of performance monitoring and error recovery
class PerformanceErrorExample extends StatefulWidget {
  const PerformanceErrorExample({Key? key}) : super(key: key);

  @override
  State<PerformanceErrorExample> createState() => _PerformanceErrorExampleState();
}

class _PerformanceErrorExampleState extends State<PerformanceErrorExample> {
  final PerformanceErrorHandler _errorHandler = PerformanceErrorHandler();
  final PerformanceErrorIntegration _integration = PerformanceErrorIntegration();
  
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';
  Map<String, dynamic>? _performanceStats;

  @override
  void initState() {
    super.initState();
    _initializePerformanceHandling();
  }

  Future<void> _initializePerformanceHandling() async {
    try {
      await _errorHandler.initialize();
      await _integration.initialize();
      
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Performance monitoring active';
      });
      
      _updatePerformanceStats();
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize: $e';
      });
    }
  }

  void _updatePerformanceStats() {
    if (_integration.isInitialized) {
      setState(() {
        _performanceStats = _integration.getPerformanceStatus();
      });
    }
  }

  /// Simulate a slow database query to trigger performance error handling
  Future<void> _simulateSlowQuery() async {
    setState(() {
      _statusMessage = 'Executing slow query...';
    });

    try {
      // Simulate slow operation
      await Future.delayed(const Duration(seconds: 2));
      
      // Trigger performance error handling
      await _errorHandler.handleSlowQuery(
        queryName: 'simulate_slow_query',
        executionTimeMs: 2000,
        context: 'user_simulation',
        queryParameters: {'table': 'food_items', 'limit': 1000},
      );
      
      setState(() {
        _statusMessage = 'Slow query completed - check performance notifications';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  /// Simulate high memory usage to trigger memory error handling
  Future<void> _simulateMemoryIssue() async {
    setState(() {
      _statusMessage = 'Simulating memory issue...';
    });

    try {
      // Trigger memory error handling
      await _errorHandler.handleMemoryIssue(
        currentMemoryMB: 200.5,
        operation: 'simulate_memory_usage',
        context: 'user_simulation',
      );
      
      setState(() {
        _statusMessage = 'Memory issue simulated - check performance notifications';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  /// Simulate poor cache performance to trigger cache error handling
  Future<void> _simulateCacheIssue() async {
    setState(() {
      _statusMessage = 'Simulating cache issue...';
    });

    try {
      // Trigger cache performance error handling
      await _errorHandler.handleCachePerformanceIssue(
        hitRate: 0.3,
        cacheType: 'simulate_cache',
        context: 'user_simulation',
      );
      
      setState(() {
        _statusMessage = 'Cache issue simulated - check performance notifications';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  /// Execute a performance recovery action
  Future<void> _executeRecovery(String actionType) async {
    setState(() {
      _statusMessage = 'Executing recovery: $actionType...';
    });

    try {
      final success = await _integration.executePerformanceRecovery(actionType);
      
      setState(() {
        _statusMessage = success 
            ? 'Recovery completed successfully'
            : 'Recovery failed - please try again';
      });
      
      _updatePerformanceStats();
    } catch (e) {
      setState(() {
        _statusMessage = 'Recovery error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Error Handling Demo'),
        actions: [
          const PerformanceStatusIndicator(showDetails: true),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance Monitoring Status',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _isInitialized ? Icons.check_circle : Icons.error,
                              color: _isInitialized ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_statusMessage),
                            ),
                          ],
                        ),
                        if (_isInitialized) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Health Score: ${_integration.getPerformanceHealthScore()}/100',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Simulation Controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Simulate Performance Issues',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        
                        ElevatedButton.icon(
                          onPressed: _isInitialized ? _simulateSlowQuery : null,
                          icon: const Icon(Icons.query_stats),
                          label: const Text('Simulate Slow Query'),
                        ),
                        const SizedBox(height: 8),
                        
                        ElevatedButton.icon(
                          onPressed: _isInitialized ? _simulateMemoryIssue : null,
                          icon: const Icon(Icons.memory),
                          label: const Text('Simulate Memory Issue'),
                        ),
                        const SizedBox(height: 8),
                        
                        ElevatedButton.icon(
                          onPressed: _isInitialized ? _simulateCacheIssue : null,
                          icon: const Icon(Icons.cached),
                          label: const Text('Simulate Cache Issue'),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Recovery Actions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance Recovery Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: _isInitialized 
                                  ? () => _executeRecovery('clear_query_cache')
                                  : null,
                              child: const Text('Clear Query Cache'),
                            ),
                            ElevatedButton(
                              onPressed: _isInitialized 
                                  ? () => _executeRecovery('clear_image_cache')
                                  : null,
                              child: const Text('Clear Image Cache'),
                            ),
                            ElevatedButton(
                              onPressed: _isInitialized 
                                  ? () => _executeRecovery('force_garbage_collection')
                                  : null,
                              child: const Text('Force GC'),
                            ),
                            ElevatedButton(
                              onPressed: _isInitialized 
                                  ? () => _executeRecovery('optimize_database')
                                  : null,
                              child: const Text('Optimize Database'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Performance Statistics
                if (_performanceStats != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Statistics',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildStatRow('Monitoring Active', 
                              _performanceStats!['monitoringActive'].toString()),
                          _buildStatRow('Health Score', 
                              '${_integration.getPerformanceHealthScore()}/100'),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'Recommendations:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          
                          ..._integration.getUserRecommendations().map(
                            (rec) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(rec)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 80), // Space for floating notifications
              ],
            ),
          ),
          
          // Performance Error Notifications (overlay)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PerformanceErrorBanner(),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _updatePerformanceStats,
        tooltip: 'Refresh Stats',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Example of integrating performance error handling into an existing screen
class ExistingScreenWithPerformanceHandling extends StatefulWidget {
  const ExistingScreenWithPerformanceHandling({Key? key}) : super(key: key);

  @override
  State<ExistingScreenWithPerformanceHandling> createState() => 
      _ExistingScreenWithPerformanceHandlingState();
}

class _ExistingScreenWithPerformanceHandlingState 
    extends State<ExistingScreenWithPerformanceHandling> {
  final PerformanceErrorIntegration _integration = PerformanceErrorIntegration();
  
  List<String> _data = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePerformanceHandling();
  }

  Future<void> _initializePerformanceHandling() async {
    try {
      await _integration.initialize();
    } catch (e) {
      debugPrint('Failed to initialize performance handling: $e');
    }
  }

  /// Example of wrapping a database operation with performance monitoring
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Wrap the database operation with performance monitoring
      final data = await _integration.monitorDatabaseOperation(
        'load_example_data',
        () async {
          // Simulate database query
          await Future.delayed(const Duration(milliseconds: 800));
          return List.generate(100, (index) => 'Item $index');
        },
      );

      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Error is already handled by the performance integration
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  /// Example of wrapping a memory-intensive operation with monitoring
  Future<void> _processLargeDataset() async {
    try {
      await _integration.monitorMemoryOperation(
        'process_large_dataset',
        () async {
          // Simulate memory-intensive operation
          final largeList = List.generate(10000, (index) => 'Data $index');
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Process the data
          largeList.sort();
          return largeList.length;
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Large dataset processed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process dataset: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen with Performance Handling'),
        actions: const [
          PerformanceStatusIndicator(showDetails: true),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Inline performance error display
              const InlinePerformanceError(),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loadData,
                        child: _isLoading 
                            ? const CircularProgressIndicator()
                            : const Text('Load Data'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _processLargeDataset,
                        child: const Text('Process Large Dataset'),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Data display
              Expanded(
                child: _data.isEmpty
                    ? const Center(
                        child: Text('No data loaded. Tap "Load Data" to start.'),
                      )
                    : ListView.builder(
                        itemCount: _data.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_data[index]),
                            subtitle: Text('Index: $index'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}