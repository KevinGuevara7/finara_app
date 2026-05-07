class Note {
  final int? id;
  final String title;
  final String content;
  final String categoryName;
  final DateTime? createdAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.categoryName = 'General',
    this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      categoryName: json['category_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'category_name': categoryName,
  };
}