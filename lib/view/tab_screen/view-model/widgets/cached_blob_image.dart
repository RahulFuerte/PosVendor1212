import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../backend/database_service.dart';

/// A widget that displays images from BLOB cache when available, 
/// falling back to network images when offline or BLOB not available
class CachedBlobImage extends StatefulWidget {
  final String imageUrl;
  final String tableName;
  final String recordId;
  final double? width;
  final double? height;
  final BoxFit fit;
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

  Future<void> _loadImage() async {
    try {
      final DatabaseService databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // First try to get image from BLOB cache
      final blobData = await databaseService.getImageBlob(widget.tableName, widget.recordId);
      
      if (blobData != null && blobData.isNotEmpty) {
        setState(() {
          _blobData = blobData;
          _isLoading = false;
        });
        return;
      }
      
      // If BLOB not available and online, try to download and cache
      final isOnline = await databaseService.isOnline();
      if (isOnline && widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A') {
        try {
          final downloadedData = await databaseService.downloadAndCacheImage(
            widget.imageUrl,
            tableName: widget.tableName,
            recordId: widget.recordId,
          );
          
          if (downloadedData != null && downloadedData.isNotEmpty) {
            setState(() {
              _blobData = downloadedData;
              _isLoading = false;
            });
            return;
          }
        } catch (e) {
          print('Failed to download and cache image: $e');
        }
      }
      
      // If all else fails, show network image or error
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading image: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
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
            child: CircularProgressIndicator(),
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
      return Image.memory(
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
    }

    // Fallback to network image if BLOB not available
    if (widget.imageUrl.isNotEmpty && widget.imageUrl != 'N/A') {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => widget.placeholder ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        errorWidget: (context, url, error) => widget.errorWidget ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Icon(Icons.error),
          ),
      );
    }

    // If no image URL, show error widget
    return widget.errorWidget ?? 
      Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported),
      );
  }
}