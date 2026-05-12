import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note.dart';

class NoteService {
  // Nota que el baseUrl llega hasta "notes"
  final String baseUrl = "https://finara-api-1lmd.onrender.com/notes";

  Future<List<Note>> fetchNotes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((n) => Note.fromJson(n)).toList();
      }
      return [];
    } catch (e) {
      print("🚨 Error en fetchNotes: $e");
      return [];
    }
  }

  Future<bool> saveNote(Note note) async {
    try {
      http.Response response;
      final headers = {"Content-Type": "application/json"};
      final body = json.encode(note.toJson());

      if (note.id == null) {
        // SI NO HAY ID -> CREAR (POST)
        response = await http.post(
          Uri.parse('$baseUrl/'), // Con barra al final
          headers: headers,
          body: body,
        );
      } else {
        // SI HAY ID -> ACTUALIZAR (PUT)
        response = await http.put(
          Uri.parse('$baseUrl/${note.id}/'), // Con barra al final
          headers: headers,
          body: body,
        );
      }
      
      print("📡 STATUS GUARDAR: ${response.statusCode}");
      // Permitimos 200 (OK) o 201 (Creado)
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("🚨 Error en saveNote: $e");
      return false;
    }
  }

  Future<bool> deleteNote(int id) async {
    try {
      // ELIMINAR (DELETE) - ¡Aseguramos la barra al final!
      final response = await http.delete(Uri.parse('$baseUrl/$id/'));
      
      print("📡 STATUS ELIMINAR: ${response.statusCode}");
      // Permitimos 200 (OK) o 204 (Sin contenido)
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("🚨 Error en deleteNote: $e");
      return false;
    }
  }
}