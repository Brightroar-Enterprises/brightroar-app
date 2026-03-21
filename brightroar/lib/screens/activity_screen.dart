import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _selectedFilter = 'All';
  final _filters = ['All', 'Deposits', 'Withdrawals', 'Trades', 'Transfers'];
  List<dynamic> _transactions = [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _page = 1;

  final _filterMap = {'All': null, 'Deposits': 'deposit', 'Withdrawals': 'withdrawal', 'Trades': 'trade', 'Transfers': 'internal_transfer'};

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final txType = _filterMap[_selectedFilter];
      final data = await ApiClient.getTransactions(txType: txType, pageSize: 20);
      setState(() { _transactions = data['transactions'] ?? []; _total = data['total'] ?? 0; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(onRefresh: _loadData, color: AppTheme.primary,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Column(children: [_appBar(), _buildFilters(), _buildSearch()])),
          if (_loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_error != null) SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.wifi_off, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry', style: TextStyle(color: AppTheme.background))),
          ])))
          else if (_transactions.isEmpty) const SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_outlined, color: AppTheme.textTertiary, size: 48),
            SizedBox(height: 16),
            Text('No transactions yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Your transaction history will appear here', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
          ])))
          else SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _txItem(_transactions[i]),
              childCount: _transactions.length))),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ])),
    );
  }

  Widget _appBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Activity', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
        Text('$_total transactions total', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
      ]),
      const Spacer(),
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
        child: const Icon(Icons.tune_outlined, size: 18, color: AppTheme.textSecondary)),
    ]));

  Widget _buildFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: _filters.map((f) => GestureDetector(
      onTap: () { setState(() => _selectedFilter = f); _loadData(); },
      child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: f == _selectedFilter ? AppTheme.primary : AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: f == _selectedFilter ? AppTheme.primary : AppTheme.border)),
        child: Text(f, style: TextStyle(color: f == _selectedFilter ? AppTheme.background : AppTheme.textSecondary, fontSize: 13, fontWeight: f == _selectedFilter ? FontWeight.w600 : FontWeight.w400)))
    )).toList()));

  Widget _buildSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Container(height: 44,
      decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: const Row(children: [SizedBox(width: 12), Icon(Icons.search, color: AppTheme.textTertiary, size: 18), SizedBox(width: 8), Text('Search transaction ID or asset', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13))])));

  Widget _txItem(Map<String, dynamic> tx) {
    final isPos = tx['tx_type'] == 'deposit';
    final amount = tx['amount']?.toString() ?? '0';
    final symbol = tx['asset_symbol'] ?? '';
    final status = tx['status'] ?? '';
    final type = (tx['tx_type'] ?? 'transfer').toString();
    final date = _formatDate(tx['created_at']?.toString() ?? '');

    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: (isPos ? AppTheme.positive : AppTheme.negative).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(_txIcon(type), color: isPos ? AppTheme.positive : AppTheme.negative, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${isPos ? '+' : '-'}$amount $symbol', style: TextStyle(color: isPos ? AppTheme.positive : AppTheme.negative, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 2),
          Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text('Fee: ${tx['fee'] ?? '0'} $symbol', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w600))),
          ]),
        ])),
      ]));
  }

  String _formatDate(String iso) {
    try { final d = DateTime.parse(iso); return '${d.day}.${d.month}.${d.year}'; }
    catch(_) { return iso; }
  }

  IconData _txIcon(String t) { switch(t) { case 'deposit': return Icons.arrow_downward; case 'withdrawal': return Icons.arrow_upward; case 'internal_transfer': return Icons.swap_horiz; case 'external_transfer': return Icons.send; default: return Icons.receipt_long; } }
  Color _statusColor(String s) { switch(s) { case 'confirmed': return AppTheme.positive; case 'pending': return AppTheme.warning; case 'failed': return AppTheme.negative; default: return AppTheme.textTertiary; } }
}
