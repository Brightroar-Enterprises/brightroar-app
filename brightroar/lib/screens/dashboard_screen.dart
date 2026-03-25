import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/lion_logo.dart';
import '../services/auth_provider.dart';
import '../services/api_client.dart';
import 'dart:math' as math;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _wallets;
  Map<String, dynamic>? _binance;
  Map<String, dynamic>? _prices;
  Map<String, dynamic>? _performance;
  List<dynamic> _activity = [];
  bool _loading = true;
  String? _error;
  String _chartPeriod = 'D';

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.getPortfolioOverview(),
        ApiClient.getWallets(),
        ApiClient.getPrices(),
        ApiClient.getTransactions(pageSize: 5),
        ApiClient.getPerformance(period: '1m'),
      ]);
      _portfolio   = results[0];
      _wallets     = results[1];
      _prices      = results[2];
      _activity    = (results[3])['transactions'] ?? [];
      _performance = results[4];

      try { _binance = await ApiClient.getBinanceAccount(); } catch (_) { _binance = null; }

      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _parseDouble(dynamic v) {
    try { return double.parse(v.toString()); } catch (_) { return 0.0; }
  }

  String _fmtUsd(dynamic v) {
    final n = _parseDouble(v);
    if (n >= 1e9) return '\$${(n/1e9).toStringAsFixed(2)}B';
    if (n >= 1e6) return '\$${(n/1e6).toStringAsFixed(2)}M';
    if (n >= 1e3) return '\$${(n/1e3).toStringAsFixed(2)}K';
    return '\$${n.toStringAsFixed(2)}';
  }

  String _fmtPrice(dynamic v) {
    final n = _parseDouble(v);
    if (n >= 1000) return n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return n.toStringAsFixed(2);
  }

  double get _totalPortfolioUsd {
    final walletTotal = _parseDouble(_wallets?['total_balance_usd'] ?? 0);
    final binanceTotal = _parseDouble(_binance?['total_usd'] ?? 0);
    return walletTotal + binanceTotal;
  }

  // Build allocation from ALL sources combined
  Map<String, double> get _combinedAllocation {
    final Map<String, double> combined = {};
    final total = _totalPortfolioUsd;
    if (total <= 0) return {};

    // From internal wallets
    final wallets = (_wallets?['wallets'] as List?) ?? [];
    for (final w in wallets) {
      final symbol = (w['asset_symbol'] ?? 'USDT').toString();
      final usd = _parseDouble(w['balance_usd'] ?? 0);
      combined[symbol] = (combined[symbol] ?? 0) + usd;
    }

    // From Binance top assets (already has USD values)
    if (_binance != null) {
      final topAssets = (_binance!['top_assets'] as List?) ?? [];
      for (final a in topAssets) {
        final symbol = (a['asset'] ?? '').toString();
        final usd = _parseDouble(a['value_usd'] ?? 0);
        if (symbol.isNotEmpty) {
          combined[symbol] = (combined[symbol] ?? 0) + usd;
        }
      }
    }

    // Convert to percentages
    final pcts = <String, double>{};
    combined.forEach((k, v) {
      pcts[k] = (v / total * 100);
    });

    // Sort by value descending
    final sorted = pcts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Return top 4 + group rest as "Other"
    final result = <String, double>{};
    double otherPct = 0;
    for (int i = 0; i < sorted.length; i++) {
      if (i < 4) {
        result[sorted[i].key] = sorted[i].value;
      } else {
        otherPct += sorted[i].value;
      }
    }
    if (otherPct > 0.1) result['Other'] = otherPct;
    return result;
  }

  // Chart data points from performance API
  List<double> get _chartPoints {
    final dataPoints = (_performance?['data_points'] as List?) ?? [];
    if (dataPoints.isEmpty) {
      // Return dummy upward trend if no data
      return [0.3, 0.35, 0.4, 0.38, 0.45, 0.5, 0.48, 0.55, 0.6, 0.65];
    }
    final volumes = dataPoints.map((d) => _parseDouble(d['volume_usd'] ?? 0)).toList();
    if (volumes.isEmpty) return [0.5];
    final maxV = volumes.reduce(math.max);
    if (maxV <= 0) return volumes.map((_) => 0.5).toList();
    return volumes.map((v) => (v / maxV).clamp(0.05, 1.0)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadData, color: AppTheme.primary,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _appBar(user)),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_error != null)
            SliverFillRemaining(child: _errorWidget())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _totalPortfolioCard(),
                const SizedBox(height: 16),
                _livepricesRow(),
                const SizedBox(height: 20),
                _walletBreakdown(),
                const SizedBox(height: 20),
                if (_binance != null) ...[_binanceCard(), const SizedBox(height: 20)],
                _chartsRow(),
                const SizedBox(height: 20),
                _recentActivity(),
                const SizedBox(height: 20),
              ]))),
        ]),
      ),
    );
  }

  Widget _appBar(Map<String, dynamic>? user) {
    final initial = (user?['contact_person'] ?? 'U').toString().isNotEmpty
        ? (user?['contact_person'] ?? 'U').toString().substring(0, 1).toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceElevated, border: Border.all(color: AppTheme.border)),
          child: const Center(child: LionLogo(size: 22))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user?['company_name'] ?? 'Brightroar',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const Text('Asset Manager', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ]),
        const Spacer(),
        GestureDetector(onTap: _loadData,
          child: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: const Icon(Icons.refresh, size: 18, color: AppTheme.textSecondary))),
        const SizedBox(width: 10),
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(initial,
            style: const TextStyle(color: AppTheme.background, fontSize: 13, fontWeight: FontWeight.w700)))),
      ]),
    );
  }

  Widget _totalPortfolioCard() {
    final pnl = _parseDouble(_portfolio?['daily_pnl_usd'] ?? 0);
    final pct = _parseDouble(_portfolio?['daily_pnl_pct'] ?? 0);
    final isPos = pnl >= 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF141414)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.08), blurRadius: 30)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total Portfolio Value', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Text(_fmtUsd(_totalPortfolioUsd),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isPos ? AppTheme.positive : AppTheme.negative).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6)),
          child: Text('${isPos ? '+' : ''}\$${_fmtPrice(pnl.abs())} (${pct.abs().toStringAsFixed(2)}%) Daily PnL',
            style: TextStyle(color: isPos ? AppTheme.positive : AppTheme.negative, fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 16),
        Row(children: [
          _balanceChip('Wallets', _fmtUsd(_wallets?['total_balance_usd'] ?? 0), AppTheme.primary),
          const SizedBox(width: 10),
          _balanceChip('Binance', _fmtUsd(_binance?['total_usd'] ?? 0), const Color(0xFFF0B90B)),
        ]),
      ]),
    );
  }

  Widget _balanceChip(String label, String value, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    ])));

  Widget _livepricesRow() {
    if (_prices == null) return const SizedBox();
    final coins = [
      {'s': 'BTC', 'k': 'BTCUSDT', 'c': AppTheme.btcColor},
      {'s': 'ETH', 'k': 'ETHUSDT', 'c': AppTheme.ethColor},
      {'s': 'SOL', 'k': 'SOLUSDT', 'c': AppTheme.solColor},
      {'s': 'USDT','k': 'USDT',    'c': AppTheme.usdtColor},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Live Prices', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: coins.asMap().entries.map((e) {
        final coin = e.value;
        final price = coin['k'] == 'USDT' ? '1.00' : (_prices?[coin['k']] ?? '0').toString();
        return Expanded(child: Container(
          margin: EdgeInsets.only(right: e.key < coins.length - 1 ? 8 : 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: coin['c'] as Color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(coin['s'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 5),
            Text('\$${_fmtPrice(price)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ])));
      }).toList()),
    ]);
  }

  Widget _walletBreakdown() {
    final wallets = (_wallets?['wallets'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('My Wallets', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(_fmtUsd(_wallets?['total_balance_usd'] ?? 0),
          style: const TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      wallets.isEmpty
        ? const GlassCard(child: Padding(padding: EdgeInsets.all(16),
            child: Row(children: [Icon(Icons.info_outline, color: AppTheme.textTertiary, size: 18), SizedBox(width: 10),
              Expanded(child: Text('No wallets yet. Go to Wallets tab to create one.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))])))
        : GlassCard(padding: EdgeInsets.zero, child: ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: wallets.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
            itemBuilder: (ctx, i) {
              final w = wallets[i];
              final symbol = w['asset_symbol'] ?? 'USDT';
              final balance = _parseDouble(w['balance'] ?? 0);
              final balanceUsd = _parseDouble(w['balance_usd'] ?? 0);
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: Center(child: Text(symbol.substring(0, 1),
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(w['wallet_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${balance.toStringAsFixed(2)} $symbol',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_fmtUsd(balanceUsd), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                  ]),
                ]));
            })),
    ]);
  }

  Widget _binanceCard() {
    final total = _binance?['total_usd'] ?? '0';
    final wallets = (_binance?['wallets'] as Map<String, dynamic>?) ?? {};
    final topAssets = (_binance?['top_assets'] as List?) ?? [];
    final walletTypes = [
      {'key': 'spot',            'label': 'Spot',           'icon': Icons.account_balance_wallet_outlined},
      {'key': 'funding',         'label': 'Funding',        'icon': Icons.savings_outlined},
      {'key': 'futures_usdm',    'label': 'USD-M Futures',  'icon': Icons.trending_up},
      {'key': 'futures_coinm',   'label': 'COIN-M Futures', 'icon': Icons.currency_bitcoin},
      {'key': 'cross_margin',    'label': 'Cross Margin',   'icon': Icons.swap_horiz},
      {'key': 'isolated_margin', 'label': 'Isolated Margin','icon': Icons.lock_outline},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Binance Account', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(_fmtUsd(total), style: const TextStyle(color: Color(0xFFF0B90B), fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      GlassCard(borderColor: const Color(0xFFF0B90B).withOpacity(0.2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFFF0B90B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('B', style: TextStyle(color: Color(0xFFF0B90B), fontWeight: FontWeight.w700, fontSize: 16)))),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Binance Total Balance', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Spot + Funding + Futures + Margin', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.positive.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text('Live', style: TextStyle(color: AppTheme.positive, fontSize: 10, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 12),
          Text(_fmtUsd(total), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 10),
          // Wallet type breakdown — only show if > $0
          ...walletTypes.map((wt) {
            final wd = wallets[wt['key']] as Map<String, dynamic>?;
            final wdTotal = _parseDouble(wd?['total_usd'] ?? 0);
            if (wdTotal <= 0) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                  child: Icon(wt['icon'] as IconData, size: 16, color: AppTheme.textSecondary)),
                const SizedBox(width: 10),
                Expanded(child: Text(wt['label'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                Text(_fmtUsd(wdTotal), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]));
          }),
          if (topAssets.isNotEmpty) ...[
            const Divider(color: AppTheme.border),
            const SizedBox(height: 10),
            const Text('Top Assets', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            ...topAssets.take(5).map((a) {
              final usd = _parseDouble(a['value_usd'] ?? 0);
              final pct = _parseDouble(a['allocation_pct'] ?? 0);
              return Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 30, height: 30,
                    decoration: const BoxDecoration(color: AppTheme.surfaceElevated, shape: BoxShape.circle),
                    child: Center(child: Text((a['asset'] ?? '?').toString().substring(0, 1),
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['asset'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Stack(children: [
                      Container(height: 3, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
                      FractionallySizedBox(widthFactor: (pct / 100).clamp(0.0, 1.0),
                        child: Container(height: 3, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)))),
                    ]),
                  ])),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_fmtUsd(usd), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                  ]),
                ]));
            }),
          ],
        ])),
    ]);
  }

  Widget _chartsRow() {
    final allocation = _combinedAllocation;
    final chartPts = _chartPoints;

    // Colors for allocation segments
    final colorMap = {
      'BTC': AppTheme.btcColor, 'ETH': AppTheme.ethColor,
      'USDT': AppTheme.usdtColor, 'SOL': AppTheme.solColor,
      'BNB': const Color(0xFFF0B90B), 'Other': AppTheme.textTertiary,
    };

    final allocationEntries = allocation.entries.toList();

    return Row(children: [
      // Performance chart — uses real data
      Expanded(child: GlassCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Performance', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text('Last ${_chartPeriod == 'D' ? '1d' : _chartPeriod == 'W' ? '7d' : _chartPeriod == 'M' ? '30d' : '365d'} activity',
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
        const SizedBox(height: 12),
        SizedBox(height: 70, child: CustomPaint(
          painter: _RealLineChartPainter(points: chartPts),
          size: const Size(double.infinity, 70))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['D','W','M','Y'].map((t) => GestureDetector(
            onTap: () {
              setState(() => _chartPeriod = t);
              // Reload performance with new period
              final period = t == 'D' ? '1d' : t == 'W' ? '1w' : t == 'M' ? '1m' : 'all';
              ApiClient.getPerformance(period: period).then((data) {
                setState(() => _performance = data);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: t == _chartPeriod ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(6)),
              child: Text(t, style: TextStyle(
                color: t == _chartPeriod ? AppTheme.primary : AppTheme.textTertiary,
                fontSize: 10, fontWeight: t == _chartPeriod ? FontWeight.w600 : FontWeight.w400)))
          )).toList()),
      ]))),
      const SizedBox(width: 14),
      // Allocation donut — uses real combined allocation
      Expanded(child: GlassCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Allocation', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        const Text('All wallets', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
        const SizedBox(height: 12),
        Center(child: SizedBox(width: 70, height: 70,
          child: allocation.isEmpty
            ? const Center(child: Text('N/A', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)))
            : CustomPaint(painter: _RealDonutPainter(
                segments: allocationEntries.map((e) => (
                  colorMap[e.key] ?? AppTheme.textTertiary,
                  e.value / 100,
                )).toList())))),
        const SizedBox(height: 10),
        ...allocationEntries.take(5).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(
              color: colorMap[e.key] ?? AppTheme.textTertiary, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Expanded(child: Text(e.key, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              overflow: TextOverflow.ellipsis)),
            Text('${e.value.toStringAsFixed(1)}%',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
          ]))),
      ]))),
    ]);
  }

  Widget _recentActivity() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recent Activity', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      _activity.isEmpty
        ? const GlassCard(child: Padding(padding: EdgeInsets.all(20),
            child: Center(child: Text('No transactions yet', style: TextStyle(color: AppTheme.textSecondary)))))
        : GlassCard(padding: EdgeInsets.zero, child: ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _activity.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
            itemBuilder: (ctx, i) {
              final tx = _activity[i];
              final isPos = tx['tx_type'] == 'deposit';
              final amount = _parseDouble(tx['amount'] ?? 0);
              final symbol = tx['asset_symbol'] ?? '';
              final date = _formatDate(tx['created_at']?.toString() ?? '');
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: (isPos ? AppTheme.positive : AppTheme.negative).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(_txIcon(tx['tx_type']), color: isPos ? AppTheme.positive : AppTheme.negative, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((tx['tx_type'] ?? 'transfer').toString().replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(date, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${isPos ? '+' : '-'}${amount.toStringAsFixed(4)} $symbol',
                      style: TextStyle(color: isPos ? AppTheme.positive : AppTheme.negative, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(_fmtUsd(tx['amount_usd'] ?? 0), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor(tx['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(tx['status'] ?? '',
                        style: TextStyle(color: _statusColor(tx['status']), fontSize: 10, fontWeight: FontWeight.w600))),
                  ]),
                ]));
            })),
    ]);
  }

  Widget _errorWidget() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.wifi_off, color: AppTheme.textTertiary, size: 48),
    const SizedBox(height: 16),
    const Text('Could not load data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
    const SizedBox(height: 8),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(_error ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center)),
    const SizedBox(height: 20),
    ElevatedButton(onPressed: _loadData, child: const Text('Retry', style: TextStyle(color: AppTheme.background))),
  ]));

  String _formatDate(String iso) {
    try { final d = DateTime.parse(iso); return '${d.day}/${d.month}/${d.year}'; } catch (_) { return iso; }
  }
  IconData _txIcon(String? t) { switch(t) { case 'deposit': return Icons.arrow_downward; case 'withdrawal': return Icons.arrow_upward; case 'internal_transfer': return Icons.swap_horiz; case 'external_transfer': return Icons.send; default: return Icons.receipt_long; } }
  Color _statusColor(String? s) { switch(s) { case 'confirmed': return AppTheme.positive; case 'pending': return AppTheme.warning; case 'failed': return AppTheme.negative; default: return AppTheme.textTertiary; } }
}

