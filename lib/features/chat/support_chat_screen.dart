import 'package:flutter/material.dart';
import '../../core/widgets/app_drawer.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msg = TextEditingController();
  final List<String> _messages = ['Welcome to MaizeMate Support!'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Chat (Mock)')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => Align(
                alignment: i % 2 == 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_messages[i]),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msg, decoration: const InputDecoration(hintText: 'Type a message', contentPadding: EdgeInsets.all(12)))),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _msg.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _messages.add('Support: Thanks for reaching out! (mock)');
      _msg.clear();
    });
  }
}
