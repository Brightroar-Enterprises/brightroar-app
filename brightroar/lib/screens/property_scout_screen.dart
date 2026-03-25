import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'property_recommendations_screen.dart';
import 'property_past_suggestions_screen.dart';
import 'property_chat_screen.dart';
import 'property_portfolio_screen.dart';

class PropertyScoutScreen extends StatefulWidget {
  const PropertyScoutScreen({super.key});
  @override
  State<PropertyScoutScreen> createState() => _PropertyScoutScreenState();
}

class _PropertyScoutScreenState extends State<PropertyScoutScreen> {
  // Selected criteria
  final Set<String> _crimeRates = {};
  final Set<String> _roiRanges = {};
  final Set<String> _marketStatus = {};
  final Set<String> _propertyTypes = {};
  final Set<String> _timelines = {};
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  // Quick tags
  final List<String> _quickTags = ['Austin, TX', 'High Yield', 'Emerging Markets', 'Miami, FL', 'Low Risk'];

  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFF4CAF50);

  @override
  void dispose() {
    _locationCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSet(Set<String> set, String val) =>
      setState(() => set.contains(val) ? set.remove(val) : set.add(val));

  bool get _canSearch =>
      _locationCtrl.text.isNotEmpty &&
      (_crimeRates.isNotEmpty || _roiRanges.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _aiMessage(),
            const SizedBox(height: 20),
            _navButtons(),
            const SizedBox(height: 20),
            _locationInput(),
            const SizedBox(height: 20),
            _criteriaSection('1. Max Crime Rate', 'Select all that apply',
                ['Low', 'Medium-Low', 'Medium', 'Medium-High'], _crimeRates),
            const SizedBox(height: 16),
            _criteriaSection('2. Target ROI', 'Select multiple ranges',
                ['5-7%', '7-9%', '9-11%', '>11%'], _roiRanges),
            const SizedBox(height: 16),
            _criteriaSection('3. Market Status', 'Select all applicable',
                ['Emerging', 'Stable', 'Declining', 'Gentrifying'], _marketStatus),
            const SizedBox(height: 16),
            _criteriaSection('4. Property Type', 'Select all options',
                ['Single-Family', 'Condo', 'Townhouse', 'Multi-Family'], _propertyTypes),
            const SizedBox(height: 16),
            _criteriaSection('5. Investment Timeline', 'Select all target periods',
                ['<3 Years', '3-5 Years', '5-7 Years', '>7 Years'], _timelines),
            const SizedBox(height: 20),
            _quickTagsRow(),
            const SizedBox(height: 24),
            _searchButton(),
            const SizedBox(height: 32),
          ])),
        ),
      ]),
      bottomNavigationBar: _searchBar(),
    );
  }


  Widget _navButtons() {
    final buttons = [
      {'icon': Icons.search, 'label': 'Find\nLocations', 'desc': 'Search Setup', 'active': true},
      {'icon': Icons.recommend_outlined, 'label': 'Recommendations', 'desc': 'Results', 'screen': 'reco'},
      {'icon': Icons.history_outlined, 'label': 'Performance\nHistory', 'desc': 'Past Picks', 'screen': 'history'},
      {'icon': Icons.account_balance_outlined, 'label': 'Portfolio\nDashboard', 'desc': 'Screen 4', 'screen': 'portfolio'},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Access', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      Row(children: buttons.asMap().entries.map((e) {
        final b = e.value;
        final isActive = b['active'] == true;
        return Expanded(child: GestureDetector(
          onTap: () {
            final screen = b['screen'];
            if (screen == 'reco') {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PropertyRecommendationsScreen(
                    location: _locationCtrl.text.isNotEmpty ? _locationCtrl.text : 'Austin, TX',
                    crimeRates: _crimeRates.toList(),
                    roiRanges: _roiRanges.toList(),
                    marketStatus: _marketStatus.toList(),
                    propertyTypes: _propertyTypes.toList(),
                    timelines: _timelines.toList(),
                  )));
            } else if (screen == 'history') {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PropertyPastSuggestionsScreen()));
            } else if (screen == 'portfolio') {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PropertyPortfolioScreen()));
            }
          },
          child: Container(
            margin: EdgeInsets.only(right: e.key < buttons.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: isActive ? _green.withOpacity(0.25) : const Color(0xFF243040),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? _greenLight.withOpacity(0.6) : Colors.white.withOpacity(0.1),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(b['icon'] as IconData,
                  color: isActive ? _greenLight : Colors.white54, size: 20),
              const SizedBox(height: 5),
              Text(b['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isActive ? Colors.white : Colors.white54,
                      fontSize: 10, fontWeight: FontWeight.w600, height: 1.2)),
              const SizedBox(height: 3),
              Text(b['desc'] as String,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8)),
            ]),
          ),
        ));
      }).toList()),
    ]);
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle,
              border: Border.all(color: _greenLight.withOpacity(0.4))),
          child: const Icon(Icons.home_work_outlined, color: _greenLight, size: 18)),
      const SizedBox(width: 10),
      const Text('Property Scout AI', style: TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      const Spacer(),
      Icon(Icons.more_vert, color: Colors.white.withOpacity(0.6)),
    ]),
  );

  Widget _aiMessage() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: const Color(0xFF243040),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withOpacity(0.3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _green.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.psychology_outlined, color: _greenLight, size: 18)),
      const SizedBox(width: 12),
      const Expanded(child: Text(
          'Tell me about your investment goals. What criteria are most important to you?',
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
    ]),
  );

  Widget _locationInput() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
        color: const Color(0xFF243040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.location_on_outlined, color: _greenLight, size: 18),
      const SizedBox(width: 10),
      Expanded(child: TextField(
          controller: _locationCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
              hintText: 'Enter city, state (e.g. Austin, TX)',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none))),
    ]),
  );

  Widget _criteriaSection(String title, String subtitle, List<String> options, Set<String> selected) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        TextSpan(text: ' ($subtitle)', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ])),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => _toggleSet(selected, opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: isSelected ? _green : const Color(0xFF243040),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? _greenLight : Colors.white24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isSelected) ...[
                const Icon(Icons.check, color: Colors.white, size: 13),
                const SizedBox(width: 4),
              ],
              Text(opt, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]),
          ),
        );
      }).toList()),
    ]);
  }

  Widget _quickTagsRow() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: _quickTags.map((tag) => GestureDetector(
      onTap: () {
        if (['Austin, TX', 'Miami, FL'].contains(tag)) {
          _locationCtrl.text = tag;
          setState(() {});
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFF243040),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24)),
        child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 13))),
    )).toList()),
  );

  Widget _searchButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _canSearch ? () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PropertyRecommendationsScreen(
            location: _locationCtrl.text,
            crimeRates: _crimeRates.toList(),
            roiRanges: _roiRanges.toList(),
            marketStatus: _marketStatus.toList(),
            propertyTypes: _propertyTypes.toList(),
            timelines: _timelines.toList(),
          ))) : null,
      style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: _green.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.search, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text('Find Best Locations', style: TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _searchBar() => Container(
    color: const Color(0xFF1A2332),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF243040),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 18),
        const SizedBox(width: 10),
        Expanded(child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
                hintText: 'Search neighborhoods, cities...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none))),
        Icon(Icons.mic_outlined, color: Colors.white.withOpacity(0.4), size: 18),
      ]),
    ),
  );
}
