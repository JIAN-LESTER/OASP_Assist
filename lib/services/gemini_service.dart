// gemini_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:capstone_project/services/pinecone_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  final bool _isDesktop;

  // Desktop-only fields
  late final String _apiKey;
  late final String _embedUrl;

  GeminiService() : _isDesktop = _checkIfDesktop() {
    if (_isDesktop) {
      _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

      if (_apiKey.isEmpty) {
        throw Exception('Gemini API key not found in .env file');
      }

      _embedUrl =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=$_apiKey";

      if (kDebugMode) {
        print('🖥️ Using desktop Gemini implementation');
      }
    } else {
      if (kDebugMode) {
        print(' Using Cloud Functions Gemini implementation');
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

  // =========================================================================
  // Embed Text
  // =========================================================================

  Future<List<double>> embedText(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    if (_isDesktop) {
      return _embedTextDesktop(text, taskType: taskType);
    } else {
      return _embedTextCloudFunction(text, taskType: taskType);
    }
  }

  Future<List<double>> _embedTextDesktop(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_embedUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'models/gemini-embedding-001',
          'content': {
            'parts': [
              {'text': text},
            ],
          },
          'embedContentConfig': {
            'taskType': taskType,
            'outputDimensionality': 768,
            'autoTruncate': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        print(' Gemini Embed API error: ${response.body}');
        throw Exception('Failed to generate embedding: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final embedding = data['embedding']['values'] as List;
      final embeddingList =
          embedding.map((e) => (e as num).toDouble()).toList();

      print(' Generated ${embeddingList.length}-dimensional embedding');

      return embeddingList;
    } catch (e) {
      print(' Error generating Gemini embedding: $e');
      rethrow;
    }
  }

  Future<List<double>> _embedTextCloudFunction(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    try {
      final callable = functions.httpsCallable('generateGeminiEmbedding');
      final result = await callable.call({'text': text, 'taskType': taskType});

      final embedding = result.data['embedding'] as List;
      final embeddingList =
          embedding.map((e) => (e as num).toDouble()).toList();

      print(' Generated ${embeddingList.length}-dimensional embedding');
      return embeddingList;
    } catch (e) {
      print(' Error generating Gemini embedding: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Convenience Methods
  // =========================================================================

  Future<List<double>> embedQuery(String query) async {
    return embedText(query, taskType: 'RETRIEVAL_QUERY');
  }

  Future<List<double>> embedDocument(String document) async {
    return embedText(document, taskType: 'RETRIEVAL_DOCUMENT');
  }

  Future<String> generateResponse(String prompt) async {
    if (_isDesktop) {
      return _generateResponseDesktop(prompt);
    } else {
      return _generateResponseCloudFunction(prompt);
    }
  }

  Future<String> _generateResponseDesktop(String prompt) async {
    try {
      final chatUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey';

      final response = await http.post(
        Uri.parse(chatUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode != 200) {
        print(' Gemini Chat API error: ${response.body}');
        throw Exception('Failed to generate response: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } catch (e) {
      print(' Error generating Gemini response: $e');
      rethrow;
    }
  }

  Future<String> _generateResponseCloudFunction(String prompt) async {
    try {
      final callable = functions.httpsCallable('generateGeminiResponse');
      final result = await callable.call({'prompt': prompt});
      return result.data['text'] ?? '';
    } catch (e) {
      print(' Error generating Gemini response: $e');
      rethrow;
    }
  }
}
