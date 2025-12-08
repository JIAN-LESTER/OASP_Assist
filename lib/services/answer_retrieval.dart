import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:capstone_project/models/message.dart';

class AnswerRetrievalService {
  // 🔥 Replace with your actual Cloud Function URL
  final String cloudFunctionUrl = 
      'https://generateanswer-kt3rxdstza-uc.a.run.app';

  /// Generate an answer using streaming for real-time response
Stream<String> generateAnswerStream(
  String question, {
  List<Message>? conversationHistory,
  String? conversationId,
}) async* {
  try {
    print('🚀 Starting streaming for: "${question.substring(0, min(50, question.length))}..."');

    final requestBody = {
      'query': question,
      'stream': true,
      'topK': 8,
      'minSimilarityScore': 0.30,
      'conversationHistory': conversationHistory
          ?.map((m) => {'sender': m.sender, 'content': m.content})
          .toList() ?? [],
    };

    final request = http.Request(
      'POST',
      Uri.parse('$cloudFunctionUrl/generateAnswer'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode(requestBody);

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      print('❌ HTTP Error ${streamedResponse.statusCode}: $errorBody');
      yield 'I apologize, but I encountered an error processing your request. Please try again.';
      return;
    }

    String fullAnswer = '';
    String buffer = '';
    int chunkCount = 0;
    final startTime = DateTime.now();

    await for (final chunk in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(LineSplitter())) {
      
      if (chunk.trim().isEmpty || 
          chunk.startsWith('event:') || 
          chunk == 'data: [DONE]') {
        continue;
      }

      String jsonStr = chunk.trim();
      if (jsonStr.startsWith('data: ')) {
        jsonStr = jsonStr.substring(6);
      }

      if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

      try {
        final data = json.decode(jsonStr);

        if (data['type'] == 'content-delta') {
          final text = data['delta']?['message']?['content']?['text'] as String?;
          
          if (text != null && text.isNotEmpty) {
            chunkCount++;
            fullAnswer += text;
            
            // ✅ OPTIMIZED: Yield more frequently for faster visual updates
            // Every 1-2 chunks instead of accumulating buffer
            yield fullAnswer;
          }
        } else if (data['type'] == 'message-end') {
          final totalTime = DateTime.now().difference(startTime).inMilliseconds;
          print('✅ Streaming complete: $chunkCount chunks in ${totalTime}ms');
          
          if (fullAnswer.isNotEmpty) {
            yield fullAnswer; // Final yield
          }
          break;
        } else if (data['type'] == 'error') {
          print('❌ Streaming error: ${data['error']}');
          if (fullAnswer.isEmpty) {
            yield 'I encountered an error processing your request. Please try again.';
          }
          break;
        }
      } catch (e) {
        print('⚠️ Failed to parse chunk: ${jsonStr.substring(0, min(100, jsonStr.length))}');
        continue;
      }
    }

    if (fullAnswer.isEmpty) {
      print('⚠️ No content received from stream');
      yield 'I apologize, but I was unable to generate a response. Please try again.';
    }

  } catch (e) {
    print('❌ Streaming error: $e');
    yield 'I apologize, but I encountered an error. Please try again or contact OASP staff.';
  }
}

  /// Non-streaming fallback method (keep for compatibility)
  Future<String> generateAnswer(
    String query, {
    List<Message>? conversationHistory,
    String? conversationId,
    int topK = 5,
    double minSimilarityScore = 0.3,
  }) async {
    try {
      print('🤖 Generating answer for: "$query"');

      final historyData = conversationHistory?.map((msg) => {
        'sender': msg.sender,
        'content': msg.content,
      }).toList() ?? [];

      final requestBody = {
        'query': query,
        'conversationHistory': historyData,
        'conversationId': conversationId,
        'topK': topK,
        'minSimilarityScore': minSimilarityScore,
      };

      print('📤 Sending request to Cloud Function...');

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