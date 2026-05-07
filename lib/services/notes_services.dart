import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note.dart';

class NoteService {
  final String baseUrl = "https://tu-api-principal.onrender.com/notes";

  Future<List<Note>> fetchNotes() async {
    final response = await http.get(Uri.parse('$baseUrl/'));
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((n) => Note.fromJson(n)).toList();
    }
    return [];
  }

  Future<bool> saveNote(Note note) async {
    final response = await http.post(
      Uri.parse('$baseUrl/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(note.toJson()),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteNote(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    return response.statusCode == 200;
  }
}