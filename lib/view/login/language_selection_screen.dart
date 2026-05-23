import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/login/onboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final bool isFirstLaunch;
  const LanguageSelectionScreen({super.key, this.isFirstLaunch = false});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguageCode;

  final List<Map<String, String>> _languages = [
    {'name': 'English',  'native': 'English',        'code': 'en'},
    {'name': 'Hindi',    'native': 'हिन्दी',           'code': 'hi'},
    {'name': 'Gujarati', 'native': 'ગુજરાતી',          'code': 'gu'},
    {'name': 'Marathi',  'native': 'मराठी',            'code': 'mr'},
    {'name': 'Bengali',  'native': 'বাংলা',            'code': 'bn'},
    {'name': 'Tamil',    'native': 'தமிழ்',            'code': 'ta'},
    {'name': 'Telugu',   'native': 'తెలుగు',           'code': 'te'},
    {'name': 'Punjabi',  'native': 'ਪੰਜਾਬੀ',           'code': 'pa'},
    {'name': 'Urdu',     'native': 'اردو',             'code': 'ur'},
    {'name': 'Sindhi',   'native': 'سنڌي / सिन्धी',   'code': 'sd'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  void _loadCurrentLanguage() {
    final code = FlutterLocalization.instance.currentLocale?.languageCode ?? 'en';
    setState(() => _selectedLanguageCode = code);
  }

  Future<void> _onLanguageSelected(String code) async {
    setState(() => _selectedLanguageCode = code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    await prefs.setBool('is_language_selected', true);
    if (mounted) FlutterLocalization.instance.translate(code);
  }

  Future<void> _handleProceed() async {
    if (_selectedLanguageCode == null) return;
    if (widget.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _Header(isFirstLaunch: widget.isFirstLaunch),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.45,
              ),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final isSelected = _selectedLanguageCode == lang['code'];
                return _LanguageCard(
                  name: lang['name']!,
                  native: lang['native']!,
                  isSelected: isSelected,
                  onTap: () => _onLanguageSelected(lang['code']!),
                );
              },
            ),
          ),
          _ProceedButton(
            label: widget.isFirstLaunch ? 'Proceed' : 'Save',
            enabled: _selectedLanguageCode != null,
            onTap: _handleProceed,
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isFirstLaunch;
  const _Header({required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, Color(0xFF1B8C1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              if (!isFirstLaunch)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.language_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Your Language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your preferred language\nto personalise your experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Language Card ─────────────────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  final String name;
  final String native;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.name,
    required this.native,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 0 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? primaryColor.withOpacity(0.30)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative letter in background
            Positioned(
              right: -6,
              bottom: -10,
              child: Text(
                native.characters.first,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? Colors.white.withOpacity(0.12)
                      : primaryColor.withOpacity(0.06),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    native,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withOpacity(0.75)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            // Check badge
            if (isSelected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: primaryColor, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Proceed Button ────────────────────────────────────────────────────────────

class _ProceedButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ProceedButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [primaryColor, Color(0xFF1B8C1E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.grey.shade400,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
