import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PropertyChatScreen extends StatefulWidget {
  const PropertyChatScreen({super.key});
  @override
  State<PropertyChatScreen> createState() => _PropertyChatScreenState();
}

class _PropertyChatScreenState extends State<PropertyChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = false;

  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFF4CAF50);

  // Replace with your Anthropic API key or use your backend
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'text': 'Hello! I\'m your Property Scout AI. I can help you:\n\n'
          '• Find the best investment locations\n'
          '• Analyze ROI and market trends\n'
          '• Track your past recommendations\n'
          '• Answer real estate questions\n\n'
          'What would you like to know?',
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': 'YOUR_ANTHROPIC_API_KEY',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 1024,
          'system': 'You are a Property Scout AI assistant specializing in real estate investment. '
              'Help users find the best investment locations, analyze ROI, market trends, crime rates, '
              'school ratings, and rental demand. Be concise, data-driven, and actionable. '
              'When mentioning specific locations, include estimated ROI ranges.',
          'messages': _messages
              .where((m) => m['role'] != 'assistant' || _messages.indexOf(m) > 0)
              .map((m) => {'role': m['role'], 'content': m['text']})
              .toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['content'][0]['text'] ?? 'Sorry, I could not generate a response.';
        setState(() { _messages.add({'role': 'assistant', 'text': reply}); _loading = false; });
      } else {
        // Fallback demo response
        setState(() {
          _messages.add({'role': 'assistant', 'text': _demoResponse(text)});
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': _demoResponse(text)});
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  String _demoResponse(String query) {
    if (query.toLowerCase().contains('austin')) {
      return 'Austin, TX remains one of the top investment markets in 2024:\n\n'
          '• **East Austin**: ROI 7.8%, Crime: Very Low, Schools: 8/10\n'
          '• **South Congress**: ROI 7.2%, Crime: Low, Schools: 7/10\n'
          '• **Mueller District**: ROI 6.5%, Crime: Very Low, Schools: 9/10\n\n'
          'Key drivers: Tech sector growth, population influx, limited housing supply.\n\n'
          'Recommended property type: Multi-family for best ROI.';
    }
    if (query.toLowerCase().contains('roi') || query.toLowerCase().contains('return')) {
      return 'For optimal ROI in current market conditions:\n\n'
          '1. **Target 6-8% cap rate** for stable markets\n'
          '2. **Look for 9-11%** in emerging neighborhoods\n'
          '3. **Avoid <5%** unless in premium locations\n\n'
          'Top ROI markets right now:\n'
          '• Austin, TX: 7-9%\n'
          '• Phoenix, AZ: 6-8%\n'
          '• Nashville, TN: 7-9%\n'
          '• Tampa, FL: 8-10%';
    }
    return 'Based on current market data, I recommend focusing on emerging neighborhoods '
        'with strong job growth, good school ratings, and low crime rates. '
        'Would you like me to analyze a specific city or neighborhood for you?';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: Column(children: [
        _header(),
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _messages.length + (_loading ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == _messages.length) return _typingIndicator();
            final msg = _messages[i];
            return _messageBubble(msg['role'] == 'assistant', msg['text']);
          },
        )),
        _inputBar(),
      ]),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
    color: const Color(0xFF1A2332),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16))),
      const SizedBox(width: 10),
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle,
              border: Border.all(color: _greenLight.withOpacity(0.4))),
          child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 16)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Property Scout AI', style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        Row(children: [
          Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          const Text('Online', style: TextStyle(color: _greenLight, fontSize: 11)),
        ]),
      ]),
      const Spacer(),
      Icon(Icons.more_vert, color: Colors.white.withOpacity(0.6)),
    ]),
  );

  Widget _messageBubble(bool isAI, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isAI) ...[
          Container(width: 28, height: 28,
              decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 14)),
          const SizedBox(width: 10),
        ],
        Flexible(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: isAI ? const Color(0xFF243040) : _green.withOpacity(0.8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isAI ? 4 : 16),
                topRight: Radius.circular(isAI ? 16 : 4),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              border: isAI ? Border.all(color: _green.withOpacity(0.3)) : null),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
        )),
        if (!isAI) const SizedBox(width: 38),
      ]),
    );
  }

  Widget _typingIndicator() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(width: 28, height: 28,
          decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 14)),
      const SizedBox(width: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF243040), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withOpacity(0.3))),
          child: Row(children: List.generate(3, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6, height: 6,
              decoration: BoxDecoration(color: _greenLight.withOpacity(0.6), shape: BoxShape.circle))))),
    ]),
  );

  Widget _inputBar() => Container(
    color: const Color(0xFF1A2332),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF243040),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _green.withOpacity(0.3))),
        child: TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
              hintText: 'Type Message...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
          onSubmitted: (_) => _sendMessage(),
        ),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _sendMessage,
        child: Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
            child: _loading
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
      ),
    ]),
  );
}
