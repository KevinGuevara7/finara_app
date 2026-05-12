import 'package:finara_app_v1/models/category_model.dart';
import 'package:finara_app_v1/providers/auth_provider.dart';
import 'package:finara_app_v1/widgets/translate_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finara_app_v1/providers/theme_provider.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../widgets/custom_bottom_nav.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:finara_app_v1/providers/languaje_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:finara_app_v1/models/meta_ahorro.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;

    // Quita cualquier cosa que no sea numero
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Convierte a numero y formatea (ejemplo: 1000 -> 1.000)
    double value = double.parse(newText) / 100; // Divide por 100 para centavos
    final formatter = NumberFormat.currency(symbol: '', decimalDigits: 2);
    String formatted = formatter.format(value).trim();

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Map<String, dynamic> _getCategoryData(String description) {
  // Comparamos la descripcion para asignar icono y color
  String desc = description.toLowerCase();
  if (desc.contains("mercado")) {
    return {'icon': Icons.shopping_basket_rounded, 'color': Colors.orange};
  } else if (desc.contains("pago") || desc.contains("trabajo")) {
    return {'icon': Icons.work_rounded, 'color': Colors.blue};
  } else if (desc.contains("ahorro")) {
    return {'icon': Icons.savings_rounded, 'color': Colors.pink};
  } else if (desc.contains("gasto") || desc.contains("adicional")) {
    return {'icon': Icons.add_circle_outline_rounded, 'color': Colors.purple};
  }
  return {'icon': Icons.category_rounded, 'color': Colors.grey};
}

class _ProfileScreenState extends State<ProfileScreen> {
  final NumberFormat formatter = NumberFormat("#,##0.00", "en_US");

  String? profileImageUrl;
  String name = "";
  String email = "";

  List<TransactionModel> transactions = [];
  List<CategoryModel> categories = [];
  bool showAllMovements = false;

  void _showFloatingMessage(String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 14,
        left: 18,
        right: 18,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? const Color(0xFFB91C1C) : const Color(0xFF047857),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    loadUser();
    _loadData();
  }

