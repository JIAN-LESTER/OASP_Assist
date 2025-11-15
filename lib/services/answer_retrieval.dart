import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_project/models/message.dart';

class AnswerRetrievalService {
  // 🔥 Replace with your actual Cloud Function URL
  final String cloudFunctionUrl = 
      'https://generateanswer-kt3rxdstza-uc.a.run.app';

  /// Generate an answer using streaming for real-time response
Stream<String> generateAnswerStream(
  String query, {
  List<Message>? conversationHistory,
  String? conversationId,
  int topK = 5,
  double minSimilarityScore = 0.3,
}) async* {
  try {
    print('🤖 Generating streaming answer for: "$query"');

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
      'stream': true,
    };

    print('📤 Sending streaming request to Cloud Function...');

    final request = http.Request('POST', Uri.parse(cloudFunctionUrl));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(requestBody);

    final response = await request.send().timeout(
      Duration(seconds: 60),
      onTimeout: () {
        throw Exception('Request timed out after 60 seconds');
      },
    );

    print('📥 Received streaming response: ${response.statusCode}');

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      print('❌ Cloud Function error: $errorBody');
      throw Exception('Cloud Function returned error: ${response.statusCode}');
    }

    String accumulatedText = '';
    String buffer = '';
    bool hasReceivedContent = false;
    bool streamEnded = false;
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      if (streamEnded) break;
      
      buffer += chunk;
      
      final lines = buffer.split('\n');
      buffer = lines.last;
      
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        
        if (line.isEmpty || line.startsWith(':')) continue;
        
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6).trim();
          
          if (jsonStr.isEmpty) continue;
          
          if (jsonStr == '[DONE]') {
            print('✅ Received [DONE] signal');
            streamEnded = true;
            break;
          }
          
          try {
            final data = jsonDecode(jsonStr);
            
            if (data['type'] == 'content-delta') {
              final text = data['delta']?['message']?['content']?['text'];
              if (text != null && text.isNotEmpty) {
                hasReceivedContent = true;
                accumulatedText += text;
                
                // ✅ Yield the full accumulated text
                yield accumulatedText;
                
                print('📝 Accumulated: ${accumulatedText.length} chars');
              }
            }
            else if (data['type'] == 'message-end') {
              print('✅ Stream ended successfully');
              final metadata = data['metadata'];
              if (metadata != null) {
                print('📊 Documents used: ${metadata['documentsUsed']}');
              }
              streamEnded = true;
              break;
            }
            else if (data['type'] == 'error' || data['error'] != null) {
              final errorMsg = data['error'] ?? 'Unknown error';
              print('❌ Server error: $errorMsg');
              throw Exception(errorMsg);
            }
          } catch (e) {
            print('⚠️ Error parsing chunk: $e');
            continue;
          }
        }
      }
    }

    // ✅ CRITICAL FIX: Don't yield again if we already received content
    if (!hasReceivedContent || accumulatedText.isEmpty) {
      print('⚠️ No content received from stream');
      yield "I'm having trouble processing your question right now. Please try again or contact OASP staff for assistance.";
    } else {
      print('✅ Streaming complete: ${accumulatedText.length} chars');
      // ❌ REMOVE THIS LINE - it causes duplication!
      // yield accumulatedText;  // DON'T yield again, we already yielded in the loop!
    }

  } catch (e, stackTrace) {
    print('❌ Error in generateAnswerStream: $e');
    print('Stack trace: $stackTrace');
    
    if (e.toString().contains('timeout')) {
      yield "The request is taking longer than expected. Please try again or contact OASP staff for assistance.";
    } else if (e.toString().contains('network') || e.toString().contains('SocketException')) {
      yield "Network error. Please check your internet connection and try again.";
    } else {
      yield "I encountered an error while processing your question. Please try again or contact OASP staff for assistance.";
    }
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