import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final int _step = 1;
  bool _showBiometricDialog = false;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // Data from backend
  List<dynamic> _wallets = [];
  String? _selectedFromWalletId;
  String? _selectedFromWalletName;
  String _selectedAsset = 'USDT';

  // Form controllers
  final _toAddressController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  // Transfer type: internal or external
  bool _isExternal = true;
  String? _selectedToWalletId;
  String? _selectedToWalletName;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  @override
  void dispose() {
    _toAddressController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getWallets();
      final wallets = (data['wallets'] as List?) ?? [];
      setState(() {
        _wallets = wallets;
        // Don't pre-select — let user pick to avoid dropdown value mismatch
        _selectedFromWalletId = null;
        _selectedFromWalletName = null;
        _selectedAsset = 'USDT';
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submitTransfer() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount', AppTheme.negative);
      return;
    }
    if (_selectedFromWalletId == null) {
      _showSnack('Select a source wallet', AppTheme.negative);
      return;
    }
    if (_isExternal && _toAddressController.text.trim().isEmpty) {
      _showSnack('Enter destination address', AppTheme.negative);
      return;
    }
    if (!_isExternal && _selectedToWalletId == null) {
      _showSnack('Select destination wallet', AppTheme.negative);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiClient.transfer(
        fromWalletId: _selectedFromWalletId!,
        toWalletId: _isExternal ? null : _selectedToWalletId,
        toExternalAddress: _isExternal ? _toAddressController.text.trim() : null,
        assetSymbol: _selectedAsset,
        amount: amount,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      );
      setState(() => _submitting = false);
      _showSnack('Transfer submitted successfully', AppTheme.positive);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _submitting = false);
      _showSnack(e.toString(), AppTheme.negative);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.wifi_off, color: AppTheme.textTertiary, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _loadWallets, child: const Text('Retry', style: TextStyle(color: AppTheme.background))),
                  ]))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Header
                        Row(children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border)),
                              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textSecondary)),
                          ),
                          const Spacer(),
                          Row(children: List.generate(3, (i) {
                            final active = i + 1 <= _step;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i + 1 == _step ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active ? AppTheme.primary : AppTheme.border,
                                borderRadius: BorderRadius.circular(4)));
                          })),
                          const Spacer(),
                          Text('Step $_step of 3',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ]),
                        const SizedBox(height: 32),

                        // Title
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('SECURE TRANSFER',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            Text(_isExternal ? 'Internal → External' : 'Internal → Internal',
                              style: const TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // Transfer type toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border)),
                          child: Row(children: [
                            Expanded(child: GestureDetector(
                              onTap: () => setState(() => _isExternal = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isExternal ? AppTheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8)),
                                child: Text('External', textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isExternal ? AppTheme.background : AppTheme.textTertiary,
                                    fontSize: 12, fontWeight: FontWeight.w600))),
                            )),
                            Expanded(child: GestureDetector(
                              onTap: () => setState(() => _isExternal = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isExternal ? AppTheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8)),
                                child: Text('Internal', textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isExternal ? AppTheme.background : AppTheme.textTertiary,
                                    fontSize: 12, fontWeight: FontWeight.w600))),
                            )),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Form
                        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // From wallet
                          _label('From Wallet'),
                          const SizedBox(height: 8),
                          _dropdownField(
                            value: _selectedFromWalletId,
                            hint: 'Select wallet',
                            icon: Icons.account_balance_wallet_outlined,
                            items: _wallets.map((w) => DropdownMenuItem(
                              value: w['id']?.toString(),
                              child: Text(
                                '${w['name']} (${w['asset_symbol']})',
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (val) {
                              final w = _wallets.firstWhere((w) => w['id']?.toString() == val, orElse: () => {});
                              setState(() {
                                _selectedFromWalletId = val;
                                _selectedFromWalletName = w['name']?.toString();
                                _selectedAsset = w['asset_symbol']?.toString() ?? 'USDT';
                              });
                            },
                          ),

                          const SizedBox(height: 20),
                          Center(child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
                            child: const Icon(Icons.arrow_downward, color: AppTheme.primary, size: 18))),
                          const SizedBox(height: 20),

                          // To — external address or internal wallet
                          _label(_isExternal ? 'To Address' : 'To Wallet'),
                          const SizedBox(height: 8),
                          if (_isExternal)
                            _inputField(
                              controller: _toAddressController,
                              hint: 'Paste destination address',
                              icon: Icons.send_outlined)
                          else
                            _dropdownField(
                              value: _selectedToWalletId,
                              hint: 'Select destination wallet',
                              icon: Icons.account_balance_wallet_outlined,
                              items: _wallets
                                .where((w) => w['id']?.toString() != _selectedFromWalletId)
                                .map((w) => DropdownMenuItem(
                                  value: w['id']?.toString(),
                                  child: Text(
                                    '${w['name']} (${w['asset_symbol']})',
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                                )).toList(),
                              onChanged: (val) {
                                final w = _wallets.firstWhere((w) => w['id']?.toString() == val, orElse: () => {});
                                setState(() {
                                  _selectedToWalletId = val;
                                  _selectedToWalletName = w['name']?.toString();
                                });
                              },
                            ),

                          const SizedBox(height: 20),

                          // Amount
                          _label('Amount ($_selectedAsset)'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border)),
                            child: Row(children: [
                              Expanded(child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                  decoration: const InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none),
                                ),
                              )),
                              GestureDetector(
                                onTap: () {
                                  final w = _wallets.firstWhere((w) => w['id']?.toString() == _selectedFromWalletId, orElse: () => {});
                                  _amountController.text = w['balance']?.toString() ?? '0';
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6)),
                                  child: const Text('MAX',
                                    style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 20),

                          // Description (optional)
                          _label('Description (optional)'),
                          const SizedBox(height: 8),
                          _inputField(
                            controller: _descController,
                            hint: 'e.g. Q1 settlement',
                            icon: Icons.notes),
                        ])),

                        const SizedBox(height: 20),

                        // Biometric approval section
                        GlassCard(
                          borderColor: AppTheme.primary.withOpacity(0.2),
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8)),
                              // Fixed overflow: wrapped text in Flexible
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.security, color: AppTheme.primary, size: 14),
                                  SizedBox(width: 6),
                                  Flexible(child: Text(
                                    'APPROVE WITH BIOMETRICS',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3),
                                    overflow: TextOverflow.ellipsis)),
                                ]),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _biometricBtn(icon: Icons.face_retouching_natural, label: 'FaceID',
                                  onTap: () => setState(() => _showBiometricDialog = true)),
                                Container(width: 1, height: 50, color: AppTheme.border),
                                _biometricBtn(icon: Icons.fingerprint, label: 'Fingerprint',
                                  onTap: () => setState(() => _showBiometricDialog = true)),
                              ]),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        // Network fee
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border)),
                          child: const Row(children: [
                            Text('Estimated Network Fee',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            Spacer(),
                            Text('~\$2.40 USDT',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submitTransfer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: _submitting
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: AppTheme.background, strokeWidth: 2))
                              : const Text('SUBMIT TRANSFER',
                                  style: TextStyle(color: AppTheme.background, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
          if (_showBiometricDialog) _buildBiometricOverlay(),
        ],
      ),
    );
  }

  Widget _buildBiometricOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showBiometricDialog = false),
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2)),
                child: const Icon(Icons.face_retouching_natural, color: AppTheme.primary, size: 36)),
              const SizedBox(height: 18),
              const Text('Confirm Identity',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Authenticate to authorize this transfer',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _showBiometricDialog = false);
                    _submitTransfer();
                  },
                  child: const Text('AUTHENTICATE',
                    style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w700, letterSpacing: 1))),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _showBiometricDialog = false),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _biometricBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
          child: Icon(icon, color: AppTheme.primary, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500));

  Widget _inputField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.textTertiary),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none),
        )),
      ]),
    );
  }

  Widget _dropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.textTertiary),
        const SizedBox(width: 10),
        Expanded(child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            // Only use value if it actually exists in the items list
            value: items.any((item) => item.value == value) ? value : null,
            hint: Text(hint, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            dropdownColor: AppTheme.surfaceCard,
            isExpanded: true,
            icon: const Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
            items: items,
            onChanged: onChanged),
        )),
      ]),
    );
  }
}