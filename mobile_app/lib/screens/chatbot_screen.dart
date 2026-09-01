import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

import '../config.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Yo! I'm Aura. I see you hit your water goal today. How can we level up your skin routine tonight?",
      isUser: false,
    ),
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chatbot'),
        headers: {'Bypass-Tunnel-Reminder': 'true', 'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(ChatMessage(text: data['reply'], isUser: false));
        });
      } else {
        _addSmartFallbackReply(text);
      }
    } catch (e) {
      _addSmartFallbackReply(text);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _addSmartFallbackReply(String query) {
    final q = query.toLowerCase();
    String reply;
    if (q.contains('acne') || q.contains('pimple') || q.contains('breakout')) {
      reply = "For active breakouts, pair a 2% Salicylic Acid cleanser with a lightweight Oil-Free Niacinamide moisturizer. Avoid popping blemishes to protect your skin barrier!";
    } else if (q.contains('glow') || q.contains('bright') || q.contains('dark spot') || q.contains('hyper')) {
      reply = "To boost natural skin glow and fade hyperpigmentation, apply Vitamin C serum every morning under SPF 50, and use Glycolic Acid 2-3 nights a week!";
    } else if (q.contains('dry') || q.contains('flaky') || q.contains('moistur')) {
      reply = "For dry or compromised skin, layer Hyaluronic Acid on damp skin, followed by a Ceramide barrier cream. Avoid harsh physical scrubs!";
    } else if (q.contains('routine') || q.contains('start') || q.contains('daily')) {
      reply = "The essential 3-step routine:\n1. Gentle Hydrating Cleanser\n2. Barrier Cream / Niacinamide Moisturizer\n3. Broad-Spectrum SPF 50 Sunscreen";
    } else {
      reply = "I'm fully locked in to help you level up your routine! For optimal skin health, cleanse daily with lukewarm water, hydrate with Ceramides, and never skip broad-spectrum SPF 50!";
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Aura Expert", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white10, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _ChatBubble(message: msg);
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/lottie/mascot_meditate.json',
                      height: 28,
                      errorBuilder: (c, e, s) => Lottie.network(
                        'https://assets9.lottiefiles.com/packages/lf20_q7uarxsb.json',
                        height: 28,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(color: Color(0xFF00FFCC), strokeWidth: 2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("Aura is typing...", style: TextStyle(color: Color(0xFF00FFCC), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ask about your routine...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF121212),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF00FFCC), Color(0xFFB300FF)]),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 24),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.5)),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF00FFCC), size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF00FFCC).withOpacity(0.15) : const Color(0xFF121212),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 20),
                ),
                border: Border.all(
                  color: isUser ? const Color(0xFF00FFCC).withOpacity(0.5) : Colors.white10,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? const Color(0xFF00FFCC) : Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 44),
        ],
      ),
    );
  }
}