  Future<void> loadTransactions() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null || auth.token!.isEmpty) return;

    final data = await ApiService.getTransactions(auth.token!);

    print(data);

    try {
      final loadedTransactions =
          data.map((e) => TransactionModel.fromMap(e)).toList();

      print("TRANSACCIONES OK");

      if (!mounted) return;

      setState(() {
        transactions = loadedTransactions;
      });
    } catch (e) {
      print("ERROR PARSEANDO TRANSACCIONES");
      print(e);
    }
  }

  void loadUser() async {
    try {
      final auth = context.read<AuthProvider>();
      if (auth.token == null || auth.token!.isEmpty) {
        setState(() {
          name = "Sesion vencida";
          email = "Inicia sesion nuevamente";
          profileImageUrl = null;
        });
        return;
      }

      final data = await auth.getUserData();
      print(data);

      setState(() {
        if (data != null) {
          name = data["name"] ?? "Sin nombre";
          email = data["email"] ?? "Sin email";
          profileImageUrl = data["profile_image_url"];
        } else {
          name = "No se pudo cargar";
          email = "";
          profileImageUrl = null;
        }
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        name = "Error cargando";
        email = "";
      });
    }
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null || auth.token!.isEmpty) return;

    await loadCategories();
    await loadTransactions();
  }

  Future<void> loadCategories() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null || auth.token!.isEmpty) return;

    final data = await ApiService.getTransactionCategories(auth.token!);

    if (!mounted) return;

    setState(() {
      categories = data.map((e) => CategoryModel.fromMap(e)).toList();
    });
  }

  String getCategoryName(int categoryId) {
    try {
      return categories
          .firstWhere(
            (c) => int.parse(c.id) == categoryId,
          )
          .name;
    } catch (e) {
      return "General";
    }
  }

  ImageProvider? _profileImageProvider() {
    final imageUrl = profileImageUrl;

    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    if (imageUrl.startsWith("data:image")) {
      try {
        final commaIndex = imageUrl.indexOf(",");
        if (commaIndex == -1) return null;

        return MemoryImage(base64Decode(imageUrl.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }

    return NetworkImage(imageUrl);
  }
  
  double getBalance() {
    double total = 0;

    for (var t in transactions) {
      if (t.type == "ingreso") {
        total += t.amount;
      } else {
        total -= t.amount;
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final metas = context.watch<AuthProvider>().metas;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF064E3B);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // APPBAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.transparent, // Fondo transparente para mayor fluidez
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            // Logo o Icono de la marca con un degradado sutil
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF00E676)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                    12), // Bordes mas redondeados son tendencia
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Finara", // Nombre de la App
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B4332),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Mi Perfil", // Subti­tulo indicativo
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      //DRAWER (MENU)
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // HEADER PERSONALIZADO
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF064E3B),
              ),
              currentAccountPicture: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white24,
                          width: 2), // Un borde lo hace ver mÃ¡s fino
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white12,
                      // Usamos un try-catch visual con errorBuilder si fuera necesario,
                      // pero aquÃ­ optimizamos la lÃ³gica de carga
                      backgroundImage: _profileImageProvider(),
                      child:
                          (profileImageUrl == null || profileImageUrl!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.white54)
                              : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: AnimatedContainer(
                        // Pequeña animacion al tocar
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(
                            6), // Un poquito más grande para el dedo
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(
                            Icons
                                .camera_alt, // Camera_alt se entiende mejor que edit
                            color: Colors.white,
                            size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              accountName: Text(
                name.isEmpty ? "Cargando..." : name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white),
              ),
              accountEmail: Text(
                email.isEmpty ? "Cargando..." : email,
                style: const TextStyle(color: Colors.white70),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("CONFIGURACIÃ“N",
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                  ),

                  // MODO OSCURO MEJORADO
                  _buildDrawerItem(
                    icon: isDark ? Icons.light_mode : Icons.dark_mode,
                    title: isDark ? "Modo claro" : "Modo oscuro",
                    color: Colors.orange,
                    onTap: () => context.read<ThemeProvider>().toggleTheme(),
                  ),

                  _buildDrawerItem(
                    icon: Icons.picture_as_pdf_outlined,
                    title: "Descargar movimientos",
                    subtitle: "Exportar historial en PDF",
                    color: const Color(0xFF00C853),
                    onTap: () async {
                      Navigator.pop(context);
                      await _downloadMovementsPdf();
                    },
                  ),

                  // IDIOMA MEJORADO
                  Consumer<LanguageProvider>(
                    builder: (context, langProvider, child) {
                      return _buildDrawerItem(
                        icon: Icons.translate,
                        title: "Idioma de la App",
                        subtitle: langProvider.currentLanguageName,
                        color: const Color(0xFF00C853),
                        onTap: () => _showLanguagePicker(context, langProvider),
                      );
                    },
                  ),

                  const Divider(),
                ],
              ),
            ),

            // BOTÃ“N DE CERRAR SESIÃ“N
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.red.withOpacity(0.1),
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const TranslatedText("Cerrar sesiÃ³n",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  final auth = context.read<AuthProvider>();

                  await auth.logout();

                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),

      //BODY CRUD
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            //PERFIL
            Row(
              children: [
                CircleAvatar(
                  radius: 20, // MÃ¡s pequeÃ±o
                  backgroundColor: Colors.white12,
                  // <-- ESTA ES LA CLAVE: Lee la MISMA variable 'profileImageUrl'
                  backgroundImage: _profileImageProvider(),
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person_outline_rounded,
                          size: 20, color: Colors.white54)
                      : null,
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? "Cargando..." : name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      email.isEmpty ? "Cargando..." : email,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // TARJETA DE BALANCE MEJORADA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24), // Un poco mÃ¡s de aire
              decoration: BoxDecoration(
                // Un degradado sutil lo hace ver mÃ¡s "Premium"
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                      : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Balance Total",
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF1B4332).withOpacity(0.7),
                          fontSize: 16,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF1B4332).withOpacity(0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatCurrency(getBalance()), // <-- Usando la funciÃ³n nueva
                    style: TextStyle(
                      fontSize: 36, // Un poco mÃ¡s grande
                      fontWeight: FontWeight.w900, // MÃ¡s grueso
                      letterSpacing:
                          -1, // Un poco mÃ¡s juntas las letras se ve pro
                      color: isDark ? Colors.white : const Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Un pequeÃ±o indicador extra le da el toque final
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Actualizado hace un momento",
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF1B4332),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //SECCIÃ“N METAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Metas de ahorro",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _crearMeta,
                  icon: const Icon(Icons.add, color: Color(0xFF00C853)),
                )
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 180,
              child: metas.isEmpty
                  ? const Center(child: Text("No hay metas aÃºn"))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: metas.length,
                      itemBuilder: (context, index) {
                        final meta = metas[index];

                        return Container(
                          width: 220,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color.fromARGB(255, 6, 78, 59)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10)
                                  ],
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(meta.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _editarMeta(index),
                                          child: const Icon(Icons.edit,
                                              size: 18,
                                              color: Color.fromARGB(
                                                  255, 5, 46, 35)),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _eliminarMeta(index),
                                          child: const Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: meta.progreso.clamp(0, 1),
                                  backgroundColor: Colors.grey[300],
                                  color: const Color(0xFF00C853),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    "${meta.porcentaje.toStringAsFixed(1)}% completado"),
                                const SizedBox(height: 5),
                                Text(
                                  "Faltan: ${meta.mesesRestantes} meses",
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ]),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 20),

            //TÃTULO Y BOTÃ“N AGREGAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const TranslatedText(
                  "Movimientos",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => showForm(),
                  icon: const Icon(Icons.add, color: Color(0xFF00C853)),
                  label: const TranslatedText("Agregar",
                      style: TextStyle(color: Color(0xFF00C853))),
                ),
              ],
            ),

            const SizedBox(height: 10),

            //LISTA DE TRANSACCIONES
            if (transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF10231F) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text("No hay movimientos registrados"),
                ),
              )
            else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: showAllMovements
                  ? transactions.length
                  : transactions.take(4).length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final t = transactions[index];
                final bool isIngreso = t.type == "ingreso";
                final categoryName =
                    getCategoryName(int.tryParse(t.categoryId) ?? 0);
                final catData = _getCategoryData(categoryName);
                return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10)
                            ],
                    ),
                    child: Row(
                      children: [
                        //ICON SEGÃšN LA IMAGEN
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: catData['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(catData['icon'],
                              color: catData['color'], size: 24),
                        ),
                        const SizedBox(width: 15),

                        //DESCRIPCIÃ“N Y FECHA
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.description,
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "14/04/2026",
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        //MONTO Y ACCIONES
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${isIngreso ? '+' : '-'} ${formatCurrency(t.amount)}",
                              style: TextStyle(
                                color:
                                    isIngreso ? Colors.green : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => showForm(edit: t),
                                  child: const Icon(Icons.edit_note,
                                      size: 20, color: Colors.blueGrey),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => confirmDelete(t),
                                  child: const Icon(Icons.delete_outline,
                                      size: 20, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                );
              },
            ),
            if (transactions.length > 4) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => showAllMovements = !showAllMovements);
                  },
                  icon: Icon(showAllMovements
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                  label: Text(showAllMovements
                      ? "Mostrar menos"
                      : "Ver todos los movimientos"),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(
        selectedIndex: 4,
      ),
    );
  }

  void showForm({TransactionModel? edit}) async {
    await loadCategories();
    List<CategoryModel> localCategories = List.from(categories);
    final dateController = TextEditingController(
        text: edit != null
            ? "10/27/2023"
            : "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}");

    final desc = TextEditingController(text: edit?.description);
    final amount =
        TextEditingController(text: edit != null ? edit.amount.toString() : "");
    String type = edit?.type ?? "gasto";
    int? selectedCategoryId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        bool isLoadingDialog = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final filteredCategories =
                localCategories.where((c) => c.type == type).toList();

            if (filteredCategories.isNotEmpty) {
              if (selectedCategoryId == null ||
                  !filteredCategories
                      .any((c) => int.parse(c.id) == selectedCategoryId)) {
                selectedCategoryId = int.parse(filteredCategories.first.id);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  //BARRA SUPERIOR (Indicador de arrastre)
                  const SizedBox(height: 12),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TÃTULO
                          Center(
                            child: Text(
                              edit == null
                                  ? "Nuevo Movimiento"
                                  : "Editar Movimiento",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ), // Center
                          ),

                          const SizedBox(height: 25),

                          // SELECTOR GASTO / INGRESO
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                _buildTypeButton(
                                    "gasto",
                                    type,
                                    (v) => setStateDialog(() {
                                          type = v;
                                        }),
                                    isDark),
                                _buildTypeButton(
                                    "ingreso",
                                    type,
                                    (v) => setStateDialog(() {
                                          type = v;
                                        }),
                                    isDark),
                              ],
                            ), // Row
                          ),

                          const SizedBox(height: 35),

                          // CAMPO MONTO

                          const Center(
                            child: TranslatedText(
                              "Ingresar monto",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          TextField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            style: const TextStyle(
                              fontSize: 45,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF064E3B),
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.attach_money,
                                  size: 35, color: Color(0xFF064E3B)),
                              hintText: "0.00",
                              border: InputBorder.none,
                            ),
                          ),

                          const SizedBox(height: 25),

                          // SELECTOR CATEGORÃA
                          const TranslatedText("CategorÃ­a",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 10),

