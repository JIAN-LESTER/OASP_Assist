import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';

class FacebookImageStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Downloads an image from Facebook and uploads it to Firebase Storage
  /// Returns the Firebase Storage download URL
  static Future<String?> uploadFacebookImageToStorage({
    required String facebookImageUrl,
    required String postId,
    required int imageIndex,
  }) async {
    try {
      print('📥 Downloading image from Facebook...');
      
      // Download the image from Facebook
      final response = await http.get(Uri.parse(facebookImageUrl));
      
      if (response.statusCode != 200) {
        print('❌ Failed to download image: ${response.statusCode}');
        return null;
      }

      final imageBytes = response.bodyBytes;
      print('✅ Downloaded ${imageBytes.length} bytes');

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'announcement_${postId}_${imageIndex}_$timestamp.jpg';
      final storagePath = 'announcements/$postId/$fileName';

      print('📤 Uploading to Firebase Storage: $storagePath');

      // Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'source': 'facebook',
            'postId': postId,
            'imageIndex': imageIndex.toString(),
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('✅ Uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image to storage: $e');
      return null;
    }
  }

  /// Process all images in a Facebook post and upload them to Firebase Storage
  /// Updates the Firestore document with new image URLs
  static Future<Map<String, dynamic>> processPostImages({
    required String postId,
    required List<String> facebookImageUrls,
  }) async {
    try {
      print('🔄 Processing ${facebookImageUrls.length} images for post $postId');

      List<String> firebaseUrls = [];
      List<String> failedUrls = [];

      for (int i = 0; i < facebookImageUrls.length; i++) {
        final fbUrl = facebookImageUrls[i];
        print('Processing image ${i + 1}/${facebookImageUrls.length}');

        final firebaseUrl = await uploadFacebookImageToStorage(
          facebookImageUrl: fbUrl,
          postId: postId,
          imageIndex: i,
        );

        if (firebaseUrl != null) {
          firebaseUrls.add(firebaseUrl);
        } else {
          failedUrls.add(fbUrl);
        }

        // Small delay to avoid rate limiting
        if (i < facebookImageUrls.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      print('✅ Successfully uploaded ${firebaseUrls.length} images');
      if (failedUrls.isNotEmpty) {
        print('⚠️ Failed to upload ${failedUrls.length} images');
      }

      return {
        'success': firebaseUrls.isNotEmpty,
        'firebaseUrls': firebaseUrls,
        'failedUrls': failedUrls,
        'totalProcessed': facebookImageUrls.length,
        'successCount': firebaseUrls.length,
        'failedCount': failedUrls.length,
      };
    } catch (e) {
      print('❌ Error processing post images: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Migrate existing announcement images from Facebook URLs to Firebase Storage
  static Future<Map<String, dynamic>> migrateAnnouncementImages(
    String announcementId,
  ) async {
    try {
      print('🔄 Migrating images for announcement: $announcementId');

      // Get the announcement document
      final doc = await _firestore
          .collection('announcements')
          .doc(announcementId)
          .get();

      if (!doc.exists) {
        return {'success': false, 'error': 'Announcement not found'};
      }

      final data = doc.data() as Map<String, dynamic>;
      List<String> facebookUrls = [];

      // Extract Facebook image URLs
      if (data['images'] != null && data['images'] is List) {
        facebookUrls = (data['images'] as List)
            .map((item) {
              if (item is String) return item;
              if (item is Map && item.containsKey('url')) {
                return item['url'].toString();
              }
              return '';
            })
            .where((url) => url.isNotEmpty && url.contains('fbcdn.net'))
            .toList();
      }

      if (data['full_picture'] != null &&
          (data['full_picture'] as String).contains('fbcdn.net')) {
        if (!facebookUrls.contains(data['full_picture'])) {
          facebookUrls.add(data['full_picture'] as String);
        }
      }

      if (facebookUrls.isEmpty) {
        print('ℹ️ No Facebook images to migrate');
        return {'success': true, 'message': 'No images to migrate'};
      }

      // Process and upload images
      final result = await processPostImages(
        postId: announcementId,
        facebookImageUrls: facebookUrls,
      );

      if (result['success'] == true && result['firebaseUrls'].isNotEmpty) {
        // Update Firestore with new URLs
        await _firestore.collection('announcements').doc(announcementId).update({
          'images': result['firebaseUrls'],
          'original_fb_urls': facebookUrls, // Keep original URLs for reference
          'images_migrated': true,
          'migration_date': FieldValue.serverTimestamp(),
          'image_count': result['firebaseUrls'].length,
        });

        print('✅ Migration completed successfully');
      }

      return result;
    } catch (e) {
      print('❌ Error migrating announcement images: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Migrate all announcements with Facebook images
  static Future<Map<String, dynamic>> migrateAllAnnouncements() async {
    try {
      print('🔄 Starting bulk migration of all announcements...');

      final querySnapshot = await _firestore
          .collection('announcements')
          .where('deleted', isEqualTo: false)
          .get();

      int total = querySnapshot.docs.length;
      int migrated = 0;
      int failed = 0;
      int skipped = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Skip if already migrated
        if (data['images_migrated'] == true) {
          print('⏭️ Skipping ${doc.id} - already migrated');
          skipped++;
          continue;
        }

        print('\n📦 Processing ${doc.id} (${migrated + failed + skipped + 1}/$total)');

        final result = await migrateAnnouncementImages(doc.id);

        if (result['success'] == true) {
          migrated++;
          print('✅ Successfully migrated ${doc.id}');
        } else {
          failed++;
          print('❌ Failed to migrate ${doc.id}: ${result['error']}');
        }

        // Delay between migrations to avoid rate limiting
        await Future.delayed(Duration(seconds: 2));
      }

      print('\n📊 Migration Summary:');
      print('Total: $total');
      print('Migrated: $migrated');
      print('Failed: $failed');
      print('Skipped: $skipped');

      return {
        'success': true,
        'total': total,
        'migrated': migrated,
        'failed': failed,
        'skipped': skipped,
      };
    } catch (e) {
      print('❌ Error in bulk migration: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete images from Firebase Storage when announcement is deleted
  static Future<void> deleteAnnouncementImages(String announcementId) async {
    try {
      print('🗑️ Deleting images for announcement: $announcementId');

      final folderRef = _storage.ref().child('announcements/$announcementId');
      final listResult = await folderRef.listAll();

      for (var item in listResult.items) {
        await item.delete();
        print('✅ Deleted: ${item.name}');
      }

      print('✅ All images deleted for $announcementId');
    } catch (e) {
      print('❌ Error deleting images: $e');
    }
  }
}