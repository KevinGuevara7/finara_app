// INICIO DE IMPORTACIONES
import 'package:flutter/material.dart';
import '../model/chat_message.dart';
import '../service/ai_service.dart';
import '../../../widgets/custom_bottom_nav.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/note.dart'; 
import '../../../services/notes_services.dart'; 
// FIN DE IMPORTACIONES

// INICIO DE DEFINICIÓN DEL WIDGET PRINCIPAL
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}
// FIN DE DEFINICIÓN DEL WIDGET PRINCIPAL

// INICIO DEL ESTADO DEL WIDGET (LÓGICA Y UI)
class _AIChatPageState extends State<AIChatPage> {
  
  // INICIO DE VARIABLES DE ESTADO Y CONTROLADORES
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final AIService _aiService = AIService();
  final NoteService _noteService = NoteService();
  
  bool _isLoading = false;
  String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // Herramienta seleccionada para el selector de la UI
  String _selectedTool = "Rápido";

  // Controladores para el Libro/Notas
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();
  int? _editingNoteId; 

  final Color primaryGreen = const Color(0xFF10B981);
  final Color accentGreen = const Color(0xFF059669);
  final Color bookColor = const Color(0xFFF4EAD5);
  // FIN DE VARIABLES DE ESTADO Y CONTROLADORES

  // INICIO DE LÓGICA DE NOTAS (LISTADO Y CRUD)
  