// 1. BotÃ³n para crear nueva
                          // 1. BotÃ³n para crear nueva
                          TextButton(
                            onPressed: () async {
                              String? nueva =
                                  await _mostrarDialogoNuevaCategoria();

                              if (nueva != null && nueva.isNotEmpty) {
                                // ValidaciÃ³n local: Usamos ignoreCase para mayor seguridad
                                if (localCategories.any((c) =>
                                    c.name.toLowerCase() ==
                                    nueva.toLowerCase())) {
                                  _showFloatingMessage("Esa categoria ya existe", isError: true);
                                  return;
                                }

                                final auth = context.read<AuthProvider>();
                                // Asumimos que la API devuelve el objeto creado o al menos confirma el Ã©xito
                                bool success = await ApiService.createCategory(
                                    auth.token!, nueva, type);

                                if (success) {
                                  await loadCategories(); // Recarga la lista global 'categories'

                                  setStateDialog(() {
                                    // ACTUALIZACIÃ“N CRÃTICA:
                                    // 1. Sincronizamos la lista local con la global reciÃ©n cargada
                                    localCategories = List.from(categories);

                                    // 2. Filtramos inmediatamente para que el Dropdown vea el cambio
                                    final filtered = localCategories
                                        .where((c) => c.type == type)
                                        .toList();

                                    if (filtered.isNotEmpty) {
                                      // 3. Intentamos encontrar la que acabamos de crear por nombre
                                      // (Es mÃ¡s seguro que .last si la lista viene ordenada del servidor)
                                      final creada = filtered.firstWhere(
                                        (c) =>
                                            c.name.toLowerCase() ==
                                            nueva.toLowerCase(),
                                        orElse: () => filtered.last,
                                      );
                                      selectedCategoryId = int.parse(creada.id);
                                    }
                                  });
                                }
                              }
                            },
                            child: const Text("Agregar categorÃ­a",
                                style: TextStyle(color: Colors.green)),
                          ),

