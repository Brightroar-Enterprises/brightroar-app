import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _secretController = TextEditingController();
  bool _obscureSecret = true;
  bool _savingKeys = false;
  bool _loadingCreds = true;
  Map<String, dynamic>? _savedCreds;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    setState(() => _loadingCreds = true);
    try {
      final creds = await ApiClient.getBinanceCredentials();
      setState(() { _savedCreds = creds; _loadingCreds = false; });
    } catch (_) {
      setState(() { _savedCreds = null; _loadingCreds = false; });
    }
  }

  Future<void> _saveKeys() async {
    if (_apiKeyController.text.isEmpty || _secretController.text.isEmpty) {
      _showSnack('Please enter both API Key and Secret Key', AppTheme.negative);
      return;
    }
    setState(() => _savingKeys = true);
    try {
      await ApiClient.saveBinanceCredentials(
        apiKey: _apiKeyController.text.trim(),
        apiSecret: _secretController.text.trim(),
      );
      _apiKeyController.clear();
      _secretController.clear();
      await _loadSavedCredentials();
      _showSnack('Binance account connected successfully!', AppTheme.positive);
    } on ApiException catch (e) {
      _showSnack(e.message, AppTheme.negative);
    } catch (e) {
      _showSnack(e.toString(), AppTheme.negative);
    } finally {
      setState(() => _savingKeys = false);
    }
  }

  Future<void> _deleteKeys() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Binance Keys', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to remove your Binance API credentials?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: AppTheme.negative))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.deleteBinanceCredentials();
      setState(() => _savedCreds = null);
      _showSnack('Binance credentials removed', AppTheme.warning);
    } catch (e) {
      _showSnack(e.toString(), AppTheme.negative);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildAppBar(user)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Profile card
                _buildProfileCard(user),
                const SizedBox(height: 24),
                // Binance section
                _buildBinanceSection(),
                const SizedBox(height: 24),
                // Security section
                _buildSecuritySection(),
                const SizedBox(height: 24),
                // Logout
                _buildLogoutButton(auth),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Map<String, dynamic>? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Row(children: [
        const Text('Settings', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            (user?['contact_person'] ?? 'U').toString().isNotEmpty
                ? (user?['contact_person'] ?? 'U').toString().substring(0, 1).toUpperCase()
                : 'U',
            style: const TextStyle(color: AppTheme.background, fontSize: 13, fontWeight: FontWeight.w700),
          )),
        ),
      ]),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic>? user) {
    return GlassCard(
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
          ),
          child: Center(child: Text(
            (user?['contact_person'] ?? 'U').toString().isNotEmpty
                ? (user?['contact_person'] ?? 'U').toString().substring(0, 1).toUpperCase()
                : 'U',
            style: const TextStyle(color: AppTheme.primary, fontSize: 22, fontWeight: FontWeight.w700),
          )),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user?['company_name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(user?['corporate_email'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 2),
          Text(user?['contact_person'] ?? '', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.positive.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: const Text('Active', style: TextStyle(color: AppTheme.positive, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildBinanceSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Binance Account', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('Connect your Binance account to view real-time balances', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
      const SizedBox(height: 14),

      // Show connected status if keys saved
      if (_loadingCreds)
        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)))
      else if (_savedCreds != null)
        _buildConnectedCard()
      else
        _buildConnectForm(),
    ]);
  }

  Widget _buildConnectedCard() {
    return GlassCard(
      borderColor: AppTheme.positive.withOpacity(0.3),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.positive.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_outline, color: AppTheme.positive, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Binance Connected', style: TextStyle(color: AppTheme.positive, fontSize: 15, fontWeight: FontWeight.w600)),
            Text(_savedCreds?['label'] ?? 'Main Account', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
          GestureDetector(
            onTap: _deleteKeys,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.negative.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.negative.withOpacity(0.3))),
              child: const Text('Remove', style: TextStyle(color: AppTheme.negative, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.vpn_key_outlined, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 6),
          Text('API Key: ${_savedCreds?['api_key_preview'] ?? '***'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          const Icon(Icons.shield_outlined, size: 14, color: AppTheme.positive),
          const SizedBox(width: 4),
          const Text('Read Only', style: TextStyle(color: AppTheme.positive, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadSavedCredentials,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh Connection'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
            ),
          )),
      ]),
    );
  }

  Widget _buildConnectForm() {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Binance logo row
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF0B90B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('B', style: TextStyle(color: Color(0xFFF0B90B), fontWeight: FontWeight.w700, fontSize: 18))),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Binance API Keys', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            Text('Read-only access required', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 20),

        // API Key field
        const Text('API Key', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Paste your Binance API Key',
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18, color: AppTheme.textTertiary),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste, size: 16, color: AppTheme.textTertiary),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) _apiKeyController.text = data!.text!;
              },
              tooltip: 'Paste',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Secret Key field
        const Text('Secret Key', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _secretController,
          obscureText: _obscureSecret,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Paste your Binance Secret Key',
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textTertiary),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.content_paste, size: 16, color: AppTheme.textTertiary),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) _secretController.text = data!.text!;
                },
                tooltip: 'Paste',
              ),
              IconButton(
                icon: Icon(_obscureSecret ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textTertiary),
                onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Only "Read Info" permission is needed. Never enable trading or withdrawal permissions for security.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // Connect button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _savingKeys ? null : _saveKeys,
            child: _savingKeys
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.background, strokeWidth: 2))
                : const Text('CONNECT BINANCE', style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSecuritySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Security', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _settingsTile(Icons.fingerprint, 'Biometric Authentication', 'Use Face ID or fingerprint', trailing: Switch(value: false, onChanged: (_) {}, activeColor: AppTheme.primary)),
          const Divider(color: AppTheme.border, height: 1),
          _settingsTile(Icons.lock_reset_outlined, 'Change Password', 'Update your corporate password', onTap: () {}),
          const Divider(color: AppTheme.border, height: 1),
          _settingsTile(Icons.key_outlined, 'Hardware Key', 'FIDO2 hardware key settings', onTap: () {}),
        ]),
      ),
    ]);
  }

  Widget _settingsTile(IconData icon, String title, String subtitle, {Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: Icon(icon, size: 18, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(subtitle, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          ])),
          trailing ?? const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 18),
        ]),
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await auth.logout();
        },
        icon: const Icon(Icons.logout, size: 18, color: AppTheme.negative),
        label: const Text('Sign Out', style: TextStyle(color: AppTheme.negative, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.negative.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
