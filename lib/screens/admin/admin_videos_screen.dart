import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/translate_widget.dart';
import '../../utils/snackbar.dart';

const primaryColor = Color.fromARGB(255, 10, 109, 82);

class AdminVideosScreen extends StatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  State<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends State<AdminVideosScreen> {
  List categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final response = await ApiService.getCategories();

      setState(() {
        categories = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void openCreateCategoryDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Nueva categoría",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInput(titleController, "Título"),
            const SizedBox(height: 12),
            _buildInput(descriptionController, "Descripción"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("Guardar"),
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isEmpty || description.isEmpty) {
                _showSnack("Todos los campos son obligatorios");
                return;
              }

              final success = await ApiService.createVideoCategory(
                title,
                description,
              );

              if (success) {
                showSnack(context, "Categoría creada", isSuccess: true);
              } else {
                showSnack(context, "Todos los campos son obligatorios",
                    isError: true);
              }
            },
          ),
        ],
      ),
    );
  }

  void openEditCategoryDialog(Map category) {
    final titleController = TextEditingController(text: category["title"]);
    final descriptionController =
        TextEditingController(text: category["description"]);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Editar categoría"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInput(titleController, "Título"),
            const SizedBox(height: 12),
            _buildInput(descriptionController, "Descripción"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text("Actualizar"),
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isEmpty || description.isEmpty) {
                _showSnack("Todos los campos son obligatorios");
                return;
              }

              final success = await ApiService.updateVideoCategory(
                category["id"],
                title,
                description,
              );

              if (success) {
                showSnack(context, "Categoría actualizada", isSuccess: true);
                loadCategories();
              } else {
                showSnack(context, "Error al actualizar", isError: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSnack(String text) {
    showSnack(context, "Todos los campos son obligatorios", isError: true);
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color.fromARGB(255, 10, 109, 82);
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          "Gestionar videos",
          style: TextStyle(color: primary),
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(
                  child: Text(
                    "No hay categorías",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          title: Text(
                            category["title"] ?? "",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            category["description"] ?? "",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: CircleAvatar(
                              backgroundColor: primary.withOpacity(0.1),
                              child:
                                  Icon(Icons.video_collection, color: primary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: primary),
                                onPressed: () =>
                                    openEditCategoryDialog(category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  final success =
                                      await ApiService.deleteVideoCategory(
                                    category["id"],
                                  );

                                  if (success) {
                                    showSnack(context, "Categoría eliminada",
                                        isSuccess: true);
                                    loadCategories();
                                  } else {
                                    showSnack(context, "Error al eliminar",
                                        isError: true);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        onPressed: openCreateCategoryDialog,
        icon: const Icon(Icons.add),
        label: const Text("Nueva"),
      ),
    );
  }
}
