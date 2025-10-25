class DocumentChunk {
  final String id;
  final String text;
  final List<double> embedding;

  DocumentChunk({required this.id, required this.text, required this.embedding});
}
