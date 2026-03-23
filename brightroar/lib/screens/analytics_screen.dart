import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';
import 'dart:math' as math;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Shared period drives BOTH the performance chart AND Binance PnL
  String _period = '1m';

  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _performance;
  Map<String, dynamic>? _profit;
  Map<String, dynamic>? _pnl;

  bool _loading = true;
  bool _pnlLoading = true;
  String? _error;
  int? _hoveredIndex;

  static const _periods = ['1D', '1W', '1M', '3M', 'YTD', 'ALL'];
  static const _periodValues = {
    '1D': '1d',
    '1W': '1w',
    '1M': '1m',
    '3M': '3m',
    'YTD': 'ytd',
    'ALL': 'all'
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _pnlLoading = true;
      _error = null;
      _hoveredIndex = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.getPortfolioOverview(),
        ApiClient.getPerformance(period: _period),
        ApiClient.getProfitHistory(),
      ]);
      setState(() {
        _portfolio = results[0] as Map<String, dynamic>;
        _performance = results[1] as Map<String, dynamic>;
        _profit = results[2] as Map<String, dynamic>;
        _loading = false;
      });
      _loadPnl();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _pnlLoading = false;
      });
    }
  }

  Future<void> _loadPnl() async {
    setState(() {
      _pnlLoading = true;
      _pnl = null;
    });
    try {
      final pnl = await ApiClient.getBinancePnl(period: _period);
      setState(() {
        _pnl = pnl;
        _pnlLoading = false;
      });
    } catch (_) {
      setState(() {
        _pnl = null;
        _pnlLoading = false;
      });
    }
  }

  void _selectPeriod(String label) {
    final val = _periodValues[label]!;
    if (val == _period) return;
    setState(() => _period = val);
    _loadAll();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double _d(dynamic v) {
    try {
      return double.parse(v.toString());
    } catch (_) {
      return 0.0;
    }
  }

  String _fmt(dynamic v) {
    final n = _d(v);
    if (n.abs() >= 1e9) return '\$${(n / 1e9).toStringAsFixed(2)}B';
    if (n.abs() >= 1e6) return '\$${(n / 1e6).toStringAsFixed(2)}M';
    if (n.abs() >= 1e3) return '\$${(n / 1e3).toStringAsFixed(2)}K';
    return '\$${n.toStringAsFixed(2)}';
  }

  String _pct(dynamic v) {
    final n = _d(v);
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(2)}%';
  }

  Color _col(dynamic v) => _d(v) >= 0 ? AppTheme.positive : AppTheme.negative;

  String get _periodLabel {
    switch (_period) {
      case '1d':
        return 'Today';
      case '1w':
        return 'Past 7 days';
      case '1m':
        return 'Past 30 days';
      case '3m':
        return 'Past 90 days';
      case 'ytd':
        return 'Year to date';
      default:
        return 'All time';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppTheme.primary,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _header()),
          if (_loading)
            const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_error != null)
            SliverFillRemaining(
                child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                  const Icon(Icons.wifi_off,
                      color: AppTheme.textTertiary, size: 48),
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: _loadAll,
                      child: const Text('Retry',
                          style: TextStyle(color: AppTheme.background))),
                ])))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                  delegate: SliverChildListDelegate([
                // ── One selector controls everything ──────────────────────────
                _periodSelector(),
                const SizedBox(height: 20),
                // ── Overall Binance PnL hero ───────────────────────────────────
                _overallPnlHero(),
                const SizedBox(height: 12),
                // ── 3 breakdown chips ──────────────────────────────────────────
                _pnlBreakdownRow(),
                const SizedBox(height: 20),
                // ── Wallet portfolio value + line chart ────────────────────────
                _portfolioCard(),
                const SizedBox(height: 20),
                _metricsRow(),
                const SizedBox(height: 20),
                // ── Spot / futures detail cards ────────────────────────────────
                if (_pnl != null) ...[
                  _spotPnlCard(),
                  const SizedBox(height: 12),
                  _futuresUnrealizedCard(),
                  const SizedBox(height: 12),
                  _futuresRealizedCard(),
                  const SizedBox(height: 20),
                ],
                _profitHistoryCard(),
                const SizedBox(height: 20),
                _allocationRow(),
                const SizedBox(height: 20),
              ])),
            ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
        child: Row(children: [
          const Text('Analytics',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFF0B90B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFF0B90B).withOpacity(0.3))),
            child: Row(children: const [
              Icon(Icons.circle, color: Color(0xFFF0B90B), size: 6),
              SizedBox(width: 5),
              Text('Binance Live',
                  style: TextStyle(
                      color: Color(0xFFF0B90B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  // ── Unified period selector ────────────────────────────────────────────────
  Widget _periodSelector() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Row(
            children: _periods.map((label) {
          final active = _periodValues[label] == _period;
          return Expanded(
              child: GestureDetector(
            onTap: () => _selectPeriod(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: active ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9)),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color:
                          active ? AppTheme.background : AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ),
          ));
        }).toList()),
      );

  // ── Overall Binance PnL hero card ──────────────────────────────────────────
  Widget _overallPnlHero() {
    if (_pnlLoading) {
      return GlassCard(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
            child: Column(children: [
          const CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2),
          const SizedBox(height: 12),
          Text('Loading PnL · $_periodLabel',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ])),
      ));
    }

    if (_pnl == null) {
      return GlassCard(
          child: const Padding(
        padding: EdgeInsets.all(20),
        child: Row(children: [
          Icon(Icons.key_outlined, color: AppTheme.textTertiary, size: 20),
          SizedBox(width: 12),
          Expanded(
              child: Text(
                  'Connect Binance API keys in Settings to see your overall PnL',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        ]),
      ));
    }

    final totalPnl = _pnl!['total_pnl'] ?? '0';
    final spotPnl = _pnl!['spot']?['pnl'] ?? '0';
    final unrPnl = _pnl!['futures_unrealized']?['pnl'] ?? '0';
    final realPnl = _pnl!['futures_realized']?['pnl'] ?? '0';
    final spotPct = _pnl!['spot']?['pnl_pct'] ?? '0';
    final total = _d(totalPnl);
    final isPos = total >= 0;
    final color = _col(totalPnl);

    final spotV = _d(spotPnl);
    final unrV = _d(unrPnl);
    final realV = _d(realPnl);
    final maxAbs = [spotV.abs(), unrV.abs(), realV.abs(), 1.0].reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.14), AppTheme.surfaceCard]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(isPos ? Icons.trending_up : Icons.trending_down,
                  color: color, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Overall Binance PnL',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text(_periodLabel,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 10)),
          ]),
          const Spacer(),
          // Period badge
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(_period.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),

        // Big number row
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${total >= 0 ? '+' : ''}${_fmt(totalPnl)}',
              style: TextStyle(
                  color: color,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                Icon(isPos ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color, size: 10),
                const SizedBox(width: 3),
                Text(_pct(spotPct),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // Horizontal breakdown bars
        _bar('Spot', spotV, AppTheme.primary, maxAbs),
        _bar('Unrealized', unrV, AppTheme.ethColor, maxAbs),
        _bar('Realized', realV, AppTheme.solColor, maxAbs),

        const SizedBox(height: 16),

        // Legend row
        Row(children: [
          _dot(AppTheme.primary, 'Spot', spotV),
          const SizedBox(width: 16),
          _dot(AppTheme.ethColor, 'Unrealized', unrV),
          const SizedBox(width: 16),
          _dot(AppTheme.solColor, 'Realized', realV),
        ]),
      ]),
    );
  }

  Widget _bar(String label, double val, Color color, double maxAbs) {
    final frac = (val.abs() / maxAbs).clamp(0.03, 1.0);
    final isPos = val >= 0;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11))),
          Expanded(
              child: Stack(children: [
            Container(
                height: 24,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(5))),
            FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: color.withOpacity(0.45), width: 1)))),
            Positioned.fill(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${isPos ? '+' : ''}${_fmt(val)}',
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))))),
          ])),
        ]));
  }

  Widget _dot(Color color, String label, double val) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
          Text('${val >= 0 ? '+' : ''}${_fmt(val)}',
              style: TextStyle(
                  color: _col(val), fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ]);

  // ── 3 breakdown chips ─────────────────────────────────────────────────────
  Widget _pnlBreakdownRow() {
    if (_pnlLoading || _pnl == null) return const SizedBox.shrink();
    return Row(children: [
      _chip('Spot', _pnl!['spot']?['pnl'] ?? '0',
          Icons.account_balance_wallet_outlined),
      const SizedBox(width: 10),
      _chip('Unrealized', _pnl!['futures_unrealized']?['pnl'] ?? '0',
          Icons.trending_up),
      const SizedBox(width: 10),
      _chip('Realized', _pnl!['futures_realized']?['pnl'] ?? '0',
          Icons.receipt_long_outlined),
    ]);
  }

  Widget _chip(String label, dynamic val, IconData icon) {
    final color = _col(val);
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.textTertiary, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
        ]),
        const SizedBox(height: 5),
        Text('${_d(val) >= 0 ? '+' : ''}${_fmt(val)}',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  // ── Wallet portfolio card ──────────────────────────────────────────────────
  Widget _portfolioCard() {
    final total = _portfolio?['total_portfolio_usd'] ?? 0;
    final pts = ((_performance?['data_points'] as List?) ?? []);
    final vals = pts.map((p) => _d(p['volume_usd'])).toList();
    final sum = vals.fold(0.0, (s, v) => s + v);
    final pct = _d(total) > 0 ? sum / _d(total) * 100 : 0.0;
    final color = sum >= 0 ? AppTheme.positive : AppTheme.negative;

    return GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Portfolio Value',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Text(_fmt(total),
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(
                '${sum >= 0 ? '+' : ''}${_fmt(sum)}  ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700))),
        const SizedBox(width: 6),
        Text('Wallets · $_periodLabel',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
      ]),
      const SizedBox(height: 16),
      if (vals.isEmpty)
        SizedBox(
            height: 100,
            child: Center(
                child: Text('No data for this period',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11))))
      else
        _lineChart(vals, pts, color),
    ]));
  }

  Widget _lineChart(List<double> vals, List pts, Color color) {
    return GestureDetector(
      onPanUpdate: (d) => _updateHover(d.localPosition.dx, vals),
      onPanEnd: (_) => setState(() => _hoveredIndex = null),
      onTapDown: (d) => _updateHover(d.localPosition.dx, vals),
      onTapUp: (_) => Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _hoveredIndex = null);
      }),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedOpacity(
            opacity: _hoveredIndex != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: _hoveredIndex != null
                ? _tooltip(vals, pts, _hoveredIndex!, color)
                : const SizedBox(height: 30)),
        const SizedBox(height: 6),
        SizedBox(
            height: 110,
            child: CustomPaint(
                size: const Size(double.infinity, 110),
                painter: _LinePainter(
                    values: vals,
                    lineColor: color,
                    hoveredIndex: _hoveredIndex))),
        const SizedBox(height: 6),
        if (pts.isNotEmpty)
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _xLabels(pts)),
      ]),
    );
  }

  void _updateHover(double localX, List<double> vals) {
    if (vals.length < 2) return;
    const lp = 40.0;
    final rbo = context.findRenderObject() as RenderBox?;
    if (rbo == null) return;
    final w = rbo.size.width - lp * 2;
    final step = w / (vals.length - 1);
    final idx = ((localX - lp) / step).round().clamp(0, vals.length - 1);
    setState(() => _hoveredIndex = idx);
  }

  Widget _tooltip(List<double> vals, List pts, int idx, Color color) {
    final val = vals[idx];
    String ds = '';
    if (idx < pts.length) {
      try {
        final d = DateTime.parse(pts[idx]['date'].toString());
        const mo = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        ds = '${mo[d.month - 1]} ${d.day}';
      } catch (_) {}
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ds.isNotEmpty) ...[
            Text(ds,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 11)),
            const SizedBox(width: 8)
          ],
          Text('${val >= 0 ? '+' : ''}${_fmt(val)}',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]));
  }

  List<Widget> _xLabels(List pts) {
    String fmt(String raw) {
      try {
        final d = DateTime.parse(raw);
        const mo = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${mo[d.month - 1]} ${d.day}';
      } catch (_) {
        return raw;
      }
    }

    const s = TextStyle(color: AppTheme.textTertiary, fontSize: 9);
    if (pts.length >= 3) {
      return [
        Text(fmt(pts.first['date']?.toString() ?? ''), style: s),
        Text(fmt(pts[pts.length ~/ 2]['date']?.toString() ?? ''), style: s),
        Text(fmt(pts.last['date']?.toString() ?? ''), style: s)
      ];
    }
    return [
      Text(fmt(pts.first['date']?.toString() ?? ''), style: s),
      Text(fmt(pts.last['date']?.toString() ?? ''), style: s)
    ];
  }

  // ── Metrics ────────────────────────────────────────────────────────────────
  Widget _metricsRow() {
    final m = _performance?['metrics'] ?? {};
    final items = [
      ['Sharpe', _d(m['sharpe_ratio']).toStringAsFixed(2)],
      ['Alpha', _d(m['alpha']).toStringAsFixed(2)],
      ['Beta', _d(m['beta']).toStringAsFixed(2)],
      ['Vol', _d(m['volatility']).toStringAsFixed(2)],
    ];
    return Row(
        children: items
            .asMap()
            .entries
            .map((e) => Expanded(
                child: Container(
                    margin: EdgeInsets.only(right: e.key < 3 ? 10 : 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border)),
                    child: Column(children: [
                      Text(e.value[1],
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(e.value[0],
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 10)),
                    ]))))
            .toList());
  }

  // ── Spot detail ────────────────────────────────────────────────────────────
  Widget _spotPnlCard() {
    final spot = _pnl!['spot'] as Map<String, dynamic>? ?? {};
    final pnl = spot['pnl'] ?? '0';
    final pct = spot['pnl_pct'] ?? '0';
    final cur = spot['current_value'] ?? '0';
    final cost = spot['cost_basis'] ?? '0';
    final assets = (spot['assets'] as List?) ?? [];
    return GlassCard(
        borderColor: _col(pnl).withOpacity(0.2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBox(Icons.account_balance_wallet_outlined),
            const SizedBox(width: 10),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Spot PnL',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('Cost basis vs current value',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 10)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_d(pnl) >= 0 ? '+' : ''}${_fmt(pnl)}',
                  style: TextStyle(
                      color: _col(pnl),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(_pct(pct), style: TextStyle(color: _col(pct), fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _infoBox('Current', _fmt(cur), AppTheme.primary)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _infoBox('Cost Basis', _fmt(cost), AppTheme.textSecondary)),
          ]),
          if (assets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            const Text('Per Asset',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...assets.take(5).map((a) => _assetRow(a)),
            if (assets.length > 5)
              Text('+${assets.length - 5} more',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11)),
          ],
        ]));
  }

  Widget _futuresUnrealizedCard() {
    final unr = _pnl!['futures_unrealized'] as Map<String, dynamic>? ?? {};
    final pnl = unr['pnl'] ?? '0';
    final pos = (unr['positions'] as List?) ?? [];
    return GlassCard(
        borderColor: _col(pnl).withOpacity(0.2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBox(Icons.trending_up),
            const SizedBox(width: 10),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Futures Unrealized PnL',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('Open positions (always current)',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 10)),
                ])),
            Text('${_d(pnl) >= 0 ? '+' : ''}${_fmt(pnl)}',
                style: TextStyle(
                    color: _col(pnl),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          if (pos.isEmpty) ...[
            const SizedBox(height: 12),
            const Center(
                child: Text('No open positions',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 12))),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            ...pos.map((p) => _positionRow(p)),
          ],
        ]));
  }

  Widget _futuresRealizedCard() {
    final real = _pnl!['futures_realized'] as Map<String, dynamic>? ?? {};
    final pnl = real['pnl'] ?? '0';
    final entries = (real['entries'] as List?) ?? [];
    return GlassCard(
        borderColor: _col(pnl).withOpacity(0.2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBox(Icons.receipt_long_outlined),
            const SizedBox(width: 10),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Futures Realized PnL',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('Closed trade income',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 10)),
                ])),
            Text('${_d(pnl) >= 0 ? '+' : ''}${_fmt(pnl)}',
                style: TextStyle(
                    color: _col(pnl),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          if (entries.isEmpty) ...[
            const SizedBox(height: 12),
            const Center(
                child: Text('No realized PnL found',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 12))),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            ...entries.take(5).map((e) => _realizedRow(e)),
          ],
        ]));
  }

  // ── Profit history ─────────────────────────────────────────────────────────
  Widget _profitHistoryCard() {
    final monthly = (_profit?['monthly'] as List?) ?? [];
    final vals = monthly.map((m) => _d(m['value'])).toList();
    final labels = monthly.map((m) => m['month']?.toString() ?? '').toList();
    return GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Monthly Profit History',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      if (monthly.isEmpty)
        const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No profit history yet',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 12))))
      else ...[
        SizedBox(
            height: 100,
            child: CustomPaint(
                size: const Size(double.infinity, 100),
                painter: _BarPainter(values: vals))),
        const SizedBox(height: 8),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((l) => Text(l,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 9)))
                .toList()),
      ],
    ]));
  }

  // ── Allocation ─────────────────────────────────────────────────────────────
  Widget _allocationRow() {
    final alloc = (_portfolio?['allocation'] as Map<String, dynamic>?) ?? {};
    final cmap = {
      'BTC': AppTheme.btcColor,
      'ETH': AppTheme.ethColor,
      'USDT': AppTheme.usdtColor,
      'SOL': AppTheme.solColor
    };
    final es = alloc.entries.toList()
      ..sort((a, b) => _d(b.value).compareTo(_d(a.value)));
    final top4 = es.take(4).toList();
    final other = es.skip(4).fold(0.0, (s, e) => s + _d(e.value));
    final segs = <(Color, double)>[
      ...top4.map(
          (e) => (cmap[e.key] ?? AppTheme.textTertiary, _d(e.value) / 100)),
      if (other > 0) (AppTheme.textTertiary, other / 100),
    ];
    return Row(children: [
      Expanded(
          child: GlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const Text('Asset Distribution',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Center(
                child: SizedBox(
                    width: 80,
                    height: 80,
                    child: segs.isEmpty
                        ? const Center(
                            child: Text('N/A',
                                style: TextStyle(color: AppTheme.textTertiary)))
                        : CustomPaint(painter: _DonutPainter(segs)))),
            const SizedBox(height: 12),
            ...top4.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: cmap[e.key] ?? AppTheme.textTertiary,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text(e.key,
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 10))),
                  Text('${_d(e.value).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]))),
            if (other > 0)
              Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: AppTheme.textTertiary, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Expanded(
                    child: Text('Other',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 10))),
                Text('${other.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
          ]))),
      const SizedBox(width: 14),
      Expanded(
          child: GlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const Text('By Sector',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Center(
                child: SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                        painter: _DonutPainter([
                      (AppTheme.primary, 0.28),
                      (AppTheme.ethColor, 0.35),
                      (AppTheme.usdtColor, 0.22),
                      (AppTheme.solColor, 0.15),
                    ])))),
            const SizedBox(height: 12),
            ...[
              ['Layer 1', AppTheme.ethColor, '35%'],
              ['DeFi', AppTheme.primary, '28%'],
              ['Stable', AppTheme.usdtColor, '22%'],
              ['Other', AppTheme.solColor, '15%']
            ].map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: r[1] as Color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text(r[0] as String,
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 10))),
                  Text(r[2] as String,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]))),
          ]))),
    ]);
  }

  // ── Shared sub-widgets ─────────────────────────────────────────────────────
  Widget _iconBox(IconData icon) => Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: AppTheme.textSecondary));

  Widget _infoBox(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]));

  Widget _assetRow(Map<String, dynamic> a) {
    final pnl = a['pnl'] ?? '0';
    final pct = a['pnl_pct'] ?? '0';
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: AppTheme.surfaceElevated, shape: BoxShape.circle),
              child: Center(
                  child: Text((a['asset'] ?? '?').toString().substring(0, 1),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(a['asset'] ?? '',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_d(pnl) >= 0 ? '+' : ''}${_fmt(pnl)}',
                style: TextStyle(
                    color: _col(pnl),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            Text(_pct(pct), style: TextStyle(color: _col(pct), fontSize: 10)),
          ]),
        ]));
  }

  Widget _positionRow(Map<String, dynamic> p) {
    final upnl = p['unrealized_pnl'] ?? '0';
    final side = p['side'] ?? 'LONG';
    final isLong = side == 'LONG';
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: (isLong ? AppTheme.positive : AppTheme.negative)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(side,
                  style: TextStyle(
                      color: isLong ? AppTheme.positive : AppTheme.negative,
                      fontSize: 9,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p['symbol'] ?? '',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                Text(
                    'Entry: \$${_d(p['entry_price']).toStringAsFixed(2)}  ×${p['leverage']}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 10)),
              ])),
          Text('${_d(upnl) >= 0 ? '+' : ''}${_fmt(upnl)}',
              style: TextStyle(
                  color: _col(upnl),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]));
  }

  Widget _realizedRow(Map<String, dynamic> e) {
    final income = e['income'] ?? '0';
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(_d(income) >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
              color: _col(income), size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(e['symbol'] ?? 'USDT',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12))),
          Text('${_d(income) >= 0 ? '+' : ''}${_fmt(income)}',
              style: TextStyle(
                  color: _col(income),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]));
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final int? hoveredIndex;
  const _LinePainter(
      {required this.values, required this.lineColor, this.hoveredIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final w = size.width;
    final h = size.height;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs();
    const vp = 12.0;

    double norm(double v) => range == 0 ? 0.5 : (v - minV) / range;
    double xOf(int i) => i * w / (values.length - 1);
    double yOf(double v) => h - vp - norm(v) * (h - vp * 2);

    final gp = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 0.5;
    for (int i = 0; i < 4; i++)
      canvas.drawLine(Offset(0, vp + i * (h - vp * 2) / 3),
          Offset(w, vp + i * (h - vp * 2) / 3), gp);

    if (minV < 0 && maxV > 0) {
      canvas.drawLine(
          Offset(0, yOf(0)),
          Offset(w, yOf(0)),
          Paint()
            ..color = AppTheme.border.withOpacity(0.9)
            ..strokeWidth = 1);
    }

    final path = Path()..moveTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < values.length; i++) {
      final x0 = xOf(i - 1);
      final y0 = yOf(values[i - 1]);
      final x1 = xOf(i);
      final y1 = yOf(values[i]);
      path.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
    }
    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lineColor.withOpacity(0.20),
                lineColor.withOpacity(0.0)
              ]).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    void lbl(String t, double y, bool top) {
      final tp = TextPainter(
          text: TextSpan(
              text: t,
              style: TextStyle(
                  color: AppTheme.textTertiary.withOpacity(0.7), fontSize: 8)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(4, top ? y + 2 : y - tp.height - 2));
    }

    String fy(double v) {
      if (v.abs() >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
      if (v.abs() >= 1e3) return '\$${(v / 1e3).toStringAsFixed(1)}K';
      return '\$${v.toStringAsFixed(0)}';
    }

    lbl(fy(maxV), yOf(maxV), true);
    lbl(fy(minV), yOf(minV), false);

    if (hoveredIndex != null && hoveredIndex! < values.length) {
      final hx = xOf(hoveredIndex!);
      final hy = yOf(values[hoveredIndex!]);
      final dp = Paint()
        ..color = lineColor.withOpacity(0.4)
        ..strokeWidth = 1;
      double dy = 0;
      while (dy < h) {
        canvas.drawLine(Offset(hx, dy), Offset(hx, dy + 4), dp);
        dy += 8;
      }
      canvas.drawCircle(
          Offset(hx, hy), 7, Paint()..color = lineColor.withOpacity(0.25));
      canvas.drawCircle(Offset(hx, hy), 4, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) =>
      o.values != values ||
      o.lineColor != lineColor ||
      o.hoveredIndex != hoveredIndex;
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  const _BarPainter({required this.values});
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final w = size.width;
    final h = size.height / 2;
    final maxV = values.map((v) => v.abs()).reduce(math.max);
    if (maxV == 0) return;
    final bw = (w / values.length) - 4;
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final bh = (v.abs() / maxV) * h * 0.9;
      final x = i * (w / values.length) + 2;
      final y = v >= 0 ? h - bh : h;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, bw, bh), const Radius.circular(2)),
          Paint()
            ..color = (v >= 0 ? AppTheme.positive : AppTheme.negative)
                .withOpacity(0.85));
    }
    canvas.drawLine(
        Offset(0, h),
        Offset(w, h),
        Paint()
          ..color = AppTheme.border
          ..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(covariant _BarPainter o) => o.values != values;
}

class _DonutPainter extends CustomPainter {
  final List<(Color, double)> segs;
  const _DonutPainter(this.segs);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    double start = -math.pi / 2;
    for (final (color, pct) in segs) {
      if (pct <= 0) continue;
      final sweep = 2 * math.pi * pct - 0.06;
      if (sweep <= 0) continue;
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          start,
          sweep,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12);
      start += sweep + 0.06;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}
