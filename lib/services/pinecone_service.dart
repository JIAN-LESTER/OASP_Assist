import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PineconeCloudService {
  final FirebaseFunctions functions;
  final bool _isDesktop;
  
  // Desktop-only fields
  late final String _baseUrl;
  late final String _apiKey;

  PineconeCloudService() 
    : functions = FirebaseFunctions.instance,
      _isDesktop = _checkIfDesktop() {
    if (_isDesktop) {
      // Load from environment variables for desktop
      _baseUrl = dotenv.env['PINECONE_HOST'] ?? '';
      _apiKey = dotenv.env['PINECONE_API_KEY'] ?? '';
      
      if (_baseUrl.isEmpty || _apiKey.isEmpty) {
        throw Exception('Pinecone credentials not found in .env file');
      }
      
      if (kDebugMode) {
        print('🖥️ Using desktop Pinecone implementation');
      }
    } else {
      if (kDebugMode) {
        print('📱 Using Cloud Functions Pinecone implementation');
      }
    }
  }

  static bool _checkIfDesktop() {
    if (kIsWeb) return false;
    
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Api-Key': _apiKey,
  };

  http.Client get _client => http.Client();

  // =========================================================================
  // Health Check
  // =========================================================================
  
  Future<bool> isHealthy() async {
    if (_isDesktop) {
      return _isHealthyDesktop();
    } else {
      return _isHealthyCloudFunction();
    }
  }

  Future<bool> _isHealthyDesktop() async {
    try {
      print('🏥 Checking Pinecone health (Desktop)...');

      final url = Uri.parse('$_baseUrl/describe_index_stats');
      final response = await _client
          .post(url, headers: _headers, body: jsonEncode({}))
          .timeout(const Duration(seconds: 10));

      final isHealthy = response.statusCode == 200;
      print(isHealthy ? '✅ Pinecone is healthy' : '❌ Pinecone is not healthy');

      if (isHealthy) {
        final data = jsonDecode(response.body);
        print('📊 Index stats: ${data['totalVectorCount']} vectors');
      }

      return isHealthy;
    } catch (e) {
      print('❌ Pinecone health check failed: $e');
      return false;
    }
  }

  Future<bool> _isHealthyCloudFunction() async {
    try {
      print('🏥 Checking Pinecone health (Cloud Function)...');

      final callable = functions.httpsCallable('checkPineconeHealth');
      
      final result = await callable.call().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Health check timed out after 15 seconds');
          throw TimeoutException('Health check timed out');
        },
      );

      final isHealthy = result.data['healthy'] == true;
      
      if (isHealthy) {
        print('✅ Pinecone is healthy');
      } else {
        print('❌ Pinecone is not healthy');
        if (result.data['error'] != null) {
          print('   Error: ${result.data['error']}');
        }
      }

      return isHealthy;
    } catch (e) {
      print('❌ Pinecone health check failed: $e');
      return false;
    }
  }

  // =========================================================================
  // Query Similar Documents
  // =========================================================================

  Future<List<Map<String, dynamic>>> querySimilarDocuments(
    List<double> embedding, {
    int topK = 5,
    String? namespace,
    Map<String, dynamic>? filter,
  }) async {
    if (_isDesktop) {
      return _querySimilarDocumentsDesktop(
        embedding,
        topK: topK,
        namespace: namespace,
        filter: filter,
      );
    } else {
      return _querySimilarDocumentsCloudFunction(
        embedding,
        topK: topK,
        namespace: namespace,
        filter: filter,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _querySimilarDocumentsDesktop(
    List<double> embedding, {
    int topK = 5,
    String? namespace,
    Map<String, dynamic>? filter,
  }) async {
    final url = Uri.parse('$_baseUrl/query');

    final payload = {
      'vector': embedding,
      'topK': topK,
      'includeMetadata': true,
      'includeValues': false,
      if (namespace != null) 'namespace': namespace,
      if (filter != null) 'filter': filter,
    };

    try {
      print('🔍 Querying Pinecone with ${embedding.length} dimensions...');

      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(payload))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timed out after 30 seconds');
            },
          );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['matches'] == null) {
          print('⚠️ No results found in response');
          return [];
        }

        final matches = data['matches'] as List;
        print('✅ Found ${matches.length} similar documents');

        return matches.map<Map<String, dynamic>>((match) {
          final result = Map<String, dynamic>.from(match);
          
          if (result['metadata'] != null) {
            final metadata = result['metadata'] as Map<String, dynamic>;
            result.addAll(metadata);
          }

          result['similarity_score'] = result['score'] ?? 0.0;
          result['id'] = result['id'];

          return result;
        }).toList();
      } else {
        print('❌ Pinecone query error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error querying Pinecone: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _querySimilarDocumentsCloudFunction(
    List<double> embedding, {
    int topK = 5,
    String? namespace,
    Map<String, dynamic>? filter,
  }) async {
    try {
      print('🔍 Querying Pinecone with ${embedding.length} dimensions...');

      final callable = functions.httpsCallable('queryPinecone');
      final result = await callable.call({
        'embedding': embedding,
        'topK': topK,
        if (namespace != null) 'namespace': namespace,
        if (filter != null) 'filter': filter,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Query timed out');
        },
      );

      if (result.data['success'] == false) {
        print('⚠️ No results found');
        return [];
      }

      final matches = result.data['matches'] as List;
      print('✅ Found ${matches.length} similar documents');

      return matches.map<Map<String, dynamic>>((match) {
        return Map<String, dynamic>.from(match);
      }).toList();
    } catch (e) {
      print('❌ Error querying Pinecone: $e');
      return [];
    }
  }

  // =========================================================================
  // Insert Document
  // =========================================================================

  Future<void> insertDocument({
    required String id,
    required List<double> embedding,
    required String title,
    required String content,
    required String source,
    String? category,
    String? namespace,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isDesktop) {
      return _insertDocumentDesktop(
        id: id,
        embedding: embedding,
        title: title,
        content: content,
        source: source,
        category: category,
        namespace: namespace,
        metadata: metadata,
      );
    } else {
      return _insertDocumentCloudFunction(
        id: id,
        embedding: embedding,
        title: title,
        content: content,
        source: source,
        category: category,
        namespace: namespace,
        metadata: metadata,
      );
    }
  }

  Future<void> _insertDocumentDesktop({
    required String id,
    required List<double> embedding,
    required String title,
    required String content,
    required String source,
    String? category,
    String? namespace,
    Map<String, dynamic>? metadata,
  }) async {
    final url = Uri.parse('$_baseUrl/vectors/upsert');

    final vectorMetadata = _sanitizeMetadata({
      'title': title,
      'content': content,
      'source': source,
      if (category != null) 'category': category,
      if (metadata != null) ...metadata,
    });

    final payload = {
      'vectors': [
        {
          'id': id,
          'values': embedding,
          'metadata': vectorMetadata,
        }
      ],
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('📤 Inserting document: $title (ID: $id)');

      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final upsertedCount = responseData['upsertedCount'] ?? 0;
        print("✅ Document inserted into Pinecone with ID: $id (upserted: $upsertedCount)");
      } else {
        print("❌ Pinecone insert failed: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to insert document into Pinecone: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error inserting document into Pinecone: $e');
      rethrow;
    }
  }

  Future<void> _insertDocumentCloudFunction({
    required String id,
    required List<double> embedding,
    required String title,
    required String content,
    required String source,
    String? category,
    String? namespace,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('📤 Inserting document: $title (ID: $id)');

      final callable = functions.httpsCallable('insertPineconeDocument');
      await callable.call({
        'id': id,
        'embedding': embedding,
        'metadata': {
          'title': title,
          'content': content,
          'source': source,
          if (category != null) 'category': category,
          if (metadata != null) ...metadata,
        },
        if (namespace != null) 'namespace': namespace,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Insert timed out');
        },
      );

      print("✅ Document inserted into Pinecone with ID: $id");
    } catch (e) {
      print('❌ Error inserting document: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Batch Insert Documents
  // =========================================================================

  Future<void> insertDocumentsBatch({
    required List<Map<String, dynamic>> documents,
    String? namespace,
  }) async {
    if (_isDesktop) {
      return _insertDocumentsBatchDesktop(
        documents: documents,
        namespace: namespace,
      );
    } else {
      return _insertDocumentsBatchCloudFunction(
        documents: documents,
        namespace: namespace,
      );
    }
  }

  Future<void> _insertDocumentsBatchDesktop({
    required List<Map<String, dynamic>> documents,
    String? namespace,
  }) async {
    const int batchSize = 100;
    
    for (int i = 0; i < documents.length; i += batchSize) {
      final batch = documents.skip(i).take(batchSize).toList();
      await _insertBatchDesktop(batch, namespace);
    }
  }

  Future<void> _insertBatchDesktop(
    List<Map<String, dynamic>> batch,
    String? namespace,
  ) async {
    final url = Uri.parse('$_baseUrl/vectors/upsert');

    final vectors = batch.map((doc) => {
      'id': doc['id'],
      'values': doc['embedding'],
      'metadata': doc['metadata'],
    }).toList();

    final payload = {
      'vectors': vectors,
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('📤 Inserting batch of ${batch.length} documents');

      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final upsertedCount = responseData['upsertedCount'] ?? 0;
        print("✅ Batch inserted into Pinecone: $upsertedCount documents");
      } else {
        print("❌ Pinecone batch insert failed: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception('Failed to insert batch into Pinecone: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error inserting batch into Pinecone: $e');
      rethrow;
    }
  }

  Future<void> _insertDocumentsBatchCloudFunction({
    required List<Map<String, dynamic>> documents,
    String? namespace,
  }) async {
    try {
      print('📤 Batch inserting ${documents.length} documents...');

      const batchSize = 100;
      for (int i = 0; i < documents.length; i += batchSize) {
        final batch = documents.skip(i).take(batchSize).toList();
        
        final callable = functions.httpsCallable('insertPineconeDocumentBatch');
        await callable.call({
          'documents': batch,
          if (namespace != null) 'namespace': namespace,
        }).timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            throw TimeoutException('Batch insert timed out');
          },
        );

        print('✅ Inserted batch ${(i / batchSize).floor() + 1}/${(documents.length / batchSize).ceil()}');
      }

      print("✅ All documents inserted into Pinecone");
    } catch (e) {
      print('❌ Error batch inserting documents: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Delete Documents
  // =========================================================================

  Future<void> deleteDocuments(List<String> ids, {String? namespace}) async {
    if (_isDesktop) {
      return _deleteDocumentsDesktop(ids, namespace: namespace);
    } else {
      return _deleteDocumentsCloudFunction(ids, namespace: namespace);
    }
  }

  Future<void> _deleteDocumentsDesktop(
    List<String> ids, {
    String? namespace,
  }) async {
    final url = Uri.parse('$_baseUrl/vectors/delete');

    final payload = {
      'ids': ids,
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('🗑️ Deleting ${ids.length} documents from Pinecone');

      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print("✅ ${ids.length} documents deleted from Pinecone");
      } else {
        print("❌ Pinecone batch delete failed: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print('❌ Error deleting documents from Pinecone: $e');
      rethrow;
    }
  }

  Future<void> _deleteDocumentsCloudFunction(
    List<String> ids, {
    String? namespace,
  }) async {
    try {
      if (ids.isEmpty) {
        print('⚠️ No documents to delete');
        return;
      }

      print('🗑️ Deleting ${ids.length} documents from Pinecone...');

      final callable = functions.httpsCallable('deletePineconeDocuments');
      final result = await callable.call({
        'ids': ids,
        if (namespace != null) 'namespace': namespace,
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Delete timed out');
        },
      );

      if (result.data['success'] == true) {
        print("✅ ${result.data['deleted']} documents deleted from Pinecone");
      } else {
        print("⚠️ Delete operation completed but status unknown");
      }
    } catch (e) {
      print('❌ Error deleting documents: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Get Index Stats
  // =========================================================================

  Future<Map<String, dynamic>?> getIndexStats({String? namespace}) async {
    if (_isDesktop) {
      return _getIndexStatsDesktop(namespace: namespace);
    } else {
      return _getIndexStatsCloudFunction(namespace: namespace);
    }
  }

  Future<Map<String, dynamic>?> _getIndexStatsDesktop({String? namespace}) async {
    try {
      print('📊 Getting Pinecone index statistics...');

      final url = Uri.parse('$_baseUrl/describe_index_stats');
      final payload = <String, dynamic>{};
      if (namespace != null) {
        payload['filter'] = {'namespace': namespace};
      }

      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved index statistics');
        return data;
      } else {
        print("❌ Failed to get index stats: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print('❌ Error getting index stats: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getIndexStatsCloudFunction({String? namespace}) async {
    try {
      print('📊 Getting Pinecone index statistics...');

      final callable = functions.httpsCallable('getPineconeStats');
      final result = await callable.call({
        if (namespace != null) 'namespace': namespace,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Stats query timed out');
        },
      );

      if (result.data['success'] == true) {
        print('✅ Retrieved index statistics');
        return Map<String, dynamic>.from(result.data['stats']);
      }

      return null;
    } catch (e) {
      print('❌ Error getting index stats: $e');
      return null;
    }
  }

  // =========================================================================
  // Fetch Vectors
  // =========================================================================

  Future<Map<String, dynamic>?> fetchVectors(
    List<String> ids, {
    String? namespace,
  }) async {
    if (_isDesktop) {
      return _fetchVectorsDesktop(ids, namespace: namespace);
    } else {
      return _fetchVectorsCloudFunction(ids, namespace: namespace);
    }
  }

  Future<Map<String, dynamic>?> _fetchVectorsDesktop(
    List<String> ids, {
    String? namespace,
  }) async {
    final url = Uri.parse('$_baseUrl/vectors/fetch');

    final payload = {
      'ids': ids,
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('📋 Fetching ${ids.length} vectors from Pinecone...');

      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved ${ids.length} vectors');
        return data;
      } else {
        print("❌ Fetch vectors failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print('❌ Error fetching vectors: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchVectorsCloudFunction(
    List<String> ids, {
    String? namespace,
  }) async {
    try {
      print('📋 Fetching ${ids.length} vectors from Pinecone...');

      final callable = functions.httpsCallable('fetchPineconeVectors');
      final result = await callable.call({
        'ids': ids,
        if (namespace != null) 'namespace': namespace,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Fetch timed out');
        },
      );

      if (result.data['success'] == true) {
        print('✅ Retrieved ${ids.length} vectors');
        return Map<String, dynamic>.from(result.data['vectors']);
      }

      return null;
    } catch (e) {
      print('❌ Error fetching vectors: $e');
      return null;
    }
  }

  // =========================================================================
  // Helper Methods
  // =========================================================================

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
    final clean = <String, dynamic>{};
    metadata.forEach((key, value) {
      if (value != null &&
          (value is String || 
           value is num || 
           value is bool || 
           (value is List && value.every((e) => e is String)))) {
        clean[key] = value;
      }
    });
    return clean;
  }

  bool get isSupported => true; // Both platforms are now supported
  
  String get unsupportedPlatformMessage => ''; // No longer needed
}
