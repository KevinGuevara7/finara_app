import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://finara-api-1lmd.onrender.com";

  static Future<String?> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/login");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["access_token"];
    } else {
      print("Error login: ${response.body}");
      return null;
    }
  }

  static Future<bool> register(
      String name, String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/register");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "email": email, "password": password}),
    );

    print("REGISTER STATUS: ${response.statusCode}");
    print("REGISTER BODY: ${response.body}");

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>?> getUser(String token) async {
    final url = Uri.parse("$baseUrl/users/me");

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  static Future<bool> createTransaction(
    String token,
    String type,
    double amount,
    String description,
    int categoryId,
  ) async {
    final url = Uri.parse("$baseUrl/transactions/");

    final body = jsonEncode({
      "type": type.toLowerCase(),
      "amount": amount,
      "description": description,
      "category_id": categoryId,
    });

    print("CREATE BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: body,
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<List<dynamic>> getTransactions(String token) async {
    final url = Uri.parse("$baseUrl/transactions/");

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return [];
  }

  static Future<bool> updateTransaction(
    String token,
    int id,
    String type,
    double amount,
    String description,
    int categoryId,
  ) async {
    final url = Uri.parse("$baseUrl/transactions/$id");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "type": type.toLowerCase(),
        "amount": amount,
        "description": description,
        "category_id": categoryId,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<bool> deleteTransaction(String token, int id) async {
    final url = Uri.parse("$baseUrl/transactions/$id");

    final response = await http.delete(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getTransactionCategories(String token) async {

  try {
    // CAMBIO AQUÍ: Solo una vez la palabra categories y sin barra final
    final url = Uri.parse("$baseUrl/categories"); 

    final response = await http.get(

      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Error en GET: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    print("Excepción en GET: $e");
    return [];
  }
}


  // 2. CREAR CATEGORÍA (POST)
  static Future<bool> createCategory(String token, String name, String type) async {
    try {
      final url = Uri.parse("$baseUrl/categories"); // Solo una vez categories

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "type": type,
        }),
      );

      print("🚀 Enviando creación a: $url");
      print("📊 Status del Backend: ${response.statusCode}");
      print("📄 Body del Backend: ${response.body}");

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("❌ Error de red: $e");
      return false;
    }
  
}


// --- ACTUALIZAR CATEGORÍA (PUT) ---
  static Future<bool> updateCategory(String token, int id, String name, String type) async {
  try {
    // Aseguramos que la URL sea limpia: base + /categories/ + id
    final baseUrlClean = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse("$baseUrlClean/categories/$id");

    print("🚀 Intentando PUT a: $url");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "type": type,
      }),
    );

    print("📊 Status del Backend: ${response.statusCode}");
    return response.statusCode == 200;
  } catch (e) {
    print("❌ Error de red: $e");
    return false;
  }
}
  // --- ELIMINAR (DELETE) ---
  static Future<bool> deleteCategory(String token, int id) async {
    try {
      // IMPORTANTE: Agregamos el prefijo doble /categories/categories/
      final url = Uri.parse(
          "$baseUrl/categories/$id"); // Verifica si tu API requiere / al final

      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      // FastAPI suele devolver 200 o 204 (No Content) al borrar con éxito
      if (response.statusCode == 200 || response.statusCode == 204) {
        print("Categoría eliminada con éxito");
        return true;
      } else {
        print("Error al borrar: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error de red al borrar: $e");
      return false;
    }
  }

  static Future<bool> resetPassword(String token, String newPassword) async {
    final url = Uri.parse("$baseUrl/auth/reset-password");

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "token": token,
              "new_password": newPassword,
            }),
          )
          .timeout(const Duration(seconds: 60));

      return response.statusCode == 200;
    } catch (e) {
      print("ERROR RESET PASSWORD: $e");
      return false;
    }
  }

  static Future<bool> forgotPassword(String email) async {
    final url = Uri.parse("$baseUrl/auth/forgot-password");

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(const Duration(seconds: 60));

      return response.statusCode == 200;
    } catch (e) {
      print("ERROR FORGOT PASSWORD: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getUsers(String token) async {
    final url = Uri.parse("$baseUrl/users/all");

    final res =
        await http.get(url, headers: {"Authorization": "Bearer $token"});

    return jsonDecode(res.body);
  }

  static Future<void> deleteUser(String token, int id) async {
    await http.delete(
      Uri.parse("$baseUrl/users/delete/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
  }

  static Future<void> makeAdmin(String token, int id) async {
    await http.put(
      Uri.parse("$baseUrl/users/make-admin/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
  }

  static Future<void> removeAdmin(String token, int id) async {
    await http.put(
      Uri.parse("$baseUrl/users/remove-admin/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
  }

  static Future<List<dynamic>> getCategories() async {
    final response = await http.get(Uri.parse("$baseUrl/videos/categories"));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Error al cargar categorías");
    }
  }

  // Obtener videos por categoría
  static Future<List<dynamic>> getVideos(int categoryId) async {
    final response = await http.get(Uri.parse("$baseUrl/videos/$categoryId"));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Error al cargar videos");
    }
  }

  static Future<bool> createVideoCategory(
    String title,
    String description,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/videos/categories"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
      }),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateVideoCategory(
    int id,
    String title,
    String description,
  ) async {
    final response = await http.put(
      Uri.parse("$baseUrl/videos/categories/$id"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<bool> deleteVideoCategory(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/videos/categories/$id"),
    );

    return response.statusCode == 200;
  }

  static Future<bool> createVideo(
    String title,
    String url,
    int categoryId,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/videos/"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "url": url,
        "category_id": categoryId,
      }),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateVideo(
    int id,
    String title,
    String url,
    int categoryId,
  ) async {
    final response = await http.put(
      Uri.parse("$baseUrl/videos/$id"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "url": url,
        "category_id": categoryId,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<bool> deleteVideo(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/videos/$id"),
    );

    return response.statusCode == 200;
  }

  Future<List<dynamic>> obtenerLecturas() async {
    final response = await http
        .get(Uri.parse("https://finara-api-1lmd.onrender.com/api/lecturas/"));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Error al cargar lecturas");
    }
  }

  static Future<List<dynamic>> getLecturas() async {
    final response = await http.get(
      Uri.parse("$baseUrl/api/lecturas/"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Error al cargar lecturas");
    }
  }

  static Future<bool> createLectura(
    String titulo,
    String contenido,
    String tiempoLectura,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/lecturas/"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "titulo": titulo,
        "contenido": contenido,
        "tiempo_lectura": tiempoLectura,
      }),
    );

    print("CREATE LECTURA STATUS: ${response.statusCode}");
    print("CREATE LECTURA BODY: ${response.body}");

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> deleteLectura(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/api/lecturas/$id"),
    );

    print("DELETE LECTURA STATUS: ${response.statusCode}");
    print("DELETE LECTURA BODY: ${response.body}");

    return response.statusCode == 200;
  }

  static Future<bool> updateLectura(
    int id,
    String titulo,
    String contenido,
    String tiempoLectura,
  ) async {
    final response = await http.put(
      Uri.parse("$baseUrl/api/lecturas/$id"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "titulo": titulo,
        "contenido": contenido,
        "tiempo_lectura": tiempoLectura,
      }),
    );

    print("UPDATE LECTURA STATUS: ${response.statusCode}");
    print("UPDATE LECTURA BODY: ${response.body}");

    return response.statusCode == 200;
  }

  static Future<List<dynamic>> getMessages(String token, int userId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/messages/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    return jsonDecode(res.body);
  }

  static Future<bool> sendMessage(
    String token,
    int receiverId,
    String content,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/messages/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({"receiver_id": receiverId, "content": content}),
    );

    print(res.statusCode);
    print(res.body);

    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<List<dynamic>> getUsersPublic(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/users/"),
      headers: {"Authorization": "Bearer $token"},
    );

    return jsonDecode(res.body);
  }

  
}
