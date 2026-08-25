import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:city_water_works_app/l10n/app_localizations.dart';
import '../../core/database/daos/settings_dao.dart';
import '../../core/database/daos/machinery_types_dao.dart';
import '../../core/database/daos/users_dao.dart';
import '../../core/models/machinery_type.dart';
import '../../core/services/backup_service.dart';
import '../backup/backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final ValueChanged<String>? onLanguageChanged;
  final VoidCallback? onLogout;
  final ValueChanged<String>? onAppNameChanged;
  final VoidCallback? onDataRestored;
  final String? currentUsername;

  const SettingsScreen({
    super.key,
    this.onThemeChanged,
    this.onLanguageChanged,
    this.onLogout,
    this.onAppNameChanged,
    this.onDataRestored,
    this.currentUsername,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final _settingsDao = SettingsDao();
  final _typesDao = MachineryTypesDao();
  final _usersDao = UsersDao();
  final _backupService = BackupService();

  bool _darkMode = true;
  bool _autoBackup = false;
  bool _isLoading = true;
  String _appName = 'Water Supply Scheme History';
  String _appLanguage = 'english';

  List<MachineryType> _machineryTypes = [];

  List<String> _miscItems = [
    'Leakage',
    'Pipes',
    'Electric',
    'Valves',
  ];

  Color get _pageBg => _darkMode ? const Color(0xFF0D1117) : Colors.white;
  Color get _surface => _darkMode ? const Color(0xFF161B22) : const Color(0xFFF7F8FA);
  Color get _outline => _darkMode ? const Color(0xFF30363D) : const Color(0xFFD8DDE6);
  Color get _textPrimary => _darkMode ? const Color(0xFFE6EDF3) : const Color(0xFF111827);
  Color get _textSecondary => _darkMode ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

  late AnimationController _headerAnim;
  late AnimationController _listAnim;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

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

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final darkMode = await _settingsDao.getSetting('dark_mode');
    final autoBackup = await _settingsDao.getSetting('auto_backup');
    final appLanguage = await _settingsDao.getSetting('app_language');
    final appDisplayName = await _settingsDao.getSetting('app_display_name');
    final miscItemsRaw = await _settingsDao.getSetting('misc_items_json');
    final types = await _typesDao.getAllTypes();

    if (!mounted) return;
    setState(() {
      _darkMode = darkMode == 'true';
      _autoBackup = autoBackup == 'true';
        _appLanguage = (appLanguage == null || appLanguage.trim().isEmpty)
          ? 'english'
          : appLanguage.trim().toLowerCase();
      _appName = (appDisplayName == null || appDisplayName.trim().isEmpty)
          ? 'Water Supply Scheme History'
          : appDisplayName.trim();
      if (miscItemsRaw != null && miscItemsRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(miscItemsRaw);
          if (decoded is List) {
            _miscItems = decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          }
        } catch (_) {}
      }
      _machineryTypes = types;
      _isLoading = false;
    });
  }

  Future<void> _persistMiscItems() async {
    await _settingsDao.setSetting('misc_items_json', jsonEncode(_miscItems));
  }

  Future<void> _addMiscItem() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Add Miscellaneous Type', style: TextStyle(color: _textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            labelText: 'Type Name',
            labelStyle: TextStyle(color: _textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (_miscItems.any((e) => e.toLowerCase() == result.toLowerCase())) return;
      setState(() => _miscItems.add(result));
      await _persistMiscItems();
    }
  }

  Future<void> _deleteMiscItem(int index) async {
    final item = _miscItems[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Delete Type', style: TextStyle(color: _textPrimary)),
        content: Text('Delete miscellaneous type "$item"?', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _miscItems.removeAt(index));
      await _persistMiscItems();
    }
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await _settingsDao.setSetting('dark_mode', value.toString());
    widget.onThemeChanged?.call();
  }

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() => _autoBackup = value);
    await _settingsDao.setSetting('auto_backup', value.toString());
  }

  Future<void> _setAppLanguage(String value) async {
    final normalized = value.toLowerCase();
    setState(() => _appLanguage = normalized);
    await _settingsDao.setSetting('app_language', normalized);
    widget.onLanguageChanged?.call(normalized);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(normalized == 'urdu' ? l10n.languageSetUrdu : l10n.languageSetEnglish)),
    );
  }

  Future<void> _addMachineryType() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Add Machinery Type',
            style: TextStyle(color: Color(0xFFE6EDF3))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE6EDF3)),
          decoration: const InputDecoration(
            labelText: 'Type Name',
            labelStyle: TextStyle(color: Color(0xFF8B949E)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _typesDao.insertType(MachineryType(typeName: result, attributes: []));
      await _loadSettings();
    }
  }

  Future<void> _deleteMachineryType(MachineryType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Delete Type',
            style: TextStyle(color: Color(0xFFE6EDF3))),
        content: Text(
          'Delete machinery type "${type.typeName}"?',
          style: const TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _typesDao.deleteType(type.typeId!);
      await _loadSettings();
    }
  }

  Future<void> _editAppName() async {
    final ctrl = TextEditingController(text: _appName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Edit App Name',
            style: TextStyle(color: Color(0xFFE6EDF3))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE6EDF3)),
          decoration: const InputDecoration(
            labelText: 'Application Name',
            labelStyle: TextStyle(color: Color(0xFF8B949E)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _settingsDao.setSetting('app_display_name', result);
      if (!mounted) return;
      setState(() => _appName = result);
      widget.onAppNameChanged?.call(result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App name updated')),
      );
    }
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _backupService.deleteAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted successfully')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _changePassword() async {
    final username = widget.currentUsername;
    if (username == null || username.trim().isEmpty) return;

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Change Password',
            style: TextStyle(color: Color(0xFFE6EDF3))),
        content: SizedBox(
          width: math.min(420.0, MediaQuery.of(ctx).size.width * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text || newCtrl.text.length < 6) {
                return;
              }
              final ok = await _usersDao.changePassword(
                username: username,
                currentPassword: currentCtrl.text,
                newPassword: newCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx, ok);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password updated successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _pageBg,
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
                  label: l10n.appearanceLabel,
                  index: 0,
                  children: [
                    _buildToggleTile(
                      icon: Icons.dark_mode_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: l10n.darkModeTitle,
                      subtitle: l10n.darkModeSubtitle,
                      value: _darkMode,
                      onChanged: _toggleDarkMode,
                    ),
                    _buildDivider(),
                    _buildLanguageTile(l10n),
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
                      onChanged: _toggleAutoBackup,
                    ),
                    _buildDivider(),
                    _buildNavTile(
                      icon: Icons.history_rounded,
                      iconColor: const Color(0xFF3FB950),
                      title: 'Backup & Restore',
                      subtitle: 'Manage your data backups',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BackupScreen(onDataRestored: widget.onDataRestored)),
                      ),
                    ),
                    _buildDivider(),
                    _buildNavTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: const Color(0xFFFF4444),
                      title: 'Delete All Data',
                      subtitle: 'Permanently remove all records',
                      titleColor: const Color(0xFFFF4444),
                      onTap: _deleteAllData,
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
                      subtitle: 'User: ${widget.currentUsername ?? 'admin'}',
                      onTap: _changePassword,
                    ),
                    _buildDivider(),
                    _buildNavTile(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFFF4444),
                      title: 'Logout',
                      subtitle: 'Sign out and return to login',
                      titleColor: const Color(0xFFFF4444),
                      onTap: widget.onLogout ?? () {},
                      isDanger: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMachinerySection(),
                const SizedBox(height: 12),
                _buildMiscellaneousSection(),
                const SizedBox(height: 12),
                _buildAboutSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: _pageBg,
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
              Positioned.fill(child: _GridPainter()),
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
                        Text(
                          l10n.settingsHeading,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          l10n.settingsSubheading,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
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
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00D4FF),
                letterSpacing: 2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outline, width: 1),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

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
                Text(title,
                  style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                    color: _textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: TextStyle(fontSize: 12, color: _textSecondary)),
              ],
            ),
          ),
          _PremiumSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconBadge(icon: icon, color: iconColor, isDanger: isDanger),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                        color: titleColor ?? _textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B949E), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const _IconBadge(icon: Icons.language_rounded, color: Color(0xFF3FB950)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsLanguage,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settingsLanguageSubtitle,
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'english', label: Text(l10n.languageEnglish)),
                    ButtonSegment(value: 'urdu', label: Text(l10n.languageUrdu)),
                  ],
                  selected: {_appLanguage},
                  onSelectionChanged: (v) => _setAppLanguage(v.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachinerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
          child: Row(
            children: [
              const Text('MACHINERY TYPES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00D4FF),
                      letterSpacing: 2)),
              const Spacer(),
              IconButton(
                onPressed: _addMachineryType,
                icon: const Icon(Icons.add_circle, color: Color(0xFF00D4FF)),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _machineryTypes.length,
            separatorBuilder: (_, __) => _buildDivider(),
            itemBuilder: (context, i) {
              final type = _machineryTypes[i];
              return ListTile(
                leading: const Icon(Icons.precision_manufacturing, color: Color(0xFF00D4FF)),
                title: Text(type.typeName,
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('${type.attributes.length} attributes',
                  style: TextStyle(color: _textSecondary)),
                trailing: IconButton(
                  onPressed: () => _deleteMachineryType(type),
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8B949E)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiscellaneousSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 0, 10),
          child: Row(
            children: [
              const Text('MISCELLANEOUS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00D4FF),
                      letterSpacing: 2)),
              const Spacer(),
              IconButton(
                onPressed: _addMiscItem,
                icon: const Icon(Icons.add_circle, color: Color(0xFF00D4FF)),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _miscItems.length,
            separatorBuilder: (_, __) => _buildDivider(),
            itemBuilder: (context, i) {
              return ListTile(
                leading: const Icon(Icons.category_outlined, color: Color(0xFF3FB950)),
                title: Text(_miscItems[i],
                    style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  onPressed: () => _deleteMiscItem(i),
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8B949E)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 0, 10),
          child: Text('ABOUT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00D4FF),
                  letterSpacing: 2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline, width: 1),
          ),
          child: ListTile(
            leading: const Icon(Icons.water_drop, color: Color(0xFF00D4FF)),
            title: Text(_appName,
                style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text('Machinery Billing & Record Management',
                style: TextStyle(color: _textSecondary)),
            trailing: IconButton(
              onPressed: _editAppName,
              icon: const Icon(Icons.edit, color: Color(0xFF00D4FF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
      color: _outline.withOpacity(0.5),
      );
}

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
      begin: Colors.white,
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
                  color: widget.value ? const Color(0xFF0D1117) : const Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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