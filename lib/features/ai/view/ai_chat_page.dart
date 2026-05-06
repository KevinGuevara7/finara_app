import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import '../model/chat_message.dart';
import '../service/ai_service.dart';
import '../../../widgets/custom_bottom_nav.dart';
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

  // --- SERVICIOS Y CONTROLADORES DE NOTAS ---
  final NoteService _noteService = NoteService();
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();

  String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();

  final Color primaryGreen = const Color(0xFF10B981);
  final Color accentGreen = const Color(0xFF059669);

  // --- LÓGICA DEL CUADERNO ---
  void _mostrarCuaderno() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("MI LIBRO DE NOTAS", 
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2, color: primaryGreen)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            TextField(
              controller: _noteTitleController,
              decoration: const InputDecoration(hintText: "Título del tema...", border: InputBorder.none),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Expanded(
              child: TextField(
                controller: _noteContentController,
                maxLines: null,
                decoration: const InputDecoration(hintText: "Escribe tus apuntes aquí...", border: InputBorder.none),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _guardarEnCuaderno,
                child: const Text("GUARDAR EN CUADERNO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _guardarEnCuaderno() async {
    if (_noteTitleController.text.isEmpty || _noteContentController.text.isEmpty) return;
    final success = await _noteService.saveNote(
      Note(
        title: _noteTitleController.text,
        content: _noteContentController.text,
        categoryName: "Libro / AI"
      ),
    );
    if (success) {
      _noteTitleController.clear();
      _noteContentController.clear();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: primaryGreen, content: const Text("Apunte guardado con éxito")),
      );
    }
  }

  // --- LÓGICA DE CHAT ---
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
        prompt: userMsg.text,
        token: userToken,
        history: _messages,
        sessionId: _currentSessionId,
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
    final authProvider = Provider.of<AuthProvider>(context);
    final String userToken = authProvider.token ?? "";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: _buildAppBar(isDark),
      drawer: _buildDrawer(isDark, userToken),
      
      // --- BOTÓN FLOTANTE LATERAL (ESTILO PESTAÑA) ---
      floatingActionButton: Stack(
        children: [
          Positioned(
            right: -5, // Ligeramente pegado al borde
            top: MediaQuery.of(context).size.height * 0.4, // Centro-derecha
            child: GestureDetector(
              onTap: _mostrarCuaderno,
              child: Container(
                width: 55, height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20), 
                    bottomLeft: Radius.circular(20)
                  ),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(-2, 4))],
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFFF4EAD5), size: 30),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg, isDark, index == 0);
              },
            ),
          ),
          if (_isLoading) LinearProgressIndicator(color: primaryGreen, backgroundColor: Colors.transparent),
          _buildInputSection(isDark),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(selectedIndex: 2),
    );
  }

  // --- WIDGETS DE INTERFAZ ---
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      iconTheme: IconThemeData(color: primaryGreen),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DAIKO AI", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF065F46))),
          Text("ACTIVE INTELLIGENCE", style: TextStyle(color: primaryGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isDark, bool isLast) {
    bool isUser = msg.sender == MessageSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser 
            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)) 
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5)),
          borderRadius: BorderRadius.circular(20),
          border: isUser ? null : Border.all(color: primaryGreen.withOpacity(0.1)),
        ),
        child: !isUser && isLast
          ? AnimatedTextKit(
              animatedTexts: [TypewriterAnimatedText(msg.text, speed: const Duration(milliseconds: 20))],
              totalRepeatCount: 1,
              displayFullTextOnTap: true,
            )
          : Text(msg.text, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Pregunta a Daiko...",
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: primaryGreen,
            radius: 25,
            child: IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Colors.white, size: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark, String token) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryGreen, accentGreen])),
            child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 50)),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text("Nueva Sesión"),
            onTap: () {
              setState(() { _messages.clear(); _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString(); });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}