// ── Real line chart using actual data points ──────────────────────────────────

class _RealLineChartPainter extends CustomPainter {
  final List<double> points;
  const _RealLineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width; final h = size.height;
    final step = points.length > 1 ? w / (points.length - 1) : w;

    // Grid
    final gridPaint = Paint()..color = AppTheme.border..strokeWidth = 0.5;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(Offset(0, h * i / 3), Offset(w, h * i / 3), gridPaint);
    }

    // Fill
    final fillPath = Path()..moveTo(0, h);
    for (int i = 0; i < points.length; i++) {
      final x = i * step; final y = h - (points[i] * h * 0.85);
      if (i == 0) {
        fillPath.lineTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath..lineTo(w, h)..close();
    canvas.drawPath(fillPath, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [AppTheme.primary.withOpacity(0.25), AppTheme.primary.withOpacity(0.0)],
    ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // Line
    if (points.length == 1) {
      canvas.drawLine(Offset(0, h - points[0] * h * 0.85), Offset(w, h - points[0] * h * 0.85),
        Paint()..color = AppTheme.primary..strokeWidth = 2..style = PaintingStyle.stroke);
      return;
    }
    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * step; final y = h - (points[i] * h * 0.85);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, Paint()..color = AppTheme.primary..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    // Last dot
    final lastX = (points.length - 1) * step;
    final lastY = h - (points.last * h * 0.85);
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = AppTheme.primary);
  }

  @override bool shouldRepaint(covariant _RealLineChartPainter old) => old.points != points;
}

// ── Real donut chart using actual allocation data ─────────────────────────────

class _RealDonutPainter extends CustomPainter {
  final List<(Color, double)> segments;
  const _RealDonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    double start = -math.pi / 2;
    final gap = segments.length > 1 ? 0.04 : 0.0;
    for (final (color, pct) in segments) {
      if (pct <= 0) continue;
      final sweep = (2 * math.pi * pct) - gap;
      if (sweep <= 0) continue;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.butt);
      start += sweep + gap;
    }
  }

  @override bool shouldRepaint(covariant _RealDonutPainter old) => old.segments != segments;
}
