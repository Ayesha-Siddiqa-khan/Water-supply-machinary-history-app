import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/app_database.dart';
import 'core/database/daos/settings_dao.dart';
import 'core/database/daos/users_dao.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/schemes/schemes_list_screen.dart';
import 'features/import/import_screen.dart';
import 'features/export/export_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/miscellaneous/miscellaneous_screen.dart';
import 'features/useless_items/useless_items_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AppDatabase.instance.database;
  await UsersDao().ensureDefaultUser();

  final settingsDao = SettingsDao();
  final darkModePref = await settingsDao.getSetting('dark_mode');
  final isDarkMode = darkModePref == 'true';
  final appLanguage = await settingsDao.getSetting('app_language');
  final rememberMe = await settingsDao.getSetting('remember_me');
  final rememberedUser = await settingsDao.getSetting('logged_in_user');

  final startAuthenticated = (rememberMe == 'true') && (rememberedUser?.trim().isNotEmpty == true);

  runApp(CityWaterWorksApp(
    isDarkMode: isDarkMode,
    initialLanguage: (appLanguage == null || appLanguage.trim().isEmpty)
        ? 'english'
        : appLanguage.trim().toLowerCase(),
    isAuthenticated: startAuthenticated,
    currentUsername: startAuthenticated ? rememberedUser?.trim() : null,
  ));
}

class CityWaterWorksApp extends StatefulWidget {
  final bool isDarkMode;
  final String initialLanguage;
  final bool isAuthenticated;
  final String? currentUsername;
  const CityWaterWorksApp({
    super.key,
    this.isDarkMode = false,
    this.initialLanguage = 'english',
    this.isAuthenticated = false,
    this.currentUsername,
  });

  static _CityWaterWorksAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_CityWaterWorksAppState>();
  }

  @override
  State<CityWaterWorksApp> createState() => _CityWaterWorksAppState();
}

class _CityWaterWorksAppState extends State<CityWaterWorksApp> {
  late bool _isDarkMode;
  late String _appLanguage;
  late bool _isAuthenticated;
  String? _currentUsername;
  final _settingsDao = SettingsDao();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _appLanguage = widget.initialLanguage;
    _isAuthenticated = widget.isAuthenticated;
    _currentUsername = widget.currentUsername;
  }

  Locale _localeFromLanguage(String language) {
    return language == 'urdu' ? const Locale('ur') : const Locale('en');
  }

  Future<void> _handleLoginSuccess(String username, bool rememberMe) async {
    await _settingsDao.setSettings({
      'remember_me': rememberMe.toString(),
      'logged_in_user': rememberMe ? username : '',
    });

    if (!mounted) return;
    setState(() {
      _isAuthenticated = true;
      _currentUsername = username;
    });
  }

  Future<void> _logout() async {
    await _settingsDao.setSettings({
      'remember_me': 'false',
      'logged_in_user': '',
    });

    if (!mounted) return;
    setState(() {
      _isAuthenticated = false;
      _currentUsername = null;
    });
  }

  void toggleTheme() async {
    final settingsDao = SettingsDao();
    final pref = await settingsDao.getSetting('dark_mode');
    setState(() => _isDarkMode = pref == 'true');
  }

  void setLanguage(String language) {
    setState(() => _appLanguage = language.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Water Supply Scheme History',
      debugShowCheckedModeBanner: false,
      locale: _localeFromLanguage(_appLanguage),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _isAuthenticated
          ? AppShell(
              currentUsername: _currentUsername,
              onLogout: _logout,
            )
          : LoginScreen(
              onLoginSuccess: _handleLoginSuccess,
            ),
    );
  }
}

class AppShell extends StatefulWidget {
  final String? currentUsername;
  final VoidCallback? onLogout;
  const AppShell({super.key, this.currentUsername, this.onLogout});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  static const _shellBg = Color(0xFF0A0F1E);
  static const _surface = Color(0xFF111A2F);
  static const _surfaceSoft = Color(0xFF16233C);
  static const _border = Color(0x33FFFFFF);
  static const _accent = Color(0xFF60A5FA);
  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textSecondary = Color(0x99E2E8F0);
  final _settingsDao = SettingsDao();
  String _appDisplayName = 'Water Supply Scheme History';

  @override
  void initState() {
    super.initState();
    _loadAppName();
  }

