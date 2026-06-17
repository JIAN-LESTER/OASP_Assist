import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:capstone_project/models/message.dart';

class AnswerRetrievalService {
  //  The Cloud Run URL for an onRequest function already IS the endpoint.
  // Do NOT append '/generateAnswer' — that would 404.
  // This URL is the full address exported as `generateAnswer` in index.ts.
  final String cloudFunctionUrl =
      'https://generateanswer-kt3rxdstza-uc.a.run.app';

  /// Generate an answer using streaming for real-time response.
  Stream<String> generateAnswerStream(
    String question, {
    List<Message>? conversationHistory,
    String? conversationId,
  }) async* {
    try {
      print(
        ' Starting streaming for: '
        '"${question.substring(0, min(50, question.length))}..."',
      );

      final requestBody = {
        'query': question,
        'stream': true,
        'topK': 5,
        'minSimilarityScore': 0.30,
        'conversationHistory':
            conversationHistory
                ?.map((m) => {'sender': m.sender, 'content': m.content})
                .toList() ??
            [],
      };

      //  POST directly to cloudFunctionUrl — the function IS the endpoint.
      final request = http.Request('POST', Uri.parse(cloudFunctionUrl));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        print(' HTTP Error ${streamedResponse.statusCode}: $errorBody');
        yield 'I apologize, but I encountered an error processing your '
            'request. Please try again.';
        return;
      }

      String fullAnswer = '';
      int chunkCount = 0;
      final startTime = DateTime.now();

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty ||
            line.startsWith('event:') ||
            line == 'data: [DONE]') {
          continue;
        }

        String jsonStr = line.trim();
        if (jsonStr.startsWith('data: ')) {
          jsonStr = jsonStr.substring(6);
        }

        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;

          if (data['type'] == 'content-delta') {
            final text =
                data['delta']?['message']?['content']?['text'] as String?;

            if (text != null && text.isNotEmpty) {
              chunkCount++;
              fullAnswer += text;
              yield fullAnswer;
            }
          } else if (data['type'] == 'message-end') {
            final totalTime =
                DateTime.now().difference(startTime).inMilliseconds;
            print(' Streaming complete: $chunkCount chunks in ${totalTime}ms');

            if (fullAnswer.isNotEmpty) {
              yield fullAnswer;
            }
            break;
          } else if (data['type'] == 'error') {
            print(' Streaming error from server: ${data['error']}');
            if (fullAnswer.isEmpty) {
              yield 'I encountered an error processing your request. '
                  'Please try again.';
            }
            break;
          }
        } catch (e) {
          // Skip malformed SSE chunks without crashing.
          print(
            ' Failed to parse chunk: '
            '${jsonStr.substring(0, min(100, jsonStr.length))}',
          );
          continue;
        }
      }

      if (fullAnswer.isEmpty) {
        print(' No content received from stream');
        yield 'I apologize, but I was unable to generate a response. '
            'Please try again.';
      }
    } catch (e) {
      print(' Streaming error: $e');
      yield 'I apologize, but I encountered an error. Please try again or '
          'contact OASP staff.';
    }
  }

  /// Non-streaming fallback method (kept for compatibility).
  Future<String> generateAnswer(
    String query, {
    List<Message>? conversationHistory,
    String? conversationId,
    int topK = 5,
    double minSimilarityScore = 0.3,
  }) async {
    try {
      print(' Generating answer for: "$query"');

      final historyData =
          conversationHistory
              ?.map((msg) => {'sender': msg.sender, 'content': msg.content})
              .toList() ??
          [];

      final requestBody = {
        'query': query,
        'conversationHistory': historyData,
        'conversationId': conversationId,
        'topK': topK,
        'minSimilarityScore': minSimilarityScore,
      };

      //  POST directly to cloudFunctionUrl (same as streaming path).
      final response = await http
          .post(
            Uri.parse(cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Request timed out after 60 seconds');
            },
          );

      print(' Received response: ${response.statusCode}');

      if (response.statusCode != 200) {
        print(' Cloud Function error: ${response.body}');
        throw Exception(
          'Cloud Function returned error: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['answer'] == null || data['answer'].toString().trim().isEmpty) {
        return "I'm having trouble processing your question right now. "
            "Please try again or contact OASP staff for assistance.";
      }

      final answer = data['answer'] as String;
      final source = data['source'] as String?;

      print(' Generated answer from source: $source');

      return answer.trim();
    } catch (e, stackTrace) {
      print(' Error in generateAnswer: $e');
      print('Stack trace: $stackTrace');

      if (e.toString().contains('timeout')) {
        return "The request is taking longer than expected. Please try again "
            "or contact OASP staff for assistance.";
      } else if (e.toString().contains('network') ||
          e.toString().contains('SocketException')) {
        return "Network error. Please check your internet connection and try again.";
      } else {
        return "I encountered an error while processing your question. "
            "Please try again or contact OASP staff for assistance.";
      }
    }
  }

  /// Test the Cloud Function connection.
  Future<bool> testConnection() async {
    try {
      final response = await http
          .post(
            Uri.parse(cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': 'test', 'conversationHistory': []}),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 400;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}
