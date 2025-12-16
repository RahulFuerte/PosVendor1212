import 'package:flutter/material.dart';
import 'cached_blob_image.dart';

/// Example usage of CachedBlobImage widget
/// This demonstrates how to use the widget with proper error handling
class CachedBlobImageExample extends StatelessWidget {
  const CachedBlobImageExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cached Blob Image Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Food Item Image with Offline Support:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Example 1: Food item image with default error handling
            CachedBlobImage(
              imageUrl: 'https://media.istockphoto.com/photos/burger-picture-id1206323282',
              tableName: 'food_items',
              recordId: 'item_123',
              width: 200,
              height: 150,
              fit: BoxFit.cover,
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Department Image with Custom Placeholder:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Example 2: Department image with custom placeholder and error widget
            CachedBlobImage(
              imageUrl: 'https://media.istockphoto.com/photos/vegetables-picture-id1234567890',
              tableName: 'departments',
              recordId: 'dept_456',
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 8),
                    Text('Loading...', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
              errorWidget: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, color: Colors.red[400], size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'Image not available',
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Features:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Offline-first: Shows cached images when available'),
                Text('• Automatic caching: Downloads and stores images for offline use'),
                Text('• Network error handling: Graceful fallback for connectivity issues'),
                Text('• Tap to retry: Users can retry loading when connection is restored'),
                Text('• Custom widgets: Support for custom placeholder and error widgets'),
                Text('• Performance optimized: Uses BLOB cache for fast loading'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}