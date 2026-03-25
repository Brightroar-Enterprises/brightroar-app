import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';
import 'property_past_suggestions_screen.dart';

class PropertyRecommendationsScreen extends StatefulWidget {
  final String location;
  final List<String> crimeRates;
  final List<String> roiRanges;
  final List<String> marketStatus;
  final List<String> propertyTypes;
  final List<String> timelines;

  const PropertyRecommendationsScreen({
    super.key,
    required this.location,
    required this.crimeRates,
    required this.roiRanges,
    required this.marketStatus,
    required this.propertyTypes,
    required this.timelines,
  });

  @override
  State<PropertyRecommendationsScreen> createState() => _PropertyRecommendationsScreenState();
}

class _PropertyRecommendationsScreenState extends State<PropertyRecommendationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _properties = [];
  String? _error;
  int? _selectedProperty;
  String _aiSummaryText = '';

  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.searchProperties(
        location: widget.location,
        crimeRates: widget.crimeRates,
        roiRanges: widget.roiRanges,
        marketStatus: widget.marketStatus,
        propertyTypes: widget.propertyTypes,
        timelines: widget.timelines,
      );
      final props = (data['properties'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _aiSummaryText = data['ai_summary']?.toString() ?? '';
        _properties = props.map((p) => {
          'zpid': p['zpid']?.toString() ?? '',
          'address': p['address'] ?? '',
          'price': p['price'] ?? 0,
          'beds': p['beds'] ?? 0,
          'baths': p['baths'] ?? 0,
          'sqft': p['sqft'] ?? 0,
          'img': p['img'] ?? '',
          'roi': p['roi_estimate']?.toString() ?? '0',
          'crime': p['crime_level'] ?? 'Unknown',
          'schools': p['school_rating'] ?? 'N/A',
          'trend': p['market_trend'] ?? 'Stable',
          'lat': p['lat'] ?? 0.0,
          'lng': p['lng'] ?? 0.0,
        }).toList().cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _aiSummary()),
        if (_loading)
          const SliverFillRemaining(child: Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50))))
        else if (_error != null)
          SliverFillRemaining(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _fetchProperties,
                style: ElevatedButton.styleFrom(backgroundColor: _green),
                child: const Text('Retry', style: TextStyle(color: Colors.white))),
          ])))
        else ...[
          SliverToBoxAdapter(child: _mapCard()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _propertyCard(_properties[i], i),
              childCount: _properties.length,
            )),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ]),
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
      GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PropertyPastSuggestionsScreen())),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _green.withOpacity(0.2), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.4))),
            child: const Text('History', style: TextStyle(color: _greenLight, fontSize: 12, fontWeight: FontWeight.w600))),
      ),
    ]),
  );

  Widget _aiSummary() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF243040),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Text(
            'Based on ${widget.crimeRates.isNotEmpty ? "low crime" : "your criteria"}, '
            '${widget.roiRanges.isNotEmpty ? "${widget.roiRanges.first} ROI target" : "high returns"}, '
            'and high rental demand, here are the top neighborhoods in ${widget.location} for ROI.',
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5))),
      ]),
    ),
  );

  Widget _mapCard() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      height: 220,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withOpacity(0.3))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          // Map placeholder — replace with google_maps_flutter widget
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1B3A2F), Color(0xFF243040)])),
          ),
          // Grid lines to simulate map
          CustomPaint(painter: _MapGridPainter(), size: Size.infinite),
          // Location pins
          ..._properties.take(3).toList().asMap().entries.map((e) {
            final offsets = [
              const Offset(0.55, 0.35),
              const Offset(0.45, 0.6),
              const Offset(0.7, 0.55),
            ];
            if (e.key >= offsets.length) return const SizedBox();
            return Positioned(
              left: MediaQuery.of(context).size.width * offsets[e.key].dx - 60,
              top: 220 * offsets[e.key].dy - 30,
              child: _mapPin(e.value['address'].toString().split(',').first,
                  '${e.value['roi']}% ROI', e.key == 0),
            );
          }),
          // Map label
          Positioned(top: 12, left: 12,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Investment Hotspots',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
        ]),
      ),
    ),
  );

  Widget _mapPin(String name, String roi, bool isTop) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: isTop ? _green : const Color(0xFF243040),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _greenLight.withOpacity(0.5))),
      child: Column(children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        Text(roi, style: TextStyle(color: isTop ? Colors.white : _greenLight, fontSize: 9)),
      ]),
    ),
    Container(width: 2, height: 8, color: _greenLight),
    Container(width: 8, height: 8, decoration: BoxDecoration(color: _greenLight, shape: BoxShape.circle)),
  ]);

  Widget _propertyCard(Map<String, dynamic> p, int index) {
    final isSelected = _selectedProperty == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedProperty = isSelected ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF243040),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? _greenLight : _green.withOpacity(0.25),
                width: isSelected ? 1.5 : 1)),
        child: Row(children: [
          // Property image
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                color: _green.withOpacity(0.2)),
            child: p['img'].toString().isNotEmpty
                ? ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    child: Image.network(p['img'], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _propertyPlaceholder()))
                : _propertyPlaceholder(),
          ),
          // Property details
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['address'], style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                _statChip('ROI: ${p['roi']}%', _greenLight),
                const SizedBox(width: 6),
                _statChip('Crime: ${p['crime']}', Colors.blue.shade300),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _statChip('Schools: ${p['schools']}', Colors.orange.shade300),
                const SizedBox(width: 6),
                _statChip('${p['trend']}', Colors.purple.shade300),
              ]),
              const SizedBox(height: 8),
              if (p['price'] > 0)
                Text('\$${_fmtPrice(p['price'])}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          )),
          // Save button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _saveProperty(p),
              child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: isSelected ? _green : _green.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(isSelected ? Icons.bookmark : Icons.bookmark_outline,
                      color: _greenLight, size: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _propertyPlaceholder() => Center(child: Icon(
      Icons.home_outlined, color: _greenLight.withOpacity(0.5), size: 32));

  Widget _statChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)));

  String _fmtPrice(dynamic price) {
    final n = double.tryParse(price.toString()) ?? 0;
    if (n >= 1e6) return '${(n/1e6).toStringAsFixed(2)}M';
    if (n >= 1e3) return '${(n/1e3).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }

  void _saveProperty(Map<String, dynamic> p) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved ${p['address']} to suggestions'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating));
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for (int i = 0; i < 10; i++) {
      canvas.drawLine(Offset(size.width * i / 10, 0), Offset(size.width * i / 10, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 10), Offset(size.width, size.height * i / 10), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}
