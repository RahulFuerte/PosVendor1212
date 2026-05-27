import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
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

  @override
  void didUpdateWidget(covariant CachedBlobImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.recordId != widget.recordId || oldWidget.imageUrl != widget.imageUrl) {
      _blobData = null;
      _isLoading = true;
      _hasError = false;
      _loadImage();
    }
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
      if (isOnline && widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A' && widget.imageUrl.startsWith('http')) {
        try {
          final downloadedData = await databaseService.downloadAndCacheImage(
            widget.imageUrl,
            tableName: widget.tableName,
            recordId: widget.recordId,
          );

          if (downloadedData != null && downloadedData.isNotEmpty) {
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
          } else {
            _hasError = true;
          }
        }
      } else {}

      // Continue to network image fallback or show appropriate state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
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
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: widget.borderRadius ?? BorderRadius.zero,
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
    if (widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A' && widget.imageUrl.startsWith('http')) {
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
        placeholder: (context, url) =>
            widget.placeholder ??
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: widget.borderRadius ?? BorderRadius.zero,
                ),
              ),
            ),
        errorWidget: (context, url, error) {
          // Log network errors for debugging
          if (error is SocketException) {
          } else {}

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
                          child: MyText(
                            text: 'Offline',
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: MyText(
                            text: 'Tap to retry',
                            color: Colors.grey[500],
                            fontSize: 8,
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
        const Icon(
          Icons.image_not_supported,
          size: 30,
        );
  }
}
