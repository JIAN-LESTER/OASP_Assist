class InformationBank {
  final String id;
  final String title;
  final String content;
  final dynamic embedding;
  final String source;
  final String category;

  // Chunk metadata
  final int? part;
  final int? totalParts;
  final int? chunkSize;
  final bool? isFirstChunk;
  final bool? isLastChunk;
  final String? originalDocId;
  final String? originalTitle;

  InformationBank({
    required this.id,
    required this.title,
    required this.content,
    required this.embedding,
    required this.source,
    required this.category,
    this.part,
    this.totalParts,
    this.chunkSize,
    this.isFirstChunk,
    this.isLastChunk,
    this.originalDocId,
    this.originalTitle,
  });

  factory InformationBank.fromJson(Map<String, dynamic> json) {
    return InformationBank(
      id: json['ibID'] ?? json['id'],
      title: json['ib_title'] ?? json['title'],
      content: json['content'],
      embedding: List<double>.from(json['embedding']),
      source: json['source'],
      category: json['categoryID'] ?? json['category'],
      part: json['chunkIndex'], // chunk index (optional)
      totalParts: json['totalChunks'], // total chunks
      chunkSize: json['chunkSize'],
      isFirstChunk: json['isFirstChunk'],
      isLastChunk: json['isLastChunk'],
      originalDocId: json['originalDocId'],
      originalTitle: json['originalTitle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ibID': id,
      'ib_title': title,
      'content': content,
      'embedding': embedding,
      'source': source,
      'categoryID': category,
      'chunkIndex': part,
      'totalChunks': totalParts,
      'chunkSize': chunkSize,
      'isFirstChunk': isFirstChunk,
      'isLastChunk': isLastChunk,
      'originalDocId': originalDocId,
      'originalTitle': originalTitle,
    };
  }
}
