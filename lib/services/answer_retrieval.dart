import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:capstone_project/models/message.dart';

class AnswerRetrievalService {
  // Use the stable Firebase Functions URL instead of the generated Cloud Run
  // service URL, which can change after redeploys.
  final String cloudFunctionUrl =
      'https://us-central1-cmu-oasp-assist.cloudfunctions.net/generateAnswer';

  /// Generate an answer using streaming for real-time response.
  Stream<String> generateAnswerStream(
    String question, {
    List<Message>? conversationHistory,
    String? conversationId,
    bool isFAQSelection = false,
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
        'isFAQSelection': isFAQSelection,
        'conversationHistory':
            conversationHistory
                ?.map((m) => {'sender': m.sender, 'content': m.content})
                .toList() ??
            [],
      };

      final request = http.Request('POST', Uri.parse(cloudFunctionUrl));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = json.encode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        print(' HTTP Error ${streamedResponse.statusCode}: $errorBody');
        yield _extractAnswerFromJson(errorBody) ??
            'I apologize, but I encountered an error processing your '
                'request. Please try again.';
        return;
      }

      String fullAnswer = '';
      int chunkCount = 0;
      final startTime = DateTime.now();
      final contentType = streamedResponse.headers['content-type'] ?? '';

      if (contentType.toLowerCase().contains('application/json')) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final answer = _extractAnswerFromJson(responseBody);
        if (answer != null && answer.isNotEmpty) {
          yield answer;
          return;
        }

        print(' Unexpected JSON response: $responseBody');
        yield 'I apologize, but I was unable to generate a response. '
            'Please try again.';
        return;
      }

      await for (final jsonStr in _decodeServerSentEvents(
        streamedResponse.stream,
      )) {
        if (jsonStr == '[DONE]') break;

        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;

          if (data['type'] == 'error') {
            print(' Streaming error from server: ${data['error']}');
            final errorAnswer = _extractAnswerFromDynamic(data);
            if (fullAnswer.isEmpty &&
                errorAnswer != null &&
                errorAnswer.isNotEmpty) {
              yield errorAnswer;
            } else if (fullAnswer.isEmpty) {
              yield 'I encountered an error processing your request. '
                  'Please try again.';
            }
            break;
          }

          final text = _extractStreamText(data);

          if (text != null && text.isNotEmpty) {
            chunkCount++;
            fullAnswer += text;
            yield fullAnswer;
          } else if (data['type'] == 'message-end') {
            final totalTime =
                DateTime.now().difference(startTime).inMilliseconds;
            print(' Streaming complete: $chunkCount chunks in ${totalTime}ms');

            if (fullAnswer.isNotEmpty) {
              yield fullAnswer;
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

  Stream<String> _decodeServerSentEvents(Stream<List<int>> byteStream) async* {
    final buffer = StringBuffer();

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var pending = buffer.toString();
      var eventEnd = _firstEventBoundary(pending);

      while (eventEnd != null) {
        final rawEvent = pending.substring(0, eventEnd);
        pending = pending.substring(_boundaryEndIndex(pending, eventEnd));

        final dataLines = <String>[];
        for (final rawLine in const LineSplitter().convert(rawEvent)) {
          final line = rawLine.trimRight();
          if (line.isEmpty || line.startsWith(':') || line.startsWith('event:')) {
            continue;
          }
          if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trimLeft());
          }
        }

        final data = dataLines.join('\n').trim();
        if (data.isNotEmpty) {
          yield data;
        }

        eventEnd = _firstEventBoundary(pending);
      }

      buffer
        ..clear()
        ..write(pending);
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      for (final rawLine in const LineSplitter().convert(remaining)) {
        final line = rawLine.trim();
        if (line.startsWith('data:')) {
          final data = line.substring(5).trimLeft();
          if (data.isNotEmpty) yield data;
        }
      }
    }
  }

  int? _firstEventBoundary(String text) {
    final lf = text.indexOf('\n\n');
    final crlf = text.indexOf('\r\n\r\n');

    if (lf == -1) return crlf == -1 ? null : crlf;
    if (crlf == -1) return lf;
    return min(lf, crlf);
  }

  int _boundaryEndIndex(String text, int boundaryStart) {
    if (text.startsWith('\r\n\r\n', boundaryStart)) {
      return boundaryStart + 4;
    }
    return boundaryStart + 2;
  }

  String? _extractStreamText(Map<String, dynamic> data) {
    final delta = data['delta'];
    if (delta is Map) {
      final message = delta['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is Map) {
          final deltaText = content['text'];
          if (deltaText is String) return deltaText;
        }
      }
    }

    final directText = data['text'];
    if (directText is String) return directText;

    final answer = data['answer'];
    if (answer is String) return answer;

    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final firstCandidate = candidates.first;
      if (firstCandidate is Map) {
        final content = firstCandidate['content'];
        if (content is Map) {
          final parts = content['parts'];
          if (parts is List && parts.isNotEmpty) {
            final firstPart = parts.first;
            if (firstPart is Map) {
              final text = firstPart['text'];
              if (text is String) return text;
            }
          }
        }
      }
    }

    return null;
  }

  String? _extractAnswerFromJson(String body) {
    try {
      final decoded = json.decode(body);
      return _extractAnswerFromDynamic(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _extractAnswerFromDynamic(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;

    final answer = decoded['answer'];
    if (answer is String && answer.trim().isNotEmpty) {
      return answer.trim();
    }

    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final errorMessage = error['message'];
      if (errorMessage is String && errorMessage.trim().isNotEmpty) {
        return errorMessage.trim();
      }
    }

    return null;
  }

  /// Non-streaming fallback method (kept for compatibility).
  Future<String> generateAnswer(
    String query, {
    List<Message>? conversationHistory,
    String? conversationId,
    int topK = 5,
    double minSimilarityScore = 0.3,
    bool isFAQSelection = false,
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
        'isFAQSelection': isFAQSelection,
      };

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
