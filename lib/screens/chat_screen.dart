import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List messages = [];

  @override
  void initState() {
    super.initState();

    loadMessages();

    //auto refresco
    Future.delayed(Duration.zero, () {
      startAutoRefresh();
    });
  }

  late final periodicRefresh;

  void startAutoRefresh() {
    periodicRefresh = Stream.periodic(const Duration(seconds: 3)).listen((_) {
      loadMessages();
    });
  }

  @override
  void dispose() {
    periodicRefresh.cancel();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Widget buildMessageBubble(msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final raw = msg["timestamp"];
    final date = raw != null
        ? DateTime.parse(raw.replaceFirst(" ", "T") + "Z").toLocal()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 12,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.green.shade600
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            msg["content"],
            style: TextStyle(
              color: isMe
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),

          //TIMESTAMP+VISTO
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTimestamp(date),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
              if (isMe) const SizedBox(width: 5),

              //CHECKS
              if (isMe)
                Icon(
                  msg["is_read"] == true ? Icons.done_all : Icons.done,
                  size: 14,
                  color: msg["is_read"] == true
                      ? Colors.blueAccent
                      : Colors.white70,
                ),
            ],
          ),
        ],
      ),
    );
  }

  final scrollController = ScrollController();
  final controller = TextEditingController();
  String formatTimestamp(DateTime? date) {
    if (date == null) return "";

    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return "Hoy ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return "Ayer ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> loadMessages() async {
    final auth = context.read<AuthProvider>();
    final data = await ApiService.getMessages(auth.token!, widget.userId);

    setState(() {
      messages = data.reversed.toList();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade600,
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.userName),
          ],
        ),
      ),
      body: Column(
        children: [
          //MNSJ
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isMe = msg["sender_id"] != widget.userId;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: buildMessageBubble(msg, isMe),
                  ),
                );
              },
            ),
          ),

          //INPUT
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                  )
                ],
              ),
              child: Row(
                children: [
                  //TXTFIELD
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: "Escribe un mensaje...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  //BTN ENVIAR
                  GestureDetector(
                    onTap: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;

                      controller.clear(); // limpiar primero UX

                      await ApiService.sendMessage(
                        auth.token!,
                        widget.userId,
                        text,
                      );

                      loadMessages();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
