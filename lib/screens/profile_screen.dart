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

    // Quita cualquier cosa que no sea número
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Convierte a número y formatea (ejemplo: 1000 -> 1.000)
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
  // Comparamos la descripción para asignar icono y color
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

  @override
  void initState() {
    super.initState();
    loadUser();
    _loadData();
  }

  Future<void> loadTransactions() async {
    final auth = context.read<AuthProvider>();

    final data = await ApiService.getTransactions(auth.token!);

    if (!mounted) return;

    setState(() {
      transactions = data.map((e) => TransactionModel.fromMap(e)).toList();
    });
  }

  void loadUser() async {
    try {
      final auth = context.read<AuthProvider>();
      final data = await auth.getUserData();
      print(data);

      setState(() {
        if (data != null) {
          name = data["name"] ?? "Sin nombre";
          email = data["email"] ?? "Sin email";
        } else {
          name = "No se pudo cargar";
          email = "";
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
    await loadCategories();
    await loadTransactions();
  }

  Future<void> loadCategories() async {
    final auth = context.read<AuthProvider>();
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF064E3B);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // APPBAR
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(4)),
              child: Icon(Icons.account_circle_rounded,
                  color: Colors.white, size: 18),
            ),
            SizedBox(width: 8),
            Text("Profile",
                style: TextStyle(
                    color: Color.fromARGB(255, 10, 109, 82),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
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
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    // El '!' después de profileImageUrl solo se pone si ya comprobaste que no es nulo
                    backgroundImage:
                        (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                            ? NetworkImage(profileImageUrl!)
                            : null,
                    child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                        ? const Icon(Icons.person,
                            size: 40, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage(), // Función para la galería
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C853),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
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
                    child: Text("CONFIGURACIÓN",
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

            // BOTÓN DE CERRAR SESIÓN
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.red.withOpacity(0.1),
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const TranslatedText("Cerrar sesión",
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
        child: Column(
          children: [
            //PERFIL
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor,
                  child:
                      const Icon(Icons.person, size: 30, color: Colors.white),
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

            //TARJETA DE BALANCE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                //light/dark
                color:
                    isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Balance Total",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF1B4332),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "\$${getBalance().toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B4332),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            //TÍTULO Y BOTÓN AGREGAR
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
            Expanded(
              child: ListView.separated(
                itemCount: transactions.length,
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
                        //ICON SEGÚN LA IMAGEN
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

                        //DESCRIPCIÓN Y FECHA
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
                              "${isIngreso ? '+' : '-'} \$${t.amount.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: isIngreso ? Colors.green : Colors.red,
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
            ),
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
                  // 🔹 BARRA SUPERIOR (Indicador de arrastre)
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
                          // TÍTULO
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

                          // SELECTOR CATEGORÍA
                          const TranslatedText("Categoría",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 10),

// 1. Botón para crear nueva
                          // 1. Botón para crear nueva
                          TextButton(
                            onPressed: () async {
                              String? nueva =
                                  await _mostrarDialogoNuevaCategoria();

                              if (nueva != null && nueva.isNotEmpty) {
                                // Validación local: Usamos ignoreCase para mayor seguridad
                                if (localCategories.any((c) =>
                                    c.name.toLowerCase() ==
                                    nueva.toLowerCase())) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Esa categoría ya existe")),
                                  );
                                  return;
                                }

                                final auth = context.read<AuthProvider>();
                                // Asumimos que la API devuelve el objeto creado o al menos confirma el éxito
                                bool success = await ApiService.createCategory(
                                    auth.token!, nueva, type);

                                if (success) {
                                  await loadCategories(); // Recarga la lista global 'categories'

                                  setStateDialog(() {
                                    // ACTUALIZACIÓN CRÍTICA:
                                    // 1. Sincronizamos la lista local con la global recién cargada
                                    localCategories = List.from(categories);

                                    // 2. Filtramos inmediatamente para que el Dropdown vea el cambio
                                    final filtered = localCategories
                                        .where((c) => c.type == type)
                                        .toList();

                                    if (filtered.isNotEmpty) {
                                      // 3. Intentamos encontrar la que acabamos de crear por nombre
                                      // (Es más seguro que .last si la lista viene ordenada del servidor)
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
                            child: const Text("Agregar categoría",
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
                                    // IMPORTANTE: Asegúrate de que filteredCategories se re-calcule
                                    // antes de este punto en el build del diálogo.
                                    items: localCategories
                                        .where((c) =>
                                            c.type ==
                                            type) // Filtramos aquí directamente para evitar desfases
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
                                // BOTÓN EDITAR
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
                                      }
                                    }
                                  },
                                ),
                                // BOTÓN ELIMINAR
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () async {
                                    bool? confirmar = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title:
                                            const Text("¿Eliminar categoría?"),
                                        content: const Text(
                                            "Esta acción no se puede deshacer."),
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
                                              null; // Reset de selección
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Categoría eliminada con éxito")),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Error al eliminar la categoría")),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 25),

                          // --- AQUÍ REGRESA LA FECHA ---
                          const TranslatedText("Fecha",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: edit != null
                                    ? DateFormat("MM/dd/yyyy")
                                        .parse(dateController.text)
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

                          // --- AQUÍ REGRESA LA DESCRIPCIÓN (NOTAS) ---
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
                          // BOTÓN GUARDAR

                          // ... (SizedBox después del TextField de Notas)
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
                                      // 1. Validar que el monto no esté vacío o sea 0
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
                                                  "Selecciona una categoría")),
                                        );
                                        return;
                                      }

                                      int categoryId = selectedCategoryId!;

                                      if (montoFinal <= 0) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: TranslatedText(
                                                  "Por favor ingresa un monto válido")),
                                        );
                                        return;
                                      }

                                      if (desc.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: TranslatedText(
                                                  "Por favor ingresa una descripción")),
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
                                      } else {
                                        // ES EDICIÓN
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
                                                  ? "Creado con éxito"
                                                  : "Actualizado con éxito")),
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
              title: const TranslatedText("Confirmar"),
              content: Text("¿Eliminar '${t.description}'?"),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context),
                  child: const TranslatedText("Cancelar"),
                ),
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setStateDialog(() => isDeleting = true);

                          final auth = context.read<AuthProvider>();

                          final success = await ApiService.deleteTransaction(
                            auth.token!,
                            t.id!,
                          );

                          if (!mounted) return;

                          Navigator.pop(context);

                          if (success) {
                            loadTransactions();
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const TranslatedText(
                          "Eliminar",
                          style: TextStyle(color: Colors.red),
                        ),
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
        title: const TranslatedText("Nueva categoría"),
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

  // Constructor de items para el menú
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

// El Modal de Idioma que ya tenías, pero llamado desde afuera
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var request = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://finara-app.onrender.com/users/upload-profile-picture'));

      // Si manejas tokens de seguridad, no olvides agregarlo:
      // request.headers['Authorization'] = 'Bearer $tuToken';

      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: image.name));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath('file', image.path));
      }

      // --- EL CAMBIO ESTÁ AQUÍ ---
      try {
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          setState(() {
            // 'url' es el nombre que configuramos en el backend de FastAPI
            // Agregamos un timestamp (?v=...) para evitar que el caché de Flutter ignore el cambio
            profileImageUrl =
                "${data['url']}?v=${DateTime.now().millisecondsSinceEpoch}";
          });

          print("¡Imagen subida y actualizada!");
        } else {
          print("Error en el servidor: ${response.statusCode}");
        }
      } catch (e) {
        print("Error de red: $e");
      }
    } else {
      print("No se seleccionó ninguna imagen.");
    }
  }
}
