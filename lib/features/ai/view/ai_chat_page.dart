import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../model/chat_message.dart';
import '../service/ai_service.dart';
import '../../../widgets/custom_bottom_nav.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/note.dart'; 
import '../../../services/notes_services.dart'; 

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final AIService _aiService = AIService();
  bool _isLoading = false;

  // --- VARIABLES DEL CUADERNO ---
  final NoteService _noteService = NoteService();
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();
  
  String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
  final Color primaryGreen = const Color(0xFF10B981);
  final Color accentGreen = const Color(0xFF059669);

  // --- FUNCIÓN PARA GUARDAR (ESTILO MINECRAFT: "FIRMANDO EL LIBRO") ---
  void _guardarNota() async {
    if (_noteTitleController.text.isEmpty && _noteContentController.text.isEmpty) return;
    
    final success = await _noteService.saveNote(
      Note(
        title: _noteTitleController.text.isEmpty ? "Nota sin título" : _noteTitleController.text,
        content: _noteContentController.text,
        categoryName: "Libro Técnico"
      ),
    );

    if (success) {
      _noteTitleController.clear();
      _noteContentController.clear();
      if (!mounted) return;
      Navigator.pop(context); // Cierra el cuaderno al guardar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF5D4037), content: Text("¡Libro firmado y guardado!")),
      );
    }
  }

  // --- MODAL DEL CUADERNO (ESTILO LIBRO ABIERTO) ---
  void _abrirCuaderno() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF4EAD5), // Color papel crema
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 25, right: 25, top: 20
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("NUEVO APUNTE", style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.brown)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.brown)),
              ],
            ),
            const Divider(color: Colors.brown),
            TextField(
              controller: _noteTitleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
              decoration: const InputDecoration(hintText: "Título del Tomo...", border: InputBorder.none),
            ),
            Expanded(
              child: TextField(
                controller: _noteContentController,
                maxLines: null,
                style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF4E342E)),
                decoration: const InputDecoration(hintText: "Escribe tus descubrimientos...", border: InputBorder.none),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton.icon(
                onPressed: _guardarNota,
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("FIRMAR Y GUARDAR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL DE LISTA DE NOTAS (ESTILO XIAOMI NOTES) ---
  void _verMisNotas() {
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
            const Text("MIS APUNTES", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Note>>(
                future: _noteService.fetchNotes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.isEmpty) return const Center(child: Text("El libro está vacío."));
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) {
                      final nota = snapshot.data![i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.book, color: Colors.brown),
                          title: Text(nota.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(nota.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            // Aquí podrías cargar la nota para editarla
                            _noteTitleController.text = nota.title;
                            _noteContentController.text = nota.content;
                            Navigator.pop(context);
                            _abrirCuaderno();
                          },
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

  // --- LÓGICA DE CHAT DAIKO ---
  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? userToken = authProvider.token;
    if (userToken == null) return;

    final userMsg = ChatMessage(text: _controller.text, sender: MessageSender.user, timestamp: DateTime.now());
    setState(() { _messages.insert(0, userMsg); _isLoading = true; });
    _controller.clear();

    try {
      final response = await _aiService.sendMessageToDaiko(
        prompt: userMsg.text, token: userToken, history: _messages, sessionId: _currentSessionId,
      );
      if (!mounted) return;
      setState(() { _messages.insert(0, response); _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      // --- BOTONES LATERALES (XIAOMI STYLE) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón para ver la lista (Xiaomi)
          FloatingActionButton.small(
            onPressed: _verMisNotas,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.list_alt, color: Colors.white),
          ),
          const SizedBox(height: 12),
          // Botón para nueva nota (Minecraft)
          Padding(
            padding: const EdgeInsets.only(bottom: 200), // A la mitad del chat
            child: FloatingActionButton(
              onPressed: _abrirCuaderno,
              backgroundColor: const Color(0xFF5D4037),
              elevation: 10,
              child: const Icon(Icons.edit, color: Color(0xFFF4EAD5)),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text("DAIKO AI", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, isDark);
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Color(0xFF10B981)),
          _buildInputSection(isDark),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(selectedIndex: 2),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    bool isUser = msg.sender == MessageSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueGrey[800] : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(msg.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "Escribe a Daiko..."))),
          const SizedBox(width: 10),
          IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Color(0xFF10B981))),
        ],
      ),
    );
  }
}