import 'dart:typed_data';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../backend/database_service.dart';
import 'ui_performance_components.dart';

/// Enhanced progressive image loader with smooth transitions and performance optimizations
class ProgressiveImageLoader extends StatefulWidget {
  final String imageUrl;
  final String tableName;
  final String recordId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool enableHeroAnimation;
  final String? heroTag;

  const ProgressiveImageLoader({
    Key? key,
    required this.imageUrl,
    required this.tableName,
    required this.recordId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableHeroAnimation = false,
    this.heroTag,
  }) : super(key: key);

  @override
  State<ProgressiveImageLoader> createState() => _ProgressiveImageLoaderState();
}

class _ProgressiveImageLoaderState extends State<ProgressiveImageLoader>
    with TickerProviderStateMixin {
  Uint8List? _blobData;
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadImage();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
  }

  /// Retry loading the image with smooth animation
  Future<void> retryLoad() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _blobData = null;
    });
    
    _fadeController.reset();
    _scaleController.reset();
    
    await _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final DatabaseService databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // First try to get image from BLOB cache (offline-first approach)
      final blobData = await databaseService.getImageBlob(widget.tableName, widget.recordId);
      
      if (blobData != null && blobData.isNotEmpty) {
        developer.log('Image loaded from BLOB cache for ${widget.tableName}:${widget.recordId}', name: 'ProgressiveImageLoader');
        await _setImageData(blobData);
        return;
      }
      
      // If BLOB not available, check connectivity and try to download
      final isOnline = await databaseService.isOnline();
      if (isOnline && widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A') {
        try {
          developer.log('Attempting to download and cache image: ${widget.imageUrl}', name: 'ProgressiveImageLoader');
          final downloadedData = await databaseService.downloadAndCacheImage(
            widget.imageUrl,
            tableName: widget.tableName,
            recordId: widget.recordId,
          );
          
          if (downloadedData != null && downloadedData.isNotEmpty) {
            developer.log('Image downloaded and cached successfully for ${widget.tableName}:${widget.recordId}', name: 'ProgressiveImageLoader');
            await _setImageData(downloadedData);
            return;
          }
        } catch (e) {
          // Handle specific network errors gracefully
          if (e is SocketException) {
            developer.log('Network error downloading image: ${e.message}. Falling back to network image widget.', name: 'ProgressiveImageLoader');
          } else {
            developer.log('Failed to download and cache image: $e', name: 'ProgressiveImageLoader');
          }
          // Don't set error state here, let CachedNetworkImage handle it
        }
      } else {
        developer.log('Offline mode or invalid URL, skipping download for ${widget.tableName}:${widget.recordId}', name: 'ProgressiveImageLoader');
      }
      
      // Continue to network image fallback or show appropriate state
      setState(() {
        _isLoading = false;
      });
      
      // Start fade animation for network image
      _fadeController.forward();
      _scaleController.forward();
      
    } catch (e) {
      developer.log('Error in _loadImage: $e', name: 'ProgressiveImageLoader');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _setImageData(Uint8List data) async {
    if (!mounted) return;
    
    setState(() {
      _blobData = data;
      _isLoading = false;
    });
    
    // Start smooth animations
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Widget _buildLoadingPlaceholder() {
    return widget.placeholder ?? 
      OptimizedImagePlaceholder(
        width: widget.width,
        height: widget.height,
        icon: Icons.image_outlined,
        text: 'Loading...',
      );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? 
      OptimizedImagePlaceholder(
        width: widget.width,
        height: widget.height,
        icon: Icons.broken_image_outlined,
        text: 'Image not available',
      );
  }

  Widget _buildImageWidget(Widget imageWidget) {
    Widget result = AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: imageWidget,
          ),
        );
      },
    );

    // Wrap with Hero animation if enabled
    if (widget.enableHeroAnimation && widget.heroTag != null) {
      result = Hero(
        tag: widget.heroTag!,
        child: result,
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingPlaceholder();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    // If we have BLOB data, use it
    if (_blobData != null) {
      return _buildImageWidget(
        Image.memory(
          _blobData!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        ),
      );
    }

    // Fallback to network image if BLOB not available
    if (widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A') {
      return _buildImageWidget(
        CachedNetworkImage(
          imageUrl: widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) => _buildLoadingPlaceholder(),
          errorWidget: (context, url, error) {
            // Log network errors for debugging
            if (error is SocketException) {
              developer.log('Network image failed to load due to connectivity: ${error.message}', name: 'ProgressiveImageLoader');
            } else {
              developer.log('Network image failed to load: $error', name: 'ProgressiveImageLoader');
            }
            
            return GestureDetector(
              onTap: error is SocketException ? retryLoad : null,
              child: OptimizedImagePlaceholder(
                width: widget.width,
                height: widget.height,
                icon: error is SocketException ? Icons.wifi_off : Icons.broken_image_outlined,
                text: error is SocketException ? 'Tap to retry' : 'Image not available',
              ),
            );
          },
          fadeInDuration: widget.fadeInDuration,
          fadeOutDuration: const Duration(milliseconds: 200),
        ),
      );
    }

    // If no image URL, show error widget
    return _buildErrorWidget();
  }
}

/// Enhanced cached blob image with progressive loading
class EnhancedCachedBlobImage extends StatelessWidget {
  final String imageUrl;
  final String tableName;
  final String recordId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableProgressiveLoading;
  final bool enableHeroAnimation;
  final String? heroTag;

  const EnhancedCachedBlobImage({
    Key? key,
    required this.imageUrl,
    required this.tableName,
    required this.recordId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableProgressiveLoading = true,
    this.enableHeroAnimation = false,
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (enableProgressiveLoading) {
      return ProgressiveImageLoader(
        imageUrl: imageUrl,
        tableName: tableName,
        recordId: recordId,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        enableHeroAnimation: enableHeroAnimation,
        heroTag: heroTag,
      );
    }

    // Fallback to basic cached blob image
    return ProgressiveImageLoader(
      imageUrl: imageUrl,
      tableName: tableName,
      recordId: recordId,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: Duration.zero,
      enableHeroAnimation: enableHeroAnimation,
      heroTag: heroTag,
    );
  }
}

/// Image loading state manager for better performance
class ImageLoadingStateManager {
  static final Map<String, bool> _loadingStates = {};
  static final Map<String, Uint8List?> _imageCache = {};

  static String _generateKey(String tableName, String recordId) {
    return '${tableName}_$recordId';
  }

  static bool isLoading(String tableName, String recordId) {
    final key = _generateKey(tableName, recordId);
    return _loadingStates[key] ?? false;
  }

  static void setLoading(String tableName, String recordId, bool loading) {
    final key = _generateKey(tableName, recordId);
    _loadingStates[key] = loading;
  }

  static Uint8List? getCachedImage(String tableName, String recordId) {
    final key = _generateKey(tableName, recordId);
    return _imageCache[key];
  }

  static void setCachedImage(String tableName, String recordId, Uint8List? data) {
    final key = _generateKey(tableName, recordId);
    if (data != null) {
      _imageCache[key] = data;
    } else {
      _imageCache.remove(key);
    }
  }

  static void clearCache() {
    _loadingStates.clear();
    _imageCache.clear();
  }

  static void clearCacheForTable(String tableName) {
    _loadingStates.removeWhere((key, value) => key.startsWith('${tableName}_'));
    _imageCache.removeWhere((key, value) => key.startsWith('${tableName}_'));
  }
}