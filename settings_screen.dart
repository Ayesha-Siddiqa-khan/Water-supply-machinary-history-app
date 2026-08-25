import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MachinerySettingsApp());
}

// ─── APP ───────────────────────────────────────────────────────────────────
class MachinerySettingsApp extends StatelessWidget {
  const MachinerySettingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SettingsScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF00D4FF),
        secondary: const Color(0xFFFF6B35),
        surface: const Color(0xFF0D1117),
        surfaceContainerHighest: const Color(0xFF161B22),
        error: const Color(0xFFFF4444),
        onPrimary: const Color(0xFF0D1117),
        onSurface: const Color(0xFFE6EDF3),
        outline: const Color(0xFF30363D),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1117),
    );
  }
}

// ─── SCREEN ────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _darkMode = true;
  bool _autoBackup = false;

  late AnimationController _headerAnim;
  late AnimationController _listAnim;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  final List<MachineryType> _machineryTypes = [
    MachineryType(name: 'Motor', attributes: 3, icon: Icons.electric_bolt),
    MachineryType(name: 'Pump', attributes: 2, icon: Icons.water_drop),
    MachineryType(name: 'Transformer', attributes: 2, icon: Icons.bolt),
    MachineryType(name: 'Turbine', attributes: 2, icon: Icons.wind_power),
  ];

  @override
  void initState() {
    super.initState();

    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _listAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      _headerAnim.forward();
      _listAnim.forward();
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildSection(
                  label: 'APPEARANCE',
                  index: 0,
                  children: [
                    _buildToggleTile(
                      icon: Icons.dark_mode_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Dark Mode',
                      subtitle: 'Switch between light and dark theme',
                      value: _darkMode,
                      onChanged: (v) => setState(() => _darkMode = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSection(
                  label: 'DATA MANAGEMENT',
                  index: 1,
                  children: [
                    _buildToggleTile(
                      icon: Icons.cloud_upload_rounded,
                      iconColor: const Color(0xFF00D4FF),
                      title: 'Auto Backup',
                      subtitle: 'Automatically backup data weekly',
                      value: _autoBackup,
                      onChanged: (v) => setState(() => _autoBackup = v),
                    ),
                    _buildDivider(),
                    _buildNavTile(
                      icon: Icons.history_rounded,
                      iconColor: const Color(0xFF3FB950),
                      title: 'Backup & Restore',
                      subtitle: 'Manage your data backups',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: const Color(0xFFFF4444),
                      title: 'Delete All Data',
                      subtitle: 'Permanently remove all records',
                      titleColor: const Color(0xFFFF4444),
                      onTap: () => _showDeleteDialog(),
                      isDanger: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSection(
                  label: 'ACCOUNT',
                  index: 2,
                  children: [
                    _buildNavTile(
                      icon: Icons.lock_rounded,
                      iconColor: const Color(0xFFFF9500),
                      title: 'Change Password',
                      subtitle: 'User: admin',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildNavTile(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFFF4444),
                      title: 'Logout',
                      subtitle: 'Sign out and return to login',
                      titleColor: const Color(0xFFFF4444),
                      onTap: () {},
                      isDanger: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMachinerySection(),
                const SizedBox(height: 12),
                _buildAboutSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF0D1117),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161B22), Color(0xFF0D1117)],
            ),
          ),
          child: Stack(
            children: [
              // Grid pattern
              Positioned.fill(child: _GridPainter()),
              // Glowing orb
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00D4FF).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Title
              Positioned(
                bottom: 16,
                left: 20,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF00D4FF),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE6EDF3),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            'System Configuration',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF8B949E),
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SECTION WRAPPER ─────────────────────────────────────────────────────
  Widget _buildSection({
    required String label,
    required int index,
    required List<Widget> children,
  }) {
    return AnimatedBuilder(
      animation: _listAnim,
      builder: (context, child) {
        final delay = index * 0.15;
        final progress = math.max(
          0.0,
          math.min(1.0, (_listAnim.value - delay) / (1 - delay)),
        );
        return Opacity(
          opacity: Curves.easeOut.transform(progress),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - Curves.easeOut.transform(progress))),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 1,
                  color: const Color(0xFF00D4FF).withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00D4FF),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF30363D),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // ── TOGGLE TILE ─────────────────────────────────────────────────────────
  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE6EDF3),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ),
          _PremiumSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── NAV TILE ────────────────────────────────────────────────────────────
  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: isDanger
            ? const Color(0xFFFF4444).withOpacity(0.08)
            : const Color(0xFF00D4FF).withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconBadge(
                icon: icon,
                color: iconColor,
                isDanger: isDanger,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? const Color(0xFFE6EDF3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDanger
                    ? const Color(0xFFFF4444).withOpacity(0.5)
                    : const Color(0xFF8B949E),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MACHINERY SECTION ───────────────────────────────────────────────────
  Widget _buildMachinerySection() {
    return AnimatedBuilder(
      animation: _listAnim,
      builder: (context, child) {
        final progress = math.max(0.0, math.min(1.0, (_listAnim.value - 0.45) / 0.55));
        return Opacity(
          opacity: Curves.easeOut.transform(progress),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - Curves.easeOut.transform(progress))),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 1,
                  color: const Color(0xFF00D4FF).withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MACHINERY TYPES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00D4FF),
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddMachineryDialog,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Color(0xFF0D1117),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _machineryTypes.length,
              separatorBuilder: (_, __) => _buildDivider(),
              itemBuilder: (context, i) => _buildMachineryTile(_machineryTypes[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineryTile(MachineryType m, int index) {
    final colors = [
      const Color(0xFF00D4FF),
      const Color(0xFF3FB950),
      const Color(0xFFFF9500),
      const Color(0xFF7C3AED),
    ];
    final color = colors[index % colors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(m.icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE6EDF3),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${m.attributes} attributes',
                      style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _machineryTypes.removeAt(
                    _machineryTypes.indexOf(m))),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: const Color(0xFF8B949E),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ABOUT SECTION ───────────────────────────────────────────────────────
  Widget _buildAboutSection() {
    return AnimatedBuilder(
      animation: _listAnim,
      builder: (context, child) {
        final progress = math.max(0.0, math.min(1.0, (_listAnim.value - 0.6) / 0.4));
        return Opacity(
          opacity: Curves.easeOut.transform(progress),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
            child: Row(
              children: [
                Container(width: 20, height: 1,
                    color: const Color(0xFF00D4FF).withOpacity(0.5)),
                const SizedBox(width: 8),
                const Text('ABOUT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF00D4FF), letterSpacing: 2)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D), width: 1),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.precision_manufacturing_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MachineryOS',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: Color(0xFFE6EDF3))),
                      const SizedBox(height: 2),
                      Text('Version 2.4.1 · Build 2024.12',
                          style: const TextStyle(fontSize: 12,
                              color: Color(0xFF8B949E))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF3FB950).withOpacity(0.3), width: 1),
                  ),
                  child: const Text('Up to date',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3FB950),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────
  Widget _buildDivider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFF30363D).withOpacity(0.5),
      );

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF4444), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4444)),
            SizedBox(width: 8),
            Text('Delete All Data', style: TextStyle(color: Color(0xFFFF4444))),
          ],
        ),
        content: const Text(
          'This will permanently remove all records. This action cannot be undone.',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddMachineryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF30363D), width: 1),
        ),
        title: const Text('Add Machinery Type',
            style: TextStyle(color: Color(0xFFE6EDF3))),
        content: const Text('Feature coming soon.',
            style: TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );
  }
}

// ─── CUSTOM SWITCH ─────────────────────────────────────────────────────────
class _PremiumSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PremiumSwitch({required this.value, required this.onChanged});

  @override
  State<_PremiumSwitch> createState() => _PremiumSwitchState();
}

class _PremiumSwitchState extends State<_PremiumSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<Color?> _trackColor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.value ? 1.0 : 0.0,
    );
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _trackColor = ColorTween(
      begin: const Color(0xFF30363D),
      end: const Color(0xFF00D4FF),
    ).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_PremiumSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Container(
          width: 50,
          height: 28,
          decoration: BoxDecoration(
            color: _trackColor.value,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.value
                ? [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Align(
              alignment: Alignment.lerp(
                Alignment.centerLeft,
                Alignment.centerRight,
                _slide.value,
              )!,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.value ? const Color(0xFF0D1117) : const Color(0xFF8B949E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ICON BADGE ────────────────────────────────────────────────────────────
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDanger;

  const _IconBadge({
    required this.icon,
    required this.color,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ─── GRID BACKGROUND PAINTER ───────────────────────────────────────────────
class _GridPainter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainterDelegate());
  }
}

class _GridPainterDelegate extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── DATA MODEL ────────────────────────────────────────────────────────────
class MachineryType {
  final String name;
  final int attributes;
  final IconData icon;

  MachineryType({
    required this.name,
    required this.attributes,
    required this.icon,
  });
}
