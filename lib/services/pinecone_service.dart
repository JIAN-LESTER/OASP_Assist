import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class PineconeCloudService {
  // final String baseUrl = "https://oasp-assist-tpewr0x.svc.aped-4627-b74a.pinecone.io";
  // final String apiKey = "pcsk_41xXt3_J3U7iPvCEojTLLfUwFhKuQXkFFnuYJu9qcio175Ne2dLNS8t3TTzRie2QmTNdLa";
  final String baseUrl = "https://oasp-assist-gemini-tpewr0x.svc.aped-4627-b74a.pinecone.io";
  final String apiKey = "pcsk_41xXt3_J3U7iPvCEojTLLfUwFhKuQXkFFnuYJu9qcio175Ne2dLNS8t3TTzRie2QmTNdLa";

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Api-Key': apiKey,
  };

  http.Client get _client => http.Client();

  /// Query similar documents using Pinecone vector search
  Future<List<Map<String, dynamic>>> querySimilarDocuments(
    List<double> embedding, {
    int topK = 5,
    String? namespace,
    Map<String, dynamic>? filter,
  }) async {
    final url = Uri.parse('$baseUrl/query');

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

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(
            Duration(seconds: 30),
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
          
          // Extract metadata
          if (result['metadata'] != null) {
            final metadata = result['metadata'] as Map<String, dynamic>;
            result.addAll(metadata);
          }

          // Add similarity information
          result['similarity_score'] = result['score'] ?? 0.0;
          result['id'] = result['id'];

          return result;
        }).toList();
      } else {
        print('❌ Pinecone query error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } on SocketException catch (e) {
      print('❌ Network error: $e');
      print('💡 Check your internet connection and Pinecone URL');
      return [];
    } on TimeoutException catch (e) {
      print('❌ Timeout error: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ JSON parsing error: $e');
      return [];
    } catch (e) {
      print('❌ Unexpected error querying Pinecone: $e');
      return [];
    }
  }

  /// Insert/Upsert a document vector into Pinecone
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
    final url = Uri.parse('$baseUrl/vectors/upsert');

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

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final upsertedCount = responseData['upsertedCount'] ?? 0;
        print("✅ Document inserted into Pinecone with ID: $id (upserted: $upsertedCount)");
      } else {
        print("❌ Pinecone insert failed: ${response.statusCode}");
        print("Response body: ${response.body}");
        throw Exception(
          'Failed to insert document into Pinecone: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      print('❌ Network error during insert: $e');
      rethrow;
    } on TimeoutException catch (e) {
      print('❌ Timeout during insert: $e');
      rethrow;
    } catch (e) {
      print('❌ Error inserting document into Pinecone: $e');
      rethrow;
    }
  }

  /// Insert multiple documents in batch
  Future<void> insertDocumentsBatch({
    required List<Map<String, dynamic>> documents,
    String? namespace,
  }) async {
    const int batchSize = 100; // Pinecone batch size limit
    
    for (int i = 0; i < documents.length; i += batchSize) {
      final batch = documents.skip(i).take(batchSize).toList();
      await _insertBatch(batch, namespace);
    }
  }

  Future<void> _insertBatch(List<Map<String, dynamic>> batch, String? namespace) async {
    final url = Uri.parse('$baseUrl/vectors/upsert');

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

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: 60));

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

  /// Check if Pinecone index is healthy
  Future<bool> isHealthy() async {
    try {
      print('🏥 Checking Pinecone health...');

      final url = Uri.parse('$baseUrl/describe_index_stats');
      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode({}))
          .timeout(Duration(seconds: 10));

      final isHealthy = response.statusCode == 200;
      print(
        isHealthy
            ? '✅ Pinecone is healthy'
            : '❌ Pinecone is not healthy',
      );

      if (isHealthy) {
        final data = jsonDecode(response.body);
        print('📊 Index stats: ${data['totalVectorCount']} vectors');
      } else {
        print('Response: ${response.statusCode} - ${response.body}');
      }

      return isHealthy;
    } on SocketException catch (e) {
      print('❌ Network error during health check: $e');
      return false;
    } on TimeoutException catch (e) {
      print('❌ Timeout during health check: $e');
      return false;
    } catch (e) {
      print('❌ Pinecone health check failed: $e');
      return false;
    }
  }

  /// Delete a document from Pinecone
  Future<void> deleteDocument(String id, {String? namespace}) async {
    final url = Uri.parse('$baseUrl/vectors/delete');

    final payload = {
      'ids': [id],
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('🗑️ Deleting document from Pinecone: $id');

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        print("✅ Document deleted from Pinecone: $id");
      } else {
        print("❌ Pinecone delete failed: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } on SocketException catch (e) {
      print('❌ Network error during delete: $e');
    } on TimeoutException catch (e) {
      print('❌ Timeout during delete: $e');
    } catch (e) {
      print('❌ Error deleting document from Pinecone: $e');
    }
  }

  /// Delete multiple documents by IDs
  Future<void> deleteDocuments(List<String> ids, {String? namespace}) async {
    final url = Uri.parse('$baseUrl/vectors/delete');

    final payload = {
      'ids': ids,
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('🗑️ Deleting ${ids.length} documents from Pinecone');

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        print("✅ ${ids.length} documents deleted from Pinecone");
      } else {
        print("❌ Pinecone batch delete failed: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print('❌ Error deleting documents from Pinecone: $e');
    }
  }

  /// Get index statistics
  Future<Map<String, dynamic>?> getIndexStats({String? namespace}) async {
    try {
      print('📊 Getting Pinecone index statistics...');

      final url = Uri.parse('$baseUrl/describe_index_stats');
      final payload = <String, dynamic>{};
      if (namespace != null) {
        payload['filter'] = {'namespace': namespace};
      }

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved index statistics');
        return data;
      } else {
        print("❌ Failed to get index stats: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('❌ Error getting index stats: $e');
      return null;
    }
  }

  /// Fetch vectors by IDs (for debugging)
  Future<Map<String, dynamic>?> fetchVectors(
    List<String> ids, {
    String? namespace,
    bool includeValues = false,
    bool includeMetadata = true,
  }) async {
    final url = Uri.parse('$baseUrl/vectors/fetch');

    final payload = {
      'ids': ids,
      if (namespace != null) 'namespace': namespace,
    };

    try {
      print('📋 Fetching ${ids.length} vectors from Pinecone...');

      final client = _client;
      final response = await client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Retrieved ${ids.length} vectors');
        return data;
      } else {
        print("❌ Fetch vectors failed: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('❌ Error fetching vectors: $e');
      return null;
    }
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
  final clean = <String, dynamic>{};
  metadata.forEach((key, value) {
    if (value != null &&
        (value is String || value is num || value is bool || (value is List && value.every((e) => e is String)))) {
      clean[key] = value;
    }
  });
  return clean;
}

}
