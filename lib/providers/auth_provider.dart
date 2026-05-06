import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/meta_ahorro.dart';

class AuthProvider extends ChangeNotifier {
  final storage = const FlutterSecureStorage();

  String? _token;

  String? get token => _token;

  bool get isAuthenticated => _token != null;

  // LOGIN
  Future<bool> login(String email, String password) async {
    final token = await ApiService.login(email, password);

    if (token != null) {
      _token = token;

      await storage.write(key: "jwt_token", value: token);

      notifyListeners();

      return true;
    }

    return false;
  }

  // REGISTER
  Future<bool> register(String name, String email, String password) async {
    return await ApiService.register(name, email, password);
  }

  // CARGAR TOKEN AL ABRIR LA APP
  Future<void> loadToken() async {
    final savedToken = await storage.read(key: "jwt_token");

    if (savedToken != null) {
      _token = savedToken;

      notifyListeners();
    }
  }

  // LOGOUT
  Future<void> logout() async {
    _token = null;

    await storage.delete(key: "jwt_token");

    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    if (_token == null) return null;

    return await ApiService.getUser(_token!);
  }

  // OBTENER METAS DE AHORRO
  List<MetaAhorro> _metas = [];

  List<MetaAhorro> get metas => _metas;

  void addMeta(MetaAhorro meta) {
  _metas.add(meta);
  notifyListeners();
}

  //aCTUALIZAR METAS
  void actualizarMetasConIngreso(double ingreso) {
  for (var meta in _metas) {
    meta.montoActual += ingreso * 0.1; // 10% automático
  }
  notifyListeners();
}

  //Limpiar metas (ejemplo al cerrar sesión)
  Future<void> logoutM() async {
  _token = null;
  _metas.clear(); //IMPORTANTE

  await storage.delete(key: "jwt_token");

  notifyListeners();
}
}
