import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'property_chat_screen.dart';

class PropertyPastSuggestionsScreen extends StatefulWidget {
  const PropertyPastSuggestionsScreen({super.key});
  @override
  State<PropertyPastSuggestionsScreen> createState() => _PropertyPastSuggestionsScreenState();
}

class _PropertyPastSuggestionsScreenState extends State<PropertyPastSuggestionsScreen> {
  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFF4CAF50);

  // Demo past suggestions — in production load from local DB or backend
  final List<Map<String, dynamic>> _suggestions = [
    {
      'date': 'Oct 2024',
      'location': 'East Austin, TX',
      'initial_roi': 7.5,
      'current_roi': 8.2,
      'status': 'performing',
      'reasoning': ['12% Job Growth (2024)', 'New Tech Hub Completion', 'Infrastructure Upgrades'],
      'rent_growth': [2.1, 2.4, 2.8, 3.1, 3.6, 4.0],
      'price_appreciation': [1.2, 1.8, 2.5, 3.2, 4.1, 5.0],
      'ai_note': 'East Austin is performing ahead of schedule due to the faster than expected tech hub expansion.',
    },
    {
      'date': 'Aug 2024',
      'location': 'South Congress, TX',
      'initial_roi': 6.8,
      'current_roi': 7.1,
      'status': 'on_track',
      'reasoning': ['Tourism Revenue Up 18%', 'New Restaurant District', 'Walkability Score +12'],
      'rent_growth': [1.8, 2.0, 2.3, 2.6, 2.9, 3.2],
      'price_appreciation': [0.9, 1.4, 1.9, 2.5, 3.1, 3.8],
      'ai_note': 'South Congress remains on track with tourism-driven rental demand exceeding projections.',
    },
    {
      'date': 'Jun 2024',
      'location': 'Mueller District, Austin',
      'initial_roi': 6.2,
      'current_roi': 5.9,
      'status': 'below',
      'reasoning': ['Construction Delays', 'Supply Increase', 'Interest Rate Impact'],
      'rent_growth': [1.5, 1.6, 1.4, 1.3, 1.5, 1.7],
      'price_appreciation': [0.8, 0.9, 0.7, 0.8, 1.0, 1.2],
      'ai_note': 'Mueller is slightly below projections due to new supply entering the market. Long-term outlook remains positive.',
    },
  ];

  int _expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _summaryBanner()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _suggestionCard(_suggestions[i], i),
            childCount: _suggestions.length,
          )),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PropertyChatScreen())),
        backgroundColor: _green,
        icon: const Icon(Icons.chat_outlined, color: Colors.white),
        label: const Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16))),
      const SizedBox(width: 10),
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 16)),
      const SizedBox(width: 8),
      const Text('Property Scout AI', style: TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      const Spacer(),
      Icon(Icons.more_vert, color: Colors.white.withOpacity(0.6)),
    ]),
  );

  Widget _summaryBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_green.withOpacity(0.3), const Color(0xFF243040)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _greenLight.withOpacity(0.4))),
      child: Column(children: [
        const Text('Previous Recommendations\nProfitability',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _statBox('${_suggestions.length}', 'Total Picks'),
          _statBox('${_suggestions.where((s) => s['status'] == 'performing').length}', 'Outperforming'),
          _statBox('${(_suggestions.map((s) => s['current_roi'] as double).reduce((a, b) => a + b) / _suggestions.length).toStringAsFixed(1)}%', 'Avg ROI'),
        ]),
      ]),
    ),
  );

  Widget _statBox(String value, String label) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
  ]);

  Widget _suggestionCard(Map<String, dynamic> s, int index) {
    final isExpanded = _expandedIndex == index;
    final isUp = s['current_roi'] >= s['initial_roi'];
    final statusColor = s['status'] == 'performing' ? _greenLight
        : s['status'] == 'on_track' ? Colors.orange.shade300
        : Colors.red.shade300;

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF243040),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isExpanded ? _greenLight.withOpacity(0.5) : _green.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['date'], style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                Text(s['location'], style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  Text('${s['initial_roi']}%', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12,
                      decoration: TextDecoration.lineThrough)),
                  const Text(' → ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text('${s['current_roi']}%', style: TextStyle(
                      color: isUp ? _greenLight : Colors.red.shade300,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                Row(children: [
                  Icon(isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp ? _greenLight : Colors.red.shade300, size: 12),
                  const SizedBox(width: 3),
                  Text(s['status'] == 'performing' ? 'Ahead of schedule'
                      : s['status'] == 'on_track' ? 'On track' : 'Below target',
                      style: TextStyle(color: statusColor, fontSize: 10)),
                ]),
              ]),
              const SizedBox(width: 8),
              Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white38, size: 20),
            ]),
          ),

          // Expanded content
          if (isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Reasoning
                const Text('REASONING', style: TextStyle(
                    color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 10),
                ...(s['reasoning'] as List<String>).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.trending_up, color: Color(0xFF4CAF50), size: 14),
                      const SizedBox(width: 8),
                      Text(r, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]))),
                const SizedBox(height: 16),

                // Rent Growth chart
                _miniChart('Rent Growth', s['rent_growth'] as List, Colors.teal, 'Census Bureau'),
                const SizedBox(height: 16),

                // Price Appreciation chart
                _miniChart('Price Appreciation', s['price_appreciation'] as List, Colors.blue, 'Local Govt.'),
                const SizedBox(height: 16),

                // AI note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _green.withOpacity(0.3))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 28, height: 28,
                        decoration: BoxDecoration(color: _green.withOpacity(0.3), shape: BoxShape.circle),
                        child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s['ai_note'], style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.5))),
                  ]),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _miniChart(String label, List values, Color color, String source) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.account_balance, color: Colors.white38, size: 12),
        const SizedBox(width: 4),
        Text(source, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
      const SizedBox(height: 8),
      SizedBox(height: 60, child: CustomPaint(
          size: const Size(double.infinity, 60),
          painter: _MiniLinePainter(values: values.map((v) => (v as num).toDouble()).toList(), color: color))),
      const SizedBox(height: 4),
      Text('Since original suggestion', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
    ]);
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _MiniLinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs().clamp(0.001, double.infinity);

    double xOf(int i) => i * size.width / (values.length - 1);
    double yOf(double v) => size.height - ((v - minV) / range) * size.height * 0.85 - size.height * 0.05;

    final path = Path()..moveTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < values.length; i++) {
      final x0 = xOf(i-1); final y0 = yOf(values[i-1]);
      final x1 = xOf(i); final y1 = yOf(values[i]);
      path.cubicTo((x0+x1)/2, y0, (x0+x1)/2, y1, x1, y1);
    }
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)]).createShader(Rect.fromLTWH(0,0,size.width,size.height)));
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override bool shouldRepaint(_) => false;
}
