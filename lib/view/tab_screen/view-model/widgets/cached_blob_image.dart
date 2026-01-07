import 'dart:typed_data';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/database_service.dart';


/// A widget that displays images from BLOB cache when available, 
/// falling back to network images when offline or BLOB not available
class CachedBlobImage extends StatefulWidget {
  final String imageUrl;
  final String tableName;
  final String recordId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedBlobImage({
    Key? key,
    required this.imageUrl,
    required this.tableName,
    required this.recordId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<CachedBlobImage> createState() => _CachedBlobImageState();
}

class _CachedBlobImageState extends State<CachedBlobImage> {
  Uint8List? _blobData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  /// Retry loading the image (useful when connectivity is restored)
  Future<void> retryLoad() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _blobData = null;
    });
    
    await _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final DatabaseService databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // First try to get image from BLOB cache (offline-first approach)
      final blobData = await databaseService.getImageBlob(widget.tableName, widget.recordId);
      
      if (blobData != null && blobData.isNotEmpty) {
        developer.log('Image loaded from BLOB cache for ${widget.tableName}:${widget.recordId}', name: 'CachedBlobImage');
        if (mounted) {
          setState(() {
            _blobData = blobData;
            _isLoading = false;
          });
        }
        return;
      }
      
      // If BLOB not available, check connectivity and try to download
      final isOnline = await databaseService.isOnline();
      if (isOnline && widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A') {
        try {
          developer.log('Attempting to download and cache image: ${widget.imageUrl}', name: 'CachedBlobImage');
          final downloadedData = await databaseService.downloadAndCacheImage(
            widget.imageUrl,
            tableName: widget.tableName,
            recordId: widget.recordId,
          );
          
          if (downloadedData != null && downloadedData.isNotEmpty) {
            developer.log('Image downloaded and cached successfully for ${widget.tableName}:${widget.recordId}', name: 'CachedBlobImage');
            if (mounted) {
              setState(() {
                _blobData = downloadedData;
                _isLoading = false;
              });
            }
            return;
          }
        } catch (e) {
          // Handle specific network errors gracefully
          if (e is SocketException) {
            developer.log('Network error downloading image: ${e.message}. Falling back to network image widget.', name: 'CachedBlobImage');
          } else {
            developer.log('Failed to download and cache image: $e', name: 'CachedBlobImage');
          }
          // Don't set error state here, let CachedNetworkImage handle it
        }
      } else {
        developer.log('Offline mode or invalid URL, skipping download for ${widget.tableName}:${widget.recordId}', name: 'CachedBlobImage');
      }
      
      // Continue to network image fallback or show appropriate state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
    } catch (e) {
      developer.log('Error in _loadImage: $e', name: 'CachedBlobImage');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? 
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          ),
        );
    }

    if (_hasError) {
      return widget.errorWidget ?? 
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Icon(Icons.error),
        );
    }

    // If we have BLOB data, use it
    if (_blobData != null) {
      Widget imageWidget = Image.memory(
        _blobData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? 
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[200],
              child: const Icon(Icons.error),
            );
        },
      );
      
      if (widget.borderRadius != null) {
        return ClipRRect(
          borderRadius: widget.borderRadius!,
          child: imageWidget,
        );
      }
      return imageWidget;
    }

    // Fallback to network image if BLOB not available
    if (widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A') {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        imageBuilder: widget.borderRadius != null
            ? (context, imageProvider) => Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  image: DecorationImage(
                    image: imageProvider,
                    fit: widget.fit,
                  ),
                ),
              )
            : null,
        placeholder: (context, url) => widget.placeholder ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        errorWidget: (context, url, error) {
          // Log network errors for debugging
          if (error is SocketException) {
            developer.log('Network image failed to load due to connectivity: ${error.message}', name: 'CachedBlobImage');
          } else {
            developer.log('Network image failed to load: $error', name: 'CachedBlobImage');
          }
          
          return widget.errorWidget ?? 
            GestureDetector(
              onTap: error is SocketException ? retryLoad : null,
              child: Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      error is SocketException ? Icons.wifi_off : Icons.error,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                    if (error is SocketException) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Offline',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Tap to retry',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
        },
      );
    }

    // If no image URL, show error widget
    return widget.errorWidget ?? 
      const Icon(Icons.image_not_supported);
  }
}