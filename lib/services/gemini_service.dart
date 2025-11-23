import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // 🔐 Replace with your Gemini API key
  final String apiKey = "AIzaSyBEsKofC_0dTYRNwFhjnnY8jzuhmQqbHQI";
  final String embedUrl = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent";

  /// Generate 768-dimensional embedding using Gemini
  Future<List<double>> embedText(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$embedUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'models/text-embedding-004',
          'content': {
            'parts': [
              {'text': text}
            ]
          },
          'taskType': taskType, // RETRIEVAL_DOCUMENT, RETRIEVAL_QUERY, etc.
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Gemini Embed API error: ${response.body}');
        throw Exception('Failed to generate embedding: ${response.body}');
      }

      final data = jsonDecode(response.body);
      
      // Extract embedding from response
      final embedding = data['embedding']['values'] as List;
      final embeddingList = embedding.map((e) => (e as num).toDouble()).toList();
      
      print('✅ Generated ${embeddingList.length}-dimensional embedding');
      
      return embeddingList;
    } catch (e) {
      print('❌ Error generating Gemini embedding: $e');
      rethrow;
    }
  }

  /// Generate embedding for search queries
  Future<List<double>> embedQuery(String query) async {
    return embedText(query, taskType: 'RETRIEVAL_QUERY');
  }

  /// Generate embedding for documents
  Future<List<double>> embedDocument(String document) async {
    return embedText(document, taskType: 'RETRIEVAL_DOCUMENT');
  }

  /// Generate response using Gemini (optional - for chat functionality)
  Future<String> generateResponse(String prompt) async {
    try {
      final chatUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';
      
      final response = await http.post(
        Uri.parse(chatUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Gemini Chat API error: ${response.body}');
        throw Exception('Failed to generate response: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } catch (e) {
      print('❌ Error generating Gemini response: $e');
      rethrow;
    }
  }
}