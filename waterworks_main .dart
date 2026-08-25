import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const WaterWorksApp());
}

// ═══════════════════════════════════════════════════════════
//  THEME & CONSTANTS
// ═══════════════════════════════════════════════════════════
class AppColors {
  static const bg         = Color(0xFF07090F);
  static const surface    = Color(0xFF0E1420);
  static const card       = Color(0xFF131928);
  static const border     = Color(0xFF1E2D45);
  static const borderGlow = Color(0xFF1A3A5C);

  static const cyan       = Color(0xFF00C9FF);
  static const cyanDim    = Color(0xFF0A4A6A);
  static const blue       = Color(0xFF2563EB);
  static const teal       = Color(0xFF06B6D4);
  static const amber      = Color(0xFFFFB020);
  static const green      = Color(0xFF10B981);
  static const red        = Color(0xFFEF4444);
  static const redDim     = Color(0xFF3D1515);

  static const textPrimary   = Color(0xFFE2EAF4);
  static const textSecondary = Color(0xFF6B8AAE);
  static const textMuted     = Color(0xFF3A5070);
}

// ═══════════════════════════════════════════════════════════
//  APP ROOT
// ═══════════════════════════════════════════════════════════
class WaterWorksApp extends StatelessWidget {
  const WaterWorksApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '14G Water Works',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyan,
          surface: AppColors.surface,
        ),
      ),
      home: const SetsListScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 1 — SETS LIST
// ═══════════════════════════════════════════════════════════
class SetsListScreen extends StatefulWidget {
  const SetsListScreen({super.key});
  @override
  State<SetsListScreen> createState() => _SetsListScreenState();
}