  // INTERFAZ: LISTADO DE NOTAS (ESTILO XIAOMI)
  void _verListadoNotas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("MIS APUNTES TÉCNICOS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Note>>(
                future: _noteService.fetchNotes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final notas = snapshot.data!;
                  if (notas.isEmpty) return const Center(child: Text("El libro está en blanco."));
                  
                  return ListView.builder(
                    itemCount: notas.length,
                    itemBuilder: (context, i) {
                      final nota = notas[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.menu_book, color: Colors.brown),
                          title: Text(nota.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(nota.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _confirmarEliminar(nota.id!),
                          ),
                          onTap: () => _abrirEditorNota(nota),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // EDITOR DE NOTAS (CRUD: CREAR/EDITAR)
  void _abrirEditorNota([Note? nota]) {
    if (nota != null) {
      _editingNoteId = nota.id;
      _noteTitleController.text = nota.title;
      _noteContentController.text = nota.content;
    } else {
      _editingNoteId = null;
      _noteTitleController.clear();
      _noteContentController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(color: bookColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_editingNoteId == null ? "NUEVO APUNTE" : "EDITANDO LIBRO", 
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.brown)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            TextField(
              controller: _noteTitleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
              decoration: const InputDecoration(hintText: "Título...", border: InputBorder.none),
            ),
            Expanded(
              child: TextField(
                controller: _noteContentController,
                maxLines: null,
                style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF4E342E)),
                decoration: const InputDecoration(hintText: "Escribe aquí...", border: InputBorder.none),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: _guardarCambiosNota,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), minimumSize: const Size(double.infinity, 50)),
                child: const Text("FIRMAR Y GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DE GUARDADO MEJORADA ---
  void _guardarCambiosNota() async {
    print("💾 --- INICIANDO PROCESO DE GUARDADO ---");
    
    final success = await _noteService.saveNote(
      Note(
        id: _editingNoteId, 
        title: _noteTitleController.text, 
        content: _noteContentController.text,
        categoryName: "General"
      ),
    );
    
    print("📡 RESPUESTA DEL SERVIDOR (GUARDAR): $success");

    if (!mounted) return;

    if (success) {
      print("✅ ¡Nota guardada exitosamente!");
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cambios guardados con éxito"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      setState(() {});
    } else {
      print("❌ ERROR: El servidor no pudo procesar el guardado.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al guardar: Revisa la consola para más detalles"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- LÓGICA DE ELIMINACIÓN MEJORADA ---
  void _confirmarEliminar(int id) async {
    print("🕵️‍♂️ --- INTENTANDO ELIMINAR APUNTE ID: $id ---");
    
    final success = await _noteService.deleteNote(id);
    
    print("📡 RESPUESTA DEL SERVIDOR (ELIMINAR): $success");

    if (!mounted) return;

    if (success) {
      print("✅ ¡Apunte eliminado con éxito!");
      setState(() {});
      Navigator.pop(context); 
      _verListadoNotas(); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Apunte eliminado correctamente"), 
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      print("❌ ERROR: Falló la eliminación.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al eliminar el apunte"), 
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
  // FIN DE LÓGICA DE NOTAS

  // INICIO DE LÓGICA DE CHAT E HISTORIAL
  void _sendMessage() async {
    if (_chatController.text.isEmpty) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userMsg = ChatMessage(text: _chatController.text, sender: MessageSender.user, timestamp: DateTime.now());
    setState(() { _messages.insert(0, userMsg); _isLoading = true; });
    _chatController.clear();
    final response = await _aiService.sendMessageToDaiko(
      prompt: userMsg.text, token: authProvider.token!, history: _messages, sessionId: _currentSessionId,
    );
    setState(() { _messages.insert(0, response); _isLoading = false; });
  }
  // FIN DE LÓGICA DE CHAT E HISTORIAL

  // INICIO DE COMPONENTES AUXILIARES DE UI (DRAWER ITEMS)
  Widget _buildToolItem(String title, String desc, IconData icon, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? primaryGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? primaryGreen : Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isActive ? primaryGreen : Colors.grey))),
          if (isActive) Icon(Icons.check_circle, color: primaryGreen, size: 14),
        ],
      ),
    );
  }
  // FIN DE COMPONENTES AUXILIARES DE UI

  // INICIO DEL MÉTODO BUILD (CONSTRUCCIÓN PRINCIPAL DE LA PANTALLA)
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "btnList",
            onPressed: _verListadoNotas,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.list_alt, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 220), 
            child: FloatingActionButton(
              heroTag: "btnEdit",
              onPressed: () => _abrirEditorNota(),
              backgroundColor: const Color(0xFF5D4037),
              child: const Icon(Icons.edit, color: Color(0xFFF4EAD5)),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryGreen, accentGreen])),
              child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 40)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("HISTORIAL RECIENTE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _aiService.getSessions(authProvider.token!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(
                        "Sesión ${snapshot.data![i]['session_id'].toString().substring(0,6)}",
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        setState(() {
                          _messages.clear();
                          _currentSessionId = snapshot.data![i]['session_id'];
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text("DAIKO AI", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Expanded(child: ListView.builder(reverse: true, padding: const EdgeInsets.all(20), itemCount: _messages.length, itemBuilder: (context, i) => _buildBubble(_messages[i], isDark))),
          if (_isLoading) LinearProgressIndicator(color: primaryGreen),
          _buildInputSection(isDark),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(selectedIndex: 2),
    );
  }
  // FIN DEL MÉTODO BUILD

  // INICIO DE COMPONENTES DE UI DEL CHAT (BURBUJAS Y CAJA DE TEXTO)
  Widget _buildBubble(ChatMessage msg, bool isDark) {
    bool isUser = msg.sender == MessageSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueGrey[800] : const Color(0xFFECFDF5), 
          borderRadius: BorderRadius.circular(15)
        ),
        child: Text(msg.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              _buildToolSelector(isDark),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: "Escribe a Daiko...",
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: primaryGreen,
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolSelector(bool isDark) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(_selectedTool, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
      onSelected: (String value) {
        setState(() {
          _selectedTool = value; 
        });
      },
      itemBuilder: (BuildContext context) => [
        _buildPopupItem("Rápido", "Responde rápidamente", Icons.bolt, _selectedTool == "Rápido", isDark),
        _buildPopupItem("Pensar", "Resuelve problemas complejos", Icons.psychology, _selectedTool == "Pensar", isDark),
        _buildPopupItem("Bolsa", "Análisis de mercado avanzado", Icons.trending_up, _selectedTool == "Bolsa", isDark),
        _buildPopupItem("Gastos", "Gestión financiera detallada", Icons.account_balance_wallet, _selectedTool == "Gastos", isDark),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String title, String subtitle, IconData icon, bool isSelected, bool isDark) {
    return PopupMenuItem<String>(
      value: title,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isSelected ? primaryGreen : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (isSelected) Icon(Icons.check_circle, size: 18, color: primaryGreen),
        ],
      ),
    );
  }
}