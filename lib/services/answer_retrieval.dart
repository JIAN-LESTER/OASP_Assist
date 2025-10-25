import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_project/models/message.dart';

class AnswerRetrievalService {
  // 🔥 Replace with your actual Cloud Function URL
  final String cloudFunctionUrl = 
      'https://generateanswer-kt3rxdstza-uc.a.run.app';

  /// Generate an answer using the Cloud Function
  Future<String> generateAnswer(
    String query, {
    List<Message>? conversationHistory,
    String? conversationId,
    int topK = 5,
    double minSimilarityScore = 0.3,
  }) async {
    try {
      print('🤖 Generating answer for: "$query"');

      // Convert conversation history to the format expected by Cloud Function
      final historyData = conversationHistory?.map((msg) => {
        'sender': msg.sender,
        'content': msg.content,
      }).toList() ?? [];

      // Prepare request body
      final requestBody = {
        'query': query,
        'conversationHistory': historyData,
        'conversationId': conversationId,
        'topK': topK,
        'minSimilarityScore': minSimilarityScore,
      };

      print('📤 Sending request to Cloud Function...');

      // Make HTTP request to Cloud Function
      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out after 60 seconds');
        },
      );

      print('📥 Received response: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ Cloud Function error: ${response.body}');
        throw Exception('Cloud Function returned error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      
      if (data['answer'] == null || data['answer'].toString().trim().isEmpty) {
        print('❌ Empty answer received from Cloud Function');
        return "I'm having trouble processing your question right now. Please try again or contact OASP staff for assistance.";
      }

      final answer = data['answer'] as String;
      final source = data['source'] as String?;
      
      print('✅ Generated answer from source: $source');
      
      return answer.trim();

    } catch (e, stackTrace) {
      print('❌ Error in generateAnswer: $e');
      print('Stack trace: $stackTrace');
      
      // Return user-friendly error messages based on error type
      if (e.toString().contains('timeout')) {
        return "The request is taking longer than expected. Please try again or contact OASP staff for assistance.";
      } else if (e.toString().contains('network') || e.toString().contains('SocketException')) {
        return "Network error. Please check your internet connection and try again.";
      } else {
        return "I encountered an error while processing your question. Please try again or contact OASP staff for assistance.";
      }
    }
  }

  /// Optional: Test the Cloud Function connection
  Future<bool> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': 'test',
          'conversationHistory': [],
        }),
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 400;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}