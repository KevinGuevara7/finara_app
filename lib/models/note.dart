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
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      // Usamos el nombre exacto de tu FastAPI: category_name
      categoryName: json['category_name'] ?? 'General',
      // Validamos que el campo exista antes de intentar parsearlo
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  // Este es el que usas en NoteService para enviar a FastAPI
  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'category_name': categoryName,
  };

  // Alias para mantener compatibilidad si usas .fromMap o .toMap
  factory Note.fromMap(Map<String, dynamic> map) => Note.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}