// 2. Fila con Dropdown + Editar + Eliminar
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black12
                                        : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(15),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: DropdownButton<int>(
                                    value: selectedCategoryId,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    // IMPORTANTE: AsegÃºrate de que filteredCategories se re-calcule
                                    // antes de este punto en el build del diÃ¡logo.
                                    items: localCategories
                                        .where((c) =>
                                            c.type ==
                                            type) // Filtramos aquÃ­ directamente para evitar desfases
                                        .map((cat) {
                                      return DropdownMenuItem<int>(
                                        value: int.parse(cat.id),
                                        child: Text(cat.name),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      setStateDialog(
                                          () => selectedCategoryId = v);
                                    },
                                  ),
                                ),
                              ),
                              if (selectedCategoryId != null) ...[
                                // BOTÃ“N EDITAR
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.blueAccent),
                                  onPressed: () async {
                                    // Buscamos en localCategories directamente
                                    final catActual =
                                        localCategories.firstWhere(
                                      (c) =>
                                          int.parse(c.id) == selectedCategoryId,
                                    );

                                    String? nuevoNombre =
                                        await _mostrarDialogoNuevaCategoria(
                                      valorInicial: catActual.name,
                                    );

                                    if (nuevoNombre != null &&
                                        nuevoNombre.isNotEmpty) {
                                      final auth = context.read<AuthProvider>();
                                      bool success =
                                          await ApiService.updateCategory(
                                        auth.token!,
                                        selectedCategoryId!,
                                        nuevoNombre,
                                        type,
                                      );
                                      if (success) {
                                        await loadCategories();
                                        setStateDialog(() {
                                          localCategories =
                                              List.from(categories);
                                        });
                                        _showFloatingMessage(
                                            "Categoria actualizada");
                                      } else {
                                        _showFloatingMessage(
                                          "Error al actualizar la categoria",
                                          isError: true,
                                        );
                                      }
                                    }
                                  },
                                ),
                                // BOTÃ“N ELIMINAR
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () async {
                                    bool? confirmar = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title:
                                            const Text("Â¿Eliminar categorÃ­a?"),
                                        content: const Text(
                                            "Esta acciÃ³n no se puede deshacer."),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text("Cancelar"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text("Eliminar",
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmar == true) {
                                      final auth = context.read<AuthProvider>();
                                      bool success =
                                          await ApiService.deleteCategory(
                                        auth.token!,
                                        selectedCategoryId!,
                                      );
                                      if (success) {
                                        await loadCategories();
                                        setStateDialog(() {
                                          localCategories =
                                              List.from(categories);
                                          selectedCategoryId =
                                              null; // Reset de selecciÃ³n
                                        });
                                        _showFloatingMessage("Categoria eliminada con exito");
                                      } else {
                                        _showFloatingMessage("Error al eliminar la categoria", isError: true);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 25),

                          //AQUÃ REGRESA LA FECHA
                          const TranslatedText("Fecha",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: edit != null &&
                                        dateController.text.isNotEmpty
                                    ? (DateFormat("MM/dd/yyyy")
                                            .tryParse(dateController.text) ??
                                        DateTime.now())
                                    : DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null) {
                                setStateDialog(() => dateController.text =
                                    DateFormat("MM/dd/yyyy").format(picked));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color:
                                    isDark ? Colors.black12 : Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Colors.green, size: 20),
                                  const SizedBox(width: 12),
                                  Text("${dateController.text}"),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          //Notas
                          const TranslatedText("Notas",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: desc,
                            decoration: InputDecoration(
                              hintText: "Escribe una nota...",
                              filled: true,
                              fillColor:
                                  isDark ? Colors.black12 : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 35),
                          // BOTÃ“N GUARDAR

                          //(SizedBox despuÃ©s del TextField de Notas)
                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C853),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                elevation: 0,
                              ),
                              onPressed: isLoadingDialog
                                  ? null
                                  : () async {
                                      // 1. Validar que el monto no estÃ© vacÃ­o o sea 0
                                      String cleanText = amount.text
                                          .replaceAll(RegExp(r'[^0-9.]'), '');
                                      double montoFinal =
                                          double.tryParse(cleanText) ?? 0.0;
                                      DateTime fechaFinal =
                                          DateFormat("MM/dd/yyyy")
                                              .parse(dateController.text);
                                      if (selectedCategoryId == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Selecciona una categor­a")),
                                        );
                                        return;
                                      }

                                      int categoryId = selectedCategoryId!;

                                      if (montoFinal <= 0) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: TranslatedText(
                                                  "Por favor ingresa un monto vÃ¡lido")),
                                        );
                                        return;
                                      }

                                      if (desc.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: TranslatedText(
                                                  "Por favor ingresa una descripciÃ³n")),
                                        );
                                        return;
                                      }

                                      setStateDialog(
                                          () => isLoadingDialog = true);

                                      final auth = context.read<AuthProvider>();

                                      bool success;
                                      if (edit == null) {
                                        // ES NUEVO
                                        success =
                                            await ApiService.createTransaction(
                                          auth.token!,
                                          type,
                                          montoFinal,
                                          desc.text,
                                          categoryId,
                                        );
                                        if (type == "ingreso") {
                                          await context
                                              .read<AuthProvider>()
                                              .actualizarMetasConIngreso(
                                                  montoFinal);
                                        }
                                      } else {
                                        // ES EDICIÃ“N
                                        success =
                                            await ApiService.updateTransaction(
                                          auth.token!,
                                          edit.id!,
                                          type,
                                          montoFinal,
                                          desc.text,
                                          categoryId,
                                        );
                                      }

                                      if (success) {
                                        if (!mounted) return;
                                        Navigator.pop(
                                            context); // Cierra el formulario
                                        loadTransactions(); // Recarga la lista principal
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(edit == null
                                                  ? "Creado con Ã©xito"
                                                  : "Actualizado con Ã©xito")),
                                        );
                                      } else {
                                        setStateDialog(
                                            () => isLoadingDialog = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: TranslatedText(
                                                  "Error al guardar en el servidor")),
                                        );
                                      }
                                    },
                              child: isLoadingDialog
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : TranslatedText(
                                      edit == null
                                          ? "Guardar Movimiento"
                                          : "Actualizar Movimiento",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          // DropdownButton
                        ], // Cierre de children
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// Helper para los botones de tipo
  Widget _buildTypeButton(
      String title, String current, Function(String) onTap, bool isDark) {
    bool isSelected = title == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF064E3B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 4)
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title[0].toUpperCase() + title.substring(1),
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.green)
                    : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void confirmDelete(TransactionModel t) {
    showDialog(
      context: context,
      builder: (_) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Â¿Eliminar movimiento?",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Se eliminarÃ¡ '${t.description}'"),
                  const SizedBox(height: 8),
                  Text("Monto: \$${t.amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context),
                  child: const Text("Cancelar",
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          // ... tu lÃ³gica de borrado que ya tienes ...
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Eliminar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _mostrarDialogoNuevaCategoria({String? valorInicial}) async {
    TextEditingController controller = TextEditingController();
    controller.text = valorInicial ?? '';

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const TranslatedText("Nueva categorÃ­a"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Ej: Transporte, Comida...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: const TranslatedText("Guardar"),
          ),
        ],
      ),
    );
  }

  // Constructor de items para el menÃº
  Widget _buildDrawerItem(
      {required IconData icon,
      required String title,
      String? subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color),
      ),
      title: TranslatedText(title,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

// El Modal de Idioma pero llamado desde afuera
  void _showLanguagePicker(
      BuildContext context, LanguageProvider langProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize:
              MainAxisSize.min, // Hace que el modal solo ocupe lo necesario
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: TranslatedText("Selecciona Idioma",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: langProvider.supportedLanguages.length,
                itemBuilder: (context, index) {
                  String key =
                      langProvider.supportedLanguages.keys.elementAt(index);
                  String name = langProvider.supportedLanguages[key]!;
                  return ListTile(
                    title: Text(name),
                    trailing: langProvider.currentLanguage == key
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      langProvider.setLanguage(key);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _downloadMovementsPdf() async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay movimientos para exportar")),
      );
      return;
    }

    final pdf = pw.Document();
    final generatedAt = DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            "Movimientos Finara",
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text("Usuario: ${name.isEmpty ? 'Sin nombre' : name}"),
          pw.Text("Email: ${email.isEmpty ? 'Sin email' : email}"),
          pw.Text("Generado: $generatedAt"),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ["Tipo", "Categoria", "Descripcion", "Monto"],
            data: transactions.map((t) {
              final categoryName =
                  getCategoryName(int.tryParse(t.categoryId) ?? 0);
              return [
                t.type,
                categoryName,
                t.description,
                formatCurrency(t.amount),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF064E3B),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(85),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Balance total: ${formatCurrency(getBalance())}",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "movimientos_finara.pdf",
    );
  }

  Future<void> _pickImage() async {
    final auth = context.read<AuthProvider>(); // Obtenemos el token
    if (auth.token == null || auth.token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inicia sesion nuevamente")),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();

    // 1. Seleccionar la imagen
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Comprimimos un poco para que suba mas rapido
    );

    if (image == null) return;

    // 2. Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    bool loadingDialogOpen = true;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/users/upload-profile-picture'),
      );

      // 3. Agregar el Token (Indispensable para tu Backend)
      request.headers['Authorization'] = 'Bearer ${auth.token}';

      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: image.name));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath('file', image.path));
      }

      // 4. Enviar y procesar
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Quitar el ci­rculo de carga
      if (!mounted) return;

      if (loadingDialogOpen) {
        Navigator.pop(context);
        loadingDialogOpen = false;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        setState(() {
          profileImageUrl = data['url'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil actualizada")),
        );
      } else {
        throw "Error del servidor: ${response.statusCode}";
      }
    } catch (e) {
      if (!mounted) return;

      if (loadingDialogOpen) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al subir imagen: $e")),
      );
    }
  }

  String formatCurrency(double amount) {
    // Crea un formato: $1,234.56
    final formatter = NumberFormat.currency(locale: "en_US", symbol: "\$");
    return formatter.format(amount);
  }

  double _parseAmount(String value) {
    final normalized = value.replaceAll(",", "").trim();
    return double.tryParse(normalized) ?? 0;
  }

  void _crearMeta() {
    TextEditingController nombre = TextEditingController();
    TextEditingController montoMeta = TextEditingController();
    TextEditingController montoActual = TextEditingController();
    TextEditingController ahorroMensual = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  //Indicador de arrastre
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 25,
                        right: 25,
                        top: 20,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          //TITULO
                          const Center(
                            child: Text(
                              "Nueva meta de ahorro",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF064E3B), // verde oscuro
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          //NOMBRE
                          const Text(
                            "Nombre",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: nombre,
                            decoration: InputDecoration(
                              hintText: "Ej: Viaje, Moto, Laptop...",
                              filled: true,
                              fillColor:
                                  isDark ? Colors.black12 : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          const Text(
                            "Monto actual",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: montoActual,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.trending_up,
                                  color: Color(0xFF064E3B)),
                              hintText: "0.00",
                              filled: true,
                              fillColor:
                                  isDark ? Colors.black12 : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          //MONTO META
                          const Text(
                            "Monto objetivo",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: montoMeta,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.attach_money,
                                  color: Color(0xFF064E3B)),
                              hintText: "0.00",
                              filled: true,
                              fillColor:
                                  isDark ? Colors.black12 : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          //AHORRO MENSUAL
                          const Text(
                            "Ahorro mensual",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: ahorroMensual,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.savings,
                                  color: Color(0xFF064E3B)),
                              hintText: "Opcional",
                              filled: true,
                              fillColor:
                                  isDark ? Colors.black12 : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                          ),

                          const SizedBox(height: 35),

                          //BTN GUARDAR
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF00C853), // verde claro
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () async {
                                if (nombre.text.isEmpty ||
                                    montoMeta.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Completa los campos obligatorios")),
                                  );
                                  return;
                                }

                                final objetivo = _parseAmount(montoMeta.text);
                                if (objetivo <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "El monto objetivo debe ser mayor a 0")),
                                  );
                                  return;
                                }

                                await context.read<AuthProvider>().addMeta(
                                      MetaAhorro(
                                        nombre: nombre.text,
                                        montoMeta: objetivo,
                                        montoActual:
                                            _parseAmount(montoActual.text),
                                        ahorroMensual:
                                            _parseAmount(ahorroMensual.text),
                                      ),
                                    );

                                Navigator.pop(context);
                              },
                              child: const Text(
                                "Guardar meta",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editarMeta(int index) {
    final metas = context.read<AuthProvider>().metas;
    final meta = metas[index];

    TextEditingController nombre = TextEditingController(text: meta.nombre);
    TextEditingController montoMeta =
        TextEditingController(text: meta.montoMeta.toString());
    TextEditingController montoActual =
        TextEditingController(text: meta.montoActual.toString());
    TextEditingController ahorroMensual =
        TextEditingController(text: meta.ahorroMensual.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final objetivoPreview = _parseAmount(montoMeta.text);
            final actualPreview = _parseAmount(montoActual.text);
            final previewProgress = objetivoPreview <= 0
                ? 0.0
                : (actualPreview / objetivoPreview).clamp(0.0, 1.0);

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F2A25) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 20,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF064E3B),
                                  Color(0xFF10B981),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.savings_rounded,
                                        color: Colors.white),
                                    SizedBox(width: 10),
                                    Text(
                                      "Actualizar meta",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                LinearProgressIndicator(
                                  value: previewProgress,
                                  minHeight: 8,
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "${(previewProgress * 100).toStringAsFixed(1)}% completado",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _metaTextField(
                            controller: nombre,
                            label: "Nombre",
                            hint: "Ej: Viaje, Moto, Laptop...",
                            icon: Icons.flag_rounded,
                            isDark: isDark,
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                          const SizedBox(height: 16),
                          _metaTextField(
                            controller: montoMeta,
                            label: "Monto objetivo",
                            hint: "0.00",
                            icon: Icons.track_changes_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                          const SizedBox(height: 16),
                          _metaTextField(
                            controller: montoActual,
                            label: "Monto actual",
                            hint: "0.00",
                            icon: Icons.trending_up_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                          const SizedBox(height: 16),
                          _metaTextField(
                            controller: ahorroMensual,
                            label: "Ahorro mensual",
                            hint: "Opcional",
                            icon: Icons.calendar_month_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final objetivo = _parseAmount(montoMeta.text);
                                if (nombre.text.trim().isEmpty ||
                                    objetivo <= 0) {
                                  _showFloatingMessage(
                                    "Completa nombre y monto objetivo",
                                    isError: true,
                                  );
                                  return;
                                }

                                await context.read<AuthProvider>().editarMeta(
                                      index,
                                      MetaAhorro(
                                        nombre: nombre.text.trim(),
                                        montoMeta: objetivo,
                                        montoActual:
                                            _parseAmount(montoActual.text),
                                        ahorroMensual:
                                            _parseAmount(ahorroMensual.text),
                                      ),
                                    );

                                if (!mounted) return;
                                Navigator.pop(context);
                                _showFloatingMessage("Meta actualizada");
                              },
                              icon: const Icon(Icons.save_rounded),
                              label: const Text(
                                "Guardar cambios",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metaTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[700],
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
            hintText: hint,
            filled: true,
            fillColor: isDark ? const Color(0xFF10231F) : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _eliminarMeta(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar meta"),
        content: const Text("Â¿Seguro?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().eliminarMeta(index);
              Navigator.pop(context);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
