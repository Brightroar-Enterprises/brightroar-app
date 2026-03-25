import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'property_chat_screen.dart';
import '../services/api_client.dart';

class PropertyPortfolioScreen extends StatefulWidget {
  const PropertyPortfolioScreen({super.key});
  @override
  State<PropertyPortfolioScreen> createState() =>
      _PropertyPortfolioScreenState();
}

class _PropertyPortfolioScreenState extends State<PropertyPortfolioScreen> {
  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFF4CAF50);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _properties = [];
  List<double> _targetRoi = [8.0, 8.0, 8.0, 8.0, 8.0, 8.0];
  List<double> _actualRoi = [7.2, 7.8, 8.1, 7.9, 8.2, 7.9];
  Map<String, double> _cashFlowByMarket = {};
  double _totalValue = 0;
  double _avgRoi = 0;
  double _totalCashFlow = 0;
  String _analysis = '';

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.getPropertyPortfolio();
      final analysisData = await ApiClient.getPortfolioAnalysis();
      if (!mounted) return;
      final props = (data['properties'] as List? ?? []);
      final trend = data['roi_trend'] as Map? ?? {};
      final cfMarket = (data['cashflow_by_market'] as Map? ?? {});
      setState(() {
        _properties = props.map((p) => Map<String, dynamic>.from(p)).toList();
        _totalValue = (data['total_value'] as num?)?.toDouble() ?? 0;
        _avgRoi = (data['annual_roi'] as num?)?.toDouble() ?? 0;
        _totalCashFlow =
            (data['net_cashflow_monthly'] as num?)?.toDouble() ?? 0;
        _targetRoi =
            (trend['target'] as List? ?? [8.0, 8.0, 8.0, 8.0, 8.0, 8.0])
                .map((v) => (v as num).toDouble())
                .toList();
        _actualRoi =
            (trend['actual'] as List? ?? [7.2, 7.8, 8.1, 7.9, 8.2, 7.9])
                .map((v) => (v as num).toDouble())
                .toList();
        _cashFlowByMarket = cfMarket
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
        _analysis = analysisData['analysis']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : _error != null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.wifi_off,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _loadPortfolio,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D52)),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white))),
                    ]))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _aiPrompt()),
                  SliverToBoxAdapter(child: _portfolioCard()),
                  SliverToBoxAdapter(child: _portfolioList()),
                  SliverToBoxAdapter(child: _visualizations()),
                  SliverToBoxAdapter(child: _aiAnalysis()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PropertyChatScreen())),
        backgroundColor: _green,
        child: const Icon(Icons.chat_outlined, color: Colors.white),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16)),
          ),
          const SizedBox(width: 10),
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.psychology_outlined,
                  color: _greenLight, size: 16)),
          const SizedBox(width: 8),
          const Text('Property Scout AI',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Icon(Icons.more_vert, color: Colors.white.withOpacity(0.6)),
        ]),
      );

  Widget _aiPrompt() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: const Color(0xFF243040),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _green.withOpacity(0.3))),
          child: Row(children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.person_outline,
                    color: _greenLight, size: 16)),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('Analyze my portfolio performance.',
                    style: TextStyle(color: Colors.white, fontSize: 14))),
          ]),
        ),
      );

  Widget _portfolioCard() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          decoration: BoxDecoration(
              color: const Color(0xFF243040),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withOpacity(0.3))),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                const Expanded(
                    child: Text('YOUR REAL ESTATE PORTFOLIO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5))),
                Icon(Icons.settings_outlined,
                    color: Colors.white.withOpacity(0.6), size: 18),
              ]),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _statBox('TOTAL VALUE', '\$${_fmtValue(_totalValue)}',
                    Icons.trending_up, _actualRoi, Colors.teal),
                _divider(),
                _statBox('ANNUAL ROI', '${_avgRoi.toStringAsFixed(1)}%',
                    Icons.check_circle_outline, _actualRoi, _greenLight,
                    subtitle: 'Target 8%'),
                _divider(),
                _statBox(
                    'NET CASH FLOW',
                    '\$${_fmtCash(_totalCashFlow)}/mo',
                    Icons.account_balance_wallet_outlined,
                    _cashFlowByMarket.values.toList(),
                    Colors.blue.shade300),
              ]),
            ),
          ]),
        ),
      );

  Widget _statBox(String label, String value, IconData icon,
      List<double> sparkData, Color color,
      {String? subtitle}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 9,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        if (subtitle != null)
          Text(subtitle, style: TextStyle(color: color, fontSize: 9)),
        const SizedBox(height: 6),
        SizedBox(
            height: 24,
            child: CustomPaint(
                size: const Size(double.infinity, 24),
                painter: _SparklinePainter(values: sparkData, color: color))),
      ]),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 60,
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(horizontal: 10));

  Widget _portfolioList() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            const Text('Portfolio List',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ..._properties.map((p) => _propertyRow(p)),
        ]),
      );

  Widget _propertyRow(Map<String, dynamic> p) {
    final isUp = p['status'] == 'up';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF243040),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        // Icon
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: _green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                p['type'] == 'Multi-Family'
                    ? Icons.apartment_outlined
                    : p['type'] == 'Condo'
                        ? Icons.business_outlined
                        : Icons.home_outlined,
                color: _greenLight,
                size: 22)),
        const SizedBox(width: 12),
        // Details
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p['city'],
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(width: 6),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(p['type'],
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 9))),
          ]),
          const SizedBox(height: 3),
          Text(p['address'],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Row(children: [
            Text('Current ROI ${p['roi']}%',
                style: TextStyle(
                    color: isUp ? _greenLight : Colors.red.shade300,
                    fontSize: 11)),
            const Text('  ·  ', style: TextStyle(color: Colors.white24)),
            Text('Cash Flow \$${_fmtCash((p['cashflow'] as num).toDouble())}',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ])),
        // ROI badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: isUp
                  ? _green.withOpacity(0.2)
                  : Colors.red.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12, color: isUp ? _greenLight : Colors.red.shade300),
            const SizedBox(width: 2),
            Text('${p['roi']}%',
                style: TextStyle(
                    color: isUp ? _greenLight : Colors.red.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _visualizations() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            const Text('Visualizations',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _chartCard(
              'PORTFOLIO ROI TREND',
              Icons.show_chart,
              'Moody\'s Analytics',
              child: SizedBox(
                  height: 70,
                  child: CustomPaint(
                      size: const Size(double.infinity, 70),
                      painter: _DualLinePainter(
                          target: _targetRoi,
                          actual: _actualRoi,
                          targetColor: Colors.white30,
                          actualColor: _greenLight))),
              legend: Row(children: [
                _legendDot(Colors.white30, 'Target'),
                const SizedBox(width: 10),
                _legendDot(_greenLight, 'Actual'),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _chartCard(
              'CASH FLOW BY MARKET',
              Icons.bar_chart,
              'Local Govt.',
              child: SizedBox(
                  height: 70,
                  child: CustomPaint(
                      size: const Size(double.infinity, 70),
                      painter: _BarChartPainter(
                          values: _cashFlowByMarket.values.toList(),
                          labels: _cashFlowByMarket.keys.toList(),
                          color: _greenLight))),
            )),
          ]),
        ]),
      );

  Widget _chartCard(String title, IconData icon, String source,
      {required Widget child, Widget? legend}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF243040),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3))),
          Icon(icon, size: 12, color: Colors.white38),
        ]),
        Row(children: [
          const Spacer(),
          Icon(Icons.public, size: 10, color: Colors.white24),
          const SizedBox(width: 3),
          Text(source,
              style: const TextStyle(color: Colors.white24, fontSize: 9)),
        ]),
        const SizedBox(height: 8),
        child,
        if (legend != null) ...[const SizedBox(height: 6), legend],
      ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 2, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      );

  Widget _aiAnalysis() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF243040),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.psychology_outlined,
                    color: _greenLight, size: 16)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    _analysis.isNotEmpty
                        ? _analysis
                        : 'Your overall portfolio ROI has dipped slightly below your 8% target this month. '
                            "Cash flow remains strong, but let's review your cost-optimization strategies."
                            'Consider expanding into emerging markets matching your criteria.',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.5))),
          ]),
        ),
      );

  String _fmtValue(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _fmtCash(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final max = values.reduce(math.max);
    final min = values.reduce(math.min);
    final range = (max - min).abs().clamp(0.001, double.infinity);
    double x(int i) => i * size.width / (values.length - 1);
    double y(double v) =>
        size.height -
        ((v - min) / range) * size.height * 0.8 -
        size.height * 0.1;
    final path = Path()..moveTo(x(0), y(values[0]));
    for (int i = 1; i < values.length; i++) {
      path.cubicTo((x(i - 1) + x(i)) / 2, y(values[i - 1]),
          (x(i - 1) + x(i)) / 2, y(values[i]), x(i), y(values[i]));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _DualLinePainter extends CustomPainter {
  final List<double> target, actual;
  final Color targetColor, actualColor;
  const _DualLinePainter(
      {required this.target,
      required this.actual,
      required this.targetColor,
      required this.actualColor});

  @override
  void paint(Canvas canvas, Size size) {
    final allVals = [...target, ...actual];
    final max = allVals.reduce(math.max);
    final min = allVals.reduce(math.min);
    final range = (max - min).abs().clamp(0.001, double.infinity);
    double x(int i, int len) => i * size.width / (len - 1);
    double y(double v) =>
        size.height -
        ((v - min) / range) * size.height * 0.8 -
        size.height * 0.1;

    for (final entry in [(target, targetColor), (actual, actualColor)]) {
      final vals = entry.$1;
      final color = entry.$2;
      final path = Path()..moveTo(x(0, vals.length), y(vals[0]));
      for (int i = 1; i < vals.length; i++) {
        path.cubicTo(
            (x(i - 1, vals.length) + x(i, vals.length)) / 2,
            y(vals[i - 1]),
            (x(i - 1, vals.length) + x(i, vals.length)) / 2,
            y(vals[i]),
            x(i, vals.length),
            y(vals[i]));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  const _BarChartPainter(
      {required this.values, required this.labels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.reduce(math.max);
    final barW = size.width / (values.length * 2);
    final textStyle = TextStyle(color: Colors.white38, fontSize: 8);

    for (int i = 0; i < values.length; i++) {
      final x = i * (size.width / values.length) + barW / 2;
      final barH = (values[i] / max) * (size.height - 16);
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 16 - barH, barW, barH),
          const Radius.circular(3));
      canvas.drawRRect(rect, Paint()..color = color.withOpacity(0.8));

      // Label
      final tp = TextPainter(
          text: TextSpan(text: labels[i], style: textStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x - tp.width / 2 + barW / 2, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
