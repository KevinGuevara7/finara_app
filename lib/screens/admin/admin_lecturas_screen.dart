import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/translate_widget.dart';

const primaryColor = Color.fromARGB(255, 10, 109, 82);

class AdminLecturasScreen extends StatefulWidget {
  const AdminLecturasScreen({super.key});

  @override
  State<AdminLecturasScreen> createState() => _AdminLecturasScreenState();
}

class _AdminLecturasScreenState extends State<AdminLecturasScreen> {
  List lecturas = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLecturas();
  }

  Future<void> loadLecturas() async {
    try {
      final response = await ApiService.getLecturas();

      setState(() {
        lecturas = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void openCreateDialog() {
    final tituloController = TextEditingController();
    final contenidoController = TextEditingController();
    final tiempoController = TextEditingController();

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Crear lectura",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInput(tituloController, "Título"),
                    const SizedBox(height: 12),
                    _buildInput(tiempoController, "Tiempo de lectura"),
                    const SizedBox(height: 12),
                    _buildInput(contenidoController, "Contenido", maxLines: 6),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final titulo = tituloController.text.trim();
                    final contenido = contenidoController.text.trim();
                    final tiempo = tiempoController.text.trim();

                    // 🚨 VALIDACIÓN
                    if (titulo.isEmpty || contenido.isEmpty || tiempo.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Todos los campos son obligatorios"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final success = await ApiService.createLectura(
                      titulo,
                      contenido,
                      tiempo,
                    );

                    if (success) {
                      Navigator.pop(context);
                      loadLecturas();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Lectura creada correctamente"),
                        ),
                      );
                    }
                  },
                  child: const Text("Guardar"),
                ),
              ],
            ));
  }

  void openEditDialog(Map lectura) {
    final tituloController = TextEditingController(
      text: lectura["titulo"],
    );
    final contenidoController = TextEditingController(
      text: lectura["contenido"],
    );
    final tiempoController = TextEditingController(
      text: lectura["tiempo_lectura"],
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar lectura"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(
                  labelText: "Título",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tiempoController,
                decoration: const InputDecoration(
                  labelText: "Tiempo de lectura",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contenidoController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "Contenido",
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final titulo = tituloController.text.trim();
              final contenido = contenidoController.text.trim();
              final tiempo = tiempoController.text.trim();

              if (titulo.isEmpty || contenido.isEmpty || tiempo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Todos los campos son obligatorios"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final success = await ApiService.updateLectura(
                lectura["id"],
                titulo,
                contenido,
                tiempo,
              );

              if (success) {
                Navigator.pop(context);
                loadLecturas();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Lectura actualizada correctamente"),
                  ),
                );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: primaryColor),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 10, 109, 82);
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          "Gestionar lecturas",
          style: TextStyle(color: primaryColor),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : lecturas.isEmpty
              ? const Center(
                  child: Text("No hay lecturas"),
                )
              : ListView.builder(
                  itemCount: lecturas.length,
                  itemBuilder: (context, index) {
                    final lectura = lecturas[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(lectura["titulo"] ?? ""),
                        subtitle: Text(
                          lectura["tiempo_lectura"] ?? "",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: primaryColor),
                              onPressed: () {
                                openEditDialog(lectura);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Eliminar lectura"),
                                    content: const Text(
                                      "¿Seguro que deseas eliminar esta lectura?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancelar"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Eliminar"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final success =
                                      await ApiService.deleteLectura(
                                    lectura["id"],
                                  );

                                  if (success) {
                                    loadLecturas();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Lectura eliminada"),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: openCreateDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
