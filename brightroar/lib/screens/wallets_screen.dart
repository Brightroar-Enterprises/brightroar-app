import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';
import 'transfer_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});
  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _walletData;
  Map<String, dynamic>? _binanceData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final wallets = await ApiClient.getWallets();
      Map<String, dynamic>? binance;
      try { binance = await ApiClient.getBinanceAccount(); } catch (_) {}
      setState(() { _walletData = wallets; _binanceData = binance; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(onRefresh: _loadData, color: AppTheme.primary,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Column(children: [_appBar(), _tabBar()])),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wifi_off, color: AppTheme.textTertiary, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry', style: TextStyle(color: AppTheme.background))),
            ])))
          else SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _totalCard(),
              const SizedBox(height: 20),
              _walletsList(),
              const SizedBox(height: 20),
              if (_binanceData != null) _binanceCard(),
              const SizedBox(height: 20),
            ]))),
        ])),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _appBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
    child: Row(children: [
      const Text('Wallets', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
      const Spacer(),
      GestureDetector(
        onTap: () => _showAddWalletSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Add Wallet', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500)),
          ])),
      ),
    ]));

  Widget _tabBar() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20), height: 44,
    decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
    child: TabBar(controller: _tabController,
      indicator: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: AppTheme.background, unselectedLabelColor: AppTheme.textSecondary,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      tabs: const [Tab(text: 'Institutional Wallets'), Tab(text: 'Cold Storage')]));

  // ── Total card ────────────────────────────────────────────────────────────

  Widget _totalCard() {
    final total = _walletData?['total_balance_usd'] ?? '0';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.primary.withOpacity(0.12), AppTheme.surfaceCard]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: AppTheme.usdtColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('T', style: TextStyle(color: AppTheme.usdtColor, fontWeight: FontWeight.w700, fontSize: 16)))),
          const SizedBox(width: 10),
          const Expanded(child: Text('Total Institutional Wallets',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 14),
        Text('\$${_fmt(total.toString())} USD',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _chip(Icons.swap_horiz, 'Internal Transfer',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen())))),
          const SizedBox(width: 8),
          Expanded(child: _chip(Icons.send_outlined, 'External Send',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen())))),
          const SizedBox(width: 8),
          Expanded(child: _chip(Icons.qr_code_scanner, 'Receive', () {})),
        ]),
      ]));
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
      ])));

  // ── Wallets list with edit/delete ─────────────────────────────────────────

  Widget _walletsList() {
    final wallets = (_walletData?['wallets'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your Wallets (${wallets.length})',
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      wallets.isEmpty
        ? GlassCard(child: Padding(padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.textTertiary, size: 40),
              const SizedBox(height: 12),
              const Text('No wallets yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Tap + Add Wallet to create your first wallet',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddWalletSheet(),
                icon: const Icon(Icons.add, size: 16, color: AppTheme.background),
                label: const Text('Add Wallet', style: TextStyle(color: AppTheme.background)),
              ),
            ])))
        : GlassCard(padding: EdgeInsets.zero, child: ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: wallets.length,
            separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
            itemBuilder: (ctx, i) => _walletItem(wallets[i]))),
    ]);
  }

  Widget _walletItem(Map<String, dynamic> w) {
    final symbol = w['asset_symbol'] ?? 'USDT';
    final balance = double.tryParse(w['balance']?.toString() ?? '0') ?? 0;
    final balanceUsd = double.tryParse(w['balance_usd']?.toString() ?? '0') ?? 0;
    final address = w['address']?.toString() ?? '';
    final hasAddress = address.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Center(child: Text(symbol.substring(0, 1),
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            Text(w['wallet_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
          ])),
          // Balance
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${balance.toStringAsFixed(4)} $symbol',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('\$${_fmt(balanceUsd.toString())}',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          ]),
          const SizedBox(width: 8),
          // Actions menu
          GestureDetector(
            onTap: () => _showWalletActions(w),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
              child: const Icon(Icons.more_vert, size: 16, color: AppTheme.textSecondary))),
        ]),
        // Wallet address (if set)
        if (hasAddress) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              _showSnack('Address copied!', AppTheme.positive);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.link, size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  '${address.substring(0, address.length > 20 ? 10 : address.length)}...${address.length > 20 ? address.substring(address.length - 8) : ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis)),
                const Icon(Icons.copy, size: 12, color: AppTheme.textTertiary),
              ])),
          ),
        ],
      ]),
    );
  }

  // ── Wallet actions sheet ──────────────────────────────────────────────────

  void _showWalletActions(Map<String, dynamic> wallet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Wallet name header
          Text(wallet['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${wallet['asset_symbol']} · ${wallet['wallet_type']?.toString().replaceAll('_', ' ')}',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          const SizedBox(height: 24),
          // Actions
          _actionTile(Icons.edit_outlined, 'Edit Wallet', AppTheme.primary, () {
            Navigator.pop(ctx);
            _showEditWalletSheet(wallet);
          }),
          const SizedBox(height: 12),
          _actionTile(Icons.swap_horiz, 'Transfer', AppTheme.textSecondary, () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
          }),
          const SizedBox(height: 12),
          _actionTile(Icons.delete_outline, 'Delete Wallet', AppTheme.negative, () {
            Navigator.pop(ctx);
            _confirmDelete(wallet);
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
        ])),
    );
  }

  // ── Add wallet sheet ──────────────────────────────────────────────────────

  void _showAddWalletSheet() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String walletType = 'internal';
    String asset = 'USDT';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Add New Wallet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Name
          const Text('Wallet Name', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(controller: nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(hintText: 'e.g. Main Treasury',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.textTertiary))),
          const SizedBox(height: 16),

          // Wallet address
          const Text('Wallet Address (optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(controller: addressCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '0x... or bc1...',
              prefixIcon: const Icon(Icons.link, size: 18, color: AppTheme.textTertiary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, size: 16, color: AppTheme.textTertiary),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) addressCtrl.text = data!.text!;
                }))),
          const SizedBox(height: 16),

          // Wallet type
          const Text('Wallet Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: ['treasury', 'internal', 'exchange', 'cold_storage'].map((t) =>
              GestureDetector(onTap: () => setS(() => walletType = t),
                child: Container(margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: walletType == t ? AppTheme.primary : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: walletType == t ? AppTheme.primary : AppTheme.border)),
                  child: Text(t.replaceAll('_', ' '), style: TextStyle(
                    color: walletType == t ? AppTheme.background : AppTheme.textSecondary,
                    fontSize: 12))))).toList())),
          const SizedBox(height: 16),

          // Asset
          const Text('Asset', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: ['USDT', 'BTC', 'ETH', 'SOL'].map((a) =>
            GestureDetector(onTap: () => setS(() => asset = a),
              child: Container(margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: asset == a ? AppTheme.primary : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: asset == a ? AppTheme.primary : AppTheme.border)),
                child: Text(a, style: TextStyle(
                  color: asset == a ? AppTheme.background : AppTheme.textSecondary,
                  fontSize: 12))))).toList()),
          const SizedBox(height: 24),

          // Create button
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  _showSnack('Please enter a wallet name', AppTheme.negative);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ApiClient.createWallet(
                    name: nameCtrl.text.trim(),
                    walletType: walletType,
                    assetSymbol: asset,
                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  );
                  _showSnack('Wallet created!', AppTheme.positive);
                  _loadData();
                } catch (e) {
                  _showSnack(e.toString(), AppTheme.negative);
                }
              },
              child: const Text('CREATE WALLET', style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w700)))),
        ]))));
  }

  // ── Edit wallet sheet ─────────────────────────────────────────────────────

  void _showEditWalletSheet(Map<String, dynamic> wallet) {
    final nameCtrl = TextEditingController(text: wallet['name'] ?? '');
    final addressCtrl = TextEditingController(text: wallet['address'] ?? '');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Edit Wallet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Name
          const Text('Wallet Name', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(controller: nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(hintText: 'Wallet name',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.textTertiary))),
          const SizedBox(height: 16),

          // Address
          const Text('Wallet Address', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(controller: addressCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '0x... or bc1...',
              prefixIcon: const Icon(Icons.link, size: 18, color: AppTheme.textTertiary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, size: 16, color: AppTheme.textTertiary),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) addressCtrl.text = data!.text!;
                }))),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  _showSnack('Name cannot be empty', AppTheme.negative);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ApiClient.updateWallet(
                    wallet['id'].toString(),
                    name: nameCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                  );
                  _showSnack('Wallet updated!', AppTheme.positive);
                  _loadData();
                } catch (e) {
                  _showSnack(e.toString(), AppTheme.negative);
                }
              },
              child: const Text('SAVE', style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w700)))),
          ]),
        ])));
  }

  // ── Confirm delete ────────────────────────────────────────────────────────

  void _confirmDelete(Map<String, dynamic> wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Wallet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${wallet['name']}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.deleteWallet(wallet['id'].toString());
                _showSnack('Wallet deleted', AppTheme.warning);
                _loadData();
              } catch (e) {
                _showSnack(e.toString(), AppTheme.negative);
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.negative, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ── Binance card ──────────────────────────────────────────────────────────

  Widget _binanceCard() {
    final total = _binanceData?['total_usd'] ?? '0';
    final wallets = (_binanceData?['wallets'] as Map<String, dynamic>?) ?? {};
    final topAssets = (_binanceData?['top_assets'] as List?) ?? [];
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
        Text('\$${_fmt(total.toString())}', style: const TextStyle(color: Color(0xFFF0B90B), fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      GlassCard(borderColor: const Color(0xFFF0B90B).withOpacity(0.2),
        child: Column(children: [
          Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFFF0B90B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('B', style: TextStyle(color: Color(0xFFF0B90B), fontWeight: FontWeight.w700, fontSize: 16)))),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Binance Corporate Wallet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Spot + Funding + Futures + Margin', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.positive.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text('Live', style: TextStyle(color: AppTheme.positive, fontSize: 10, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft,
            child: Text('\$${_fmt(total.toString())} USD',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 10),
          // Wallet type breakdown
          ...walletTypes.map((wt) {
            final wd = wallets[wt['key']] as Map<String, dynamic>?;
            final wdTotal = double.tryParse(wd?['total_usd']?.toString() ?? '0') ?? 0;
            if (wdTotal <= 0) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                  child: Icon(wt['icon'] as IconData, size: 16, color: AppTheme.textSecondary)),
                const SizedBox(width: 10),
                Expanded(child: Text(wt['label'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                Text('\$${_fmt(wdTotal.toString())}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]));
          }),
          if (topAssets.isNotEmpty) ...[
            const Divider(color: AppTheme.border),
            const SizedBox(height: 10),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Top Assets', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))),
            const SizedBox(height: 10),
            ...topAssets.take(5).map((a) {
              final usd = double.tryParse(a['value_usd']?.toString() ?? '0') ?? 0;
              final pct = double.tryParse(a['allocation_pct']?.toString() ?? '0') ?? 0;
              return Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: AppTheme.surfaceElevated, shape: BoxShape.circle),
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
                    Text('\$${_fmt(usd.toString())}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                  ]),
                ]));
            }),
          ],
        ])),
    ]);
  }

  String _fmt(String v) {
    try {
      final n = double.parse(v);
      if (n >= 1e9) return '${(n/1e9).toStringAsFixed(2)}B';
      if (n >= 1e6) return '${(n/1e6).toStringAsFixed(2)}M';
      if (n >= 1e3) return '${(n/1e3).toStringAsFixed(2)}K';
      return n.toStringAsFixed(2);
    } catch (_) { return v; }
  }
}