class _SetsListScreenState extends State<SetsListScreen>
    with TickerProviderStateMixin {
  late AnimationController _pageAnim;
  late AnimationController _pulseAnim;

  final List<SetData> sets = [
    SetData(id: 1, name: 'Set No. 1', machinery: 3, entries: 8,
        amount: 876750, color: AppColors.cyan),
    SetData(id: 2, name: 'Set No. 2', machinery: 2, entries: 8,
        amount: 619741, color: AppColors.teal),
    SetData(id: 3, name: 'Set No. 3', machinery: 2, entries: 2,
        amount: 257071, color: AppColors.blue),
  ];

  @override
  void initState() {
    super.initState();
    _pageAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000))..forward();
    _pulseAnim = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildTopBar(),
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(children: [
            _buildProjectHeader(),
            _buildSectionLabel(),
            ...sets.asMap().entries.map((e) =>
                _buildSetCard(e.value, e.key)),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(color: AppColors.cyan.withOpacity(0.05),
              blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('14G Water Works',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, letterSpacing: 0.3)),
              Text('PROJECT OVERVIEW',
                  style: TextStyle(fontSize: 10, letterSpacing: 2.5,
                      color: AppColors.cyan.withOpacity(0.7),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary),
          onPressed: () {},
        ),
      ]),
    );
  }

  // ── PROJECT HEADER CARD ────────────────────────────────
  Widget _buildProjectHeader() {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _pageAnim, curve: Curves.easeOut),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E1E35), Color(0xFF0A1525)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderGlow, width: 1),
          boxShadow: [
            BoxShadow(color: AppColors.cyan.withOpacity(0.08),
                blurRadius: 24, spreadRadius: -4),
          ],
        ),
        child: Stack(children: [
          // Background water ripple effect
          Positioned.fill(child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => CustomPaint(
                painter: _RipplePainter(_pulseAnim.value),
              ),
            ),
          )),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              // Icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.cyan.withOpacity(0.2),
                    AppColors.blue.withOpacity(0.2),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.cyan.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.water_drop_rounded,
                    color: AppColors.cyan, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('14G Water Works',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.circle, size: 6, color: AppColors.green),
                    const SizedBox(width: 5),
                    Text('Active Project',
                        style: TextStyle(fontSize: 11,
                            color: AppColors.green.withOpacity(0.9),
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('TOTAL VALUE',
                    style: TextStyle(fontSize: 9, letterSpacing: 2,
                        color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.cyan, AppColors.teal],
                  ).createShader(bounds),
                  child: const Text('Rs. 17,53,562',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.5)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── SECTION LABEL ──────────────────────────────────────
  Widget _buildSectionLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.cyan, AppColors.blue]),
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 10),
        const Text('SETS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 2.5)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
          ),
          child: const Text('3',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.cyan)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.cyan, Color(0xFF0099CC)]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(
                  color: AppColors.cyan.withOpacity(0.3),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: const [
              Icon(Icons.add_rounded, size: 14, color: AppColors.bg),
              SizedBox(width: 4),
              Text('Add Set', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: AppColors.bg)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── SET CARD ───────────────────────────────────────────
  Widget _buildSetCard(SetData set, int index) {
    return AnimatedBuilder(
      animation: _pageAnim,
      builder: (context, child) {
        final delay = index * 0.15;
        final t = math.max(0.0,
            math.min(1.0, (_pageAnim.value - delay) / (1.0 - delay)));
        final curve = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - curve)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SetDetailScreen(set: set))),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SetDetailScreen(set: set))),
              borderRadius: BorderRadius.circular(16),
              splashColor: set.color.withOpacity(0.08),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // Number badge
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          set.color.withOpacity(0.2),
                          set.color.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: set.color.withOpacity(0.4), width: 1.5),
                    ),
                    child: Center(
                      child: Text('${set.id}',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w800, color: set.color)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(set.name,
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _MetaChip(
                          icon: Icons.precision_manufacturing_outlined,
                          label: '${set.machinery} machinery',
                          color: set.color,
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.receipt_long_outlined,
                          label: '${set.entries} entries',
                          color: AppColors.textSecondary,
                        ),
                      ]),
                    ],
                  )),
                  // Amount + delete
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_formatAmount(set.amount),
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: set.color)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmDelete(set),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.redDim,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.red.withOpacity(0.3), width: 1),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.red, size: 14),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    final s = amount.toString();
    if (s.length > 3) {
      return 'Rs. ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return 'Rs. $s';
  }

  void _confirmDelete(SetData set) {
    showDialog(context: context, builder: (ctx) => _DeleteDialog(
      title: set.name,
      onConfirm: () {
        setState(() => sets.remove(set));
        Navigator.pop(ctx);
      },
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 2 — SET DETAIL
// ═══════════════════════════════════════════════════════════
class SetDetailScreen extends StatefulWidget {
  final SetData set;
  const SetDetailScreen({super.key, required this.set});
  @override
  State<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends State<SetDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  final List<MachineData> machines = [
    MachineData(
      name: 'Motor 50/HP Siemens',
      icon: Icons.electric_bolt_rounded,
      color: AppColors.amber,
      total: 501993,
      entries: [
        EntryRow(sr: 1, date: '17-06-2020', voucher: '171',   amount: 82900),
        EntryRow(sr: 2, date: '06-04-2023', voucher: '-',     amount: 95300),
        EntryRow(sr: 3, date: '20-01-2025', voucher: '1688',  amount: 160694),
        EntryRow(sr: 4, date: '26-08-2025', voucher: '2113',  amount: 163099),
      ],
    ),
    MachineData(
      name: 'Pump 5x6',
      icon: Icons.water_rounded,
      color: AppColors.teal,
      total: 374757,
      entries: [
        EntryRow(sr: 1, date: '17-09-2022', voucher: '292',  amount: 62938),
        EntryRow(sr: 2, date: '29-09-2023', voucher: '981',  amount: 60194),
        EntryRow(sr: 3, date: '01-02-2024', voucher: '1076', amount: 72265),
        EntryRow(sr: 4, date: '04-02-2025', voucher: '1708', amount: 179360),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildTopBar(context),
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(children: [
            _buildSetHeader(),
            ...machines.asMap().entries.map((e) =>
                _buildMachineBlock(e.value, e.key)),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set No. 1',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text('14G WATER WORKS',
                style: TextStyle(fontSize: 9, letterSpacing: 2.5,
                    color: AppColors.cyan.withOpacity(0.7),
                    fontWeight: FontWeight.w600)),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary),
          onPressed: () {},
        ),
      ]),
    );
  }

  Widget _buildSetHeader() {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0D1E35), Color(0xFF091525)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderGlow),
          boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.06),
              blurRadius: 20)],
        ),
        child: Column(children: [
          Row(children: [
            // Breadcrumb
            Text('14G Water Works',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: AppColors.textMuted),
            Text('Set No. 1',
                style: TextStyle(fontSize: 12, color: AppColors.cyan,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set No. 1',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('14G Water Works Set No.1',
                    style: TextStyle(fontSize: 13,
                        color: AppColors.textSecondary)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('TOTAL',
                  style: TextStyle(fontSize: 9, letterSpacing: 2,
                      color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.cyan, AppColors.teal],
                ).createShader(b),
                child: const Text('Rs. 8,76,750',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          // Progress bar
          _buildProgressBar(),
        ]),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Motor 50/HP', style: TextStyle(fontSize: 11,
            color: AppColors.amber, fontWeight: FontWeight.w600)),
        Text('Pump 5x6', style: TextStyle(fontSize: 11,
            color: AppColors.teal, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      Container(
        height: 6, decoration: BoxDecoration(
          color: AppColors.border, borderRadius: BorderRadius.circular(3)),
        child: Row(children: [
          Flexible(
            flex: 501993,
            child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.amber, AppColors.amber.withOpacity(0.6)]),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(3)),
            )),
          ),
          Flexible(
            flex: 374757,
            child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.teal.withOpacity(0.6), AppColors.teal]),
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(3),
                  bottomRight: Radius.circular(3)),
            )),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildMachineBlock(MachineData machine, int blockIndex) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final delay = 0.2 + blockIndex * 0.2;
        final t = math.max(0.0, math.min(1.0,
            (_anim.value - delay) / (1.0 - delay)));
        final curve = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - curve)), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Machine header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: machine.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: machine.color.withOpacity(0.35), width: 1.5),
                ),
                child: Icon(machine.icon, color: machine.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(machine.name,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('${machine.entries.length} entries',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.textSecondary)),
                    Container(margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 3, height: 3,
                        decoration: BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle)),
                    Text('Rs. ${_fmt(machine.total)}',
                        style: TextStyle(fontSize: 12,
                            color: machine.color,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              )),
            ]),
          ),

          // Table header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              _TableHeader('SR', flex: 1),
              _TableHeader('DATE', flex: 3),
              _TableHeader('VOUCHER', flex: 2),
              _TableHeader('AMOUNT', flex: 3, align: TextAlign.right),
              _TableHeader('REG.', flex: 2, align: TextAlign.center),
              _TableHeader('ACTIONS', flex: 2, align: TextAlign.right),
            ]),
          ),

          // Entries
          ...machine.entries.map((e) => _buildEntryRow(e, machine.color)),

          // Add entry button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: machine.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: machine.color.withOpacity(0.25),
                      width: 1,
                      style: BorderStyle.solid),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: machine.color, size: 16),
                  const SizedBox(width: 6),
                  Text('Add Entry',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: machine.color)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEntryRow(EntryRow entry, Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(children: [
        // SR
        Expanded(flex: 1, child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Text('${entry.sr}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: accentColor))),
        )),
        // Date
        Expanded(flex: 3, child: Text(entry.date,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary,
                fontWeight: FontWeight.w500))),
        // Voucher
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: entry.voucher != '-' ? BoxDecoration(
            color: AppColors.border.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ) : null,
          child: Text(entry.voucher,
              style: TextStyle(fontSize: 12,
                  color: entry.voucher != '-'
                      ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        )),
        // Amount
        Expanded(flex: 3, child: Text('Rs. ${_fmt(entry.amount)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.green))),
        // Reg
        Expanded(flex: 2, child: Text('-',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
        // Actions
        Expanded(flex: 2, child: Row(
            mainAxisAlignment: MainAxisAlignment.end, children: [
          _ActionBtn(icon: Icons.edit_rounded,
              color: AppColors.cyan, onTap: () {}),
          const SizedBox(width: 6),
          _ActionBtn(icon: Icons.delete_outline_rounded,
              color: AppColors.red, onTap: () {}),
        ])),
      ]),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return s;
  }
}

// ═══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 12, color: color.withOpacity(0.8)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11,
        color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
  ]);
}

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  const _TableHeader(this.text, {this.flex = 1,
    this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(text,
        textAlign: align,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 1.5)),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color,
    required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 14),
    ),
  );
}