  Future<void> _loadAppName() async {
    final savedName = await _settingsDao.getSetting('app_display_name');
    if (!mounted) return;
    setState(() {
      _appDisplayName =
          (savedName == null || savedName.trim().isEmpty) ? 'Water Supply Scheme History' : savedName.trim();
    });
  }

  List<_NavItem> _navItems(AppLocalizations l10n) => [
        _NavItem(icon: Icons.dashboard, label: l10n.navDashboard),
        _NavItem(icon: Icons.business, label: l10n.navSchemes),
        _NavItem(icon: Icons.delete_sweep_outlined, label: l10n.navUselessItems),
        _NavItem(icon: Icons.category_outlined, label: l10n.navMiscellaneous),
        _NavItem(icon: Icons.upload_file, label: l10n.navImport),
        _NavItem(icon: Icons.download, label: l10n.navExport),
        _NavItem(icon: Icons.settings, label: l10n.navSettings),
      ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          onNavigateToSchemes: () => setState(() => _selectedIndex = 1),
          onNavigateToImport: () => setState(() => _selectedIndex = 4),
          onNavigateToExport: () => setState(() => _selectedIndex = 5),
        );
      case 1:
        return const SchemesListScreen();
      case 2:
        return const UselessItemsScreen();
      case 3:
        return const MiscellaneousScreen();
      case 4:
        return const ImportScreen();
      case 5:
        return const ExportScreen();
      case 6:
        return SettingsScreen(
          onThemeChanged: () => CityWaterWorksApp.of(context)?.toggleTheme(),
          onLanguageChanged: (value) => CityWaterWorksApp.of(context)?.setLanguage(value),
          currentUsername: widget.currentUsername,
          onLogout: widget.onLogout,
          onAppNameChanged: (value) => setState(() => _appDisplayName = value),
          onDataRestored: () => setState(() => _selectedIndex = 0),
        );
      default:
        return const DashboardScreen();
    }
  }

  Widget _buildBrandHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x223B82F6),
            child: Icon(Icons.water_drop, size: 18, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_appDisplayName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(l10n.adminPanel,
                  style: const TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navItems = _navItems(l10n);
    final width = MediaQuery.of(context).size.width;

    // Desktop: persistent side navigation drawer
    if (width >= 1200) {
      return Scaffold(
        backgroundColor: _shellBg,
        body: Row(
          children: [
            Container(
              width: 270,
              decoration: BoxDecoration(
                color: _surface,
                border: Border(right: BorderSide(color: _border)),
              ),
              child: Column(
                children: [
                  _buildBrandHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: navItems.length,
                      itemBuilder: (context, i) {
                        final item = navItems[i];
                        final selected = i == _selectedIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            selected: selected,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            selectedTileColor: _surfaceSoft,
                            iconColor: selected ? _accent : _textSecondary,
                            textColor: selected ? _textPrimary : _textSecondary,
                            leading: Icon(item.icon, size: 20),
                            title: Text(item.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                            onTap: () => setState(() => _selectedIndex = i),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildPage(_selectedIndex)),
          ],
        ),
      );
    }

    // Tablet: navigation rail
    if (width >= 600) {
      return Scaffold(
        backgroundColor: _shellBg,
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _surface,
                border: Border(right: BorderSide(color: _border)),
              ),
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                backgroundColor: Colors.transparent,
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: const IconThemeData(color: _accent),
                unselectedIconTheme: const IconThemeData(color: _textSecondary),
                selectedLabelTextStyle: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
                unselectedLabelTextStyle: const TextStyle(color: _textSecondary),
                indicatorColor: _surfaceSoft,
                leading: const Padding(
                  padding: EdgeInsets.only(bottom: 8, top: 8),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0x223B82F6),
                    child: Icon(Icons.water_drop, size: 18, color: _accent),
                  ),
                ),
                destinations: navItems
                    .map((item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          label: Text(item.label),
                        ))
                    .toList(),
              ),
            ),
            Expanded(child: _buildPage(_selectedIndex)),
          ],
        ),
      );
    }

    // Mobile: bottom navigation bar
    return Scaffold(
      backgroundColor: _shellBg,
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: _surface,
        indicatorColor: _surfaceSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.04)),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon, color: _textSecondary),
                  selectedIcon: Icon(item.icon, color: _accent),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}