class _DeleteDialog extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;
  const _DeleteDialog({required this.title, required this.onConfirm});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.red, width: 1),
    ),
    title: Row(children: const [
      Icon(Icons.warning_amber_rounded, color: AppColors.red),
      SizedBox(width: 8),
      Text('Delete Set', style: TextStyle(color: AppColors.red)),
    ]),
    content: Text('Are you sure you want to delete "$title"?\nThis cannot be undone.',
        style: const TextStyle(color: AppColors.textSecondary)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary))),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onConfirm,
        child: const Text('Delete', style: TextStyle(color: Colors.white)),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════
//  RIPPLE PAINTER
// ═══════════════════════════════════════════════════════════
class _RipplePainter extends CustomPainter {
  final double progress;
  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final radius = p * size.width * 0.8;
      paint.color = AppColors.cyan.withOpacity((1 - p) * 0.06);
      canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.5),
        radius, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════
class SetData {
  final int id;
  final String name;
  final int machinery;
  final int entries;
  final int amount;
  final Color color;
  SetData({required this.id, required this.name, required this.machinery,
    required this.entries, required this.amount, required this.color});
}

class MachineData {
  final String name;
  final IconData icon;
  final Color color;
  final int total;
  final List<EntryRow> entries;
  MachineData({required this.name, required this.icon, required this.color,
    required this.total, required this.entries});
}

class EntryRow {
  final int sr;
  final String date;
  final String voucher;
  final int amount;
  EntryRow({required this.sr, required this.date, required this.voucher,
    required this.amount});
}
