// ============================================================
// Durian Smart Farm - Mobile App (Flutter) — เชื่อม Supabase จริง
//
// pubspec.yaml ต้องมี:
//   supabase_flutter: ^2.6.0
//
// วางไฟล์นี้เป็น lib/main.dart และให้ durian_supabase_service.dart,
// durian_login_screen.dart อยู่โฟลเดอร์ lib/ เดียวกัน
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'durian_supabase_service.dart';
import 'durian_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qperhmjkmqkuiwnbxjck.supabase.co',   // TODO: ใส่ URL จริง
    anonKey: 'sb_publishable_-B3rAdCdJ7ATnoCppfRqLg_khuX-keB,                   // TODO: ใส่ anon key จริง
  );
  runApp(const DurianApp());
}

class AppColors {
  static const bg = Color(0xFFF6F7F2);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF0F2EC);
  static const ink = Color(0xFF1E2A20);
  static const inkSoft = Color(0xFF5B6B5D);
  static const border = Color(0xFFE1E5DA);

  static const green = Color(0xFF2F6B3C);
  static const greenSoft = Color(0xFFE4F0E6);
  static const blue = Color(0xFF2B6CA3);
  static const blueSoft = Color(0xFFE3EEF7);
  static const orange = Color(0xFFCE6A0B);
  static const orangeSoft = Color(0xFFFBEAD5);
  static const red = Color(0xFFB23A3A);
  static const redSoft = Color(0xFFF8E3E1);

  static (Color, Color) tone(String key) => switch (key) {
        'green' => (green, greenSoft),
        'blue' => (blue, blueSoft),
        'orange' => (orange, orangeSoft),
        _ => (red, redSoft),
      };

  static (Color, Color) health(String status) => switch (status) {
        'healthy' => (green, greenSoft),
        'watch' => (orange, orangeSoft),
        _ => (red, redSoft),
      };

  static String healthLabel(String status) => switch (status) {
        'healthy' => 'ปกติ',
        'watch' => 'เฝ้าระวัง',
        'sick' => 'ป่วย',
        'dead' => 'ตาย',
        _ => status,
      };
}

const opLabels = {
  'fertilizer': 'ใส่ปุ๋ย', 'spray': 'ฉีดยา', 'mowing': 'ตัดหญ้า', 'watering': 'รดน้ำ',
  'pruning': 'ตัดแต่งกิ่ง', 'pest_control': 'กำจัดศัตรูพืช', 'other': 'อื่นๆ',
};

class DurianApp extends StatefulWidget {
  const DurianApp({super.key});
  @override
  State<DurianApp> createState() => _DurianAppState();
}

class _DurianAppState extends State<DurianApp> {
  final service = SupabaseService();
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    // ฟังการเปลี่ยนสถานะ auth (เช่น token หมดอายุ / sign out จากที่อื่น)
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && mounted) {
        setState(() => loggedIn = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Durian Smart Farm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green, primary: AppColors.green),
        fontFamily: 'NotoSansThai',
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      home: loggedIn
          ? MainShell(service: service, onLoggedOut: () => setState(() => loggedIn = false))
          : LoginScreen(service: service, onLoggedIn: () => setState(() => loggedIn = true)),
    );
  }
}

// ============================================================
// MAIN SHELL — โหลดข้อมูลจริงจาก SupabaseService
// ============================================================
class MainShell extends StatefulWidget {
  final SupabaseService service;
  final VoidCallback onLoggedOut;
  const MainShell({required this.service, required this.onLoggedOut, super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool loading = true;
  String? error;

  Map<String, dynamic> kpis = {};
  List<Map<String, dynamic>> alerts = [];
  List<Map<String, dynamic>> trees = [];
  List<Map<String, dynamic>> operations = [];
  List<Map<String, dynamic>> harvest = [];
  List<Map<String, dynamic>> soil = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        widget.service.getDashboardKpis(),
        widget.service.listActiveAlerts(),
        widget.service.listTrees(),
        widget.service.listOperations(),
        widget.service.listSoilReadings(),
      ]);
      setState(() {
        kpis = results[0] as Map<String, dynamic>;
        alerts = results[1] as List<Map<String, dynamic>>;
        trees = results[2] as List<Map<String, dynamic>>;
        operations = results[3] as List<Map<String, dynamic>>;
        soil = results[4] as List<Map<String, dynamic>>;
        loading = false;
      });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _openQuickAdd(int tab) async {
    final saved = await openQuickActionSheet(context, service: widget.service, trees: trees, startTab: tab);
    if (saved == true) _loadAll();
  }

  Future<void> _logout() async {
    await widget.service.signOut();
    widget.onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(kpis: kpis, alerts: alerts, loading: loading),
      TreesPage(trees: trees, openQuickAdd: _openQuickAdd),
      OperationsPage(operations: operations, openQuickAdd: _openQuickAdd),
      SoilPage(soil: soil, openQuickAdd: _openQuickAdd),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('สวนทุเรียนของฉัน',
            style: TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.inkSoft), onPressed: _loadAll),
          IconButton(icon: const Icon(Icons.logout, color: AppColors.inkSoft), onPressed: _logout),
        ],
      ),
      body: error != null
          ? Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $error', style: const TextStyle(color: AppColors.red)))
          : IndexedStack(index: index, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () => _openQuickAdd(0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, 'ภาพรวม', 0),
            _navItem(Icons.park_rounded, 'ต้นไม้', 1),
            const SizedBox(width: 40),
            _navItem(Icons.assignment_rounded, 'กิจกรรม', 2),
            _navItem(Icons.science_rounded, 'ดิน', 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int i) {
    final active = index == i;
    final color = active ? AppColors.green : AppColors.inkSoft;
    return InkWell(
      onTap: () => setState(() => index = i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ============================================================
// SHARED WIDGETS
// ============================================================
class Chip2 extends StatelessWidget {
  final String label;
  final String tone;
  const Chip2(this.label, this.tone, {super.key});
  @override
  Widget build(BuildContext context) {
    final (fg, bgc) = AppColors.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onAdd;
  const SectionCard({required this.title, required this.child, this.onAdd, super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('เพิ่ม'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

class CompactDataGrid extends StatelessWidget {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;
  final List<String> keys;
  final String? healthKey;
  const CompactDataGrid({required this.headers, required this.rows, required this.keys, this.healthKey, super.key});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('ยังไม่มีข้อมูล', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 34,
        columnSpacing: 18,
        headingTextStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
        dataTextStyle: const TextStyle(fontSize: 12.5, color: AppColors.ink),
        columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
        rows: rows.map((r) {
          return DataRow(
            cells: keys.map((k) {
              final raw = r[k];
              if (k == healthKey) {
                final status = (raw ?? 'healthy').toString();
                final (fg, bgc) = AppColors.health(status);
                return DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(999)),
                  child: Text(AppColors.healthLabel(status), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
                ));
              }
              return DataCell(Text(raw?.toString() ?? '-'));
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class SearchBar2 extends StatelessWidget {
  const SearchBar2({super.key});
  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'ค้นหา...',
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.inkSoft),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      ),
    );
  }
}

// ============================================================
// PAGES — รับข้อมูลจริงผ่าน props จาก MainShell
// ============================================================
class DashboardPage extends StatelessWidget {
  final Map<String, dynamic> kpis;
  final List<Map<String, dynamic>> alerts;
  final bool loading;
  const DashboardPage({required this.kpis, required this.alerts, required this.loading, super.key});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppColors.green));

    final revenue = (kpis['revenue_mtd'] ?? 0) as num;
    final expense = (kpis['expense_mtd'] ?? 0) as num;
    final cards = [
      {'label': 'ต้นทุเรียนทั้งหมด', 'value': '${kpis['total_trees'] ?? 0} ต้น', 'tone': 'green', 'icon': Icons.park},
      {'label': 'ผลผลิตเดือนนี้', 'value': '${(kpis['yield_mtd_kg'] ?? 0)} กก.', 'tone': 'green', 'icon': Icons.eco},
      {'label': 'รายรับเดือนนี้', 'value': '฿${revenue.toStringAsFixed(0)}', 'tone': 'blue', 'icon': Icons.payments},
      {'label': 'กำไรสุทธิ', 'value': '฿${(revenue - expense).toStringAsFixed(0)}', 'tone': 'blue', 'icon': Icons.trending_up},
      {'label': 'งานค้าง', 'value': '${kpis['open_tasks'] ?? 0} รายการ', 'tone': 'orange', 'icon': Icons.checklist},
      {'label': 'ต้นที่ป่วย', 'value': '${kpis['sick_trees'] ?? 0} ต้น', 'tone': 'red', 'icon': Icons.favorite},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        const Text('ภาพรวมสวน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
          children: cards.map((k) {
            final (fg, bgc) = AppColors.tone(k['tone'] as String);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(8)),
                    child: Icon(k['icon'] as IconData, size: 15, color: fg),
                  ),
                  const SizedBox(height: 8),
                  Text(k['value'] as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(k['label'] as String, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'การแจ้งเตือนที่ต้องดำเนินการ',
          child: alerts.isEmpty
              ? const Text('ไม่มีการแจ้งเตือนขณะนี้', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5))
              : Column(
                  children: alerts.map((a) {
                    final tone = {'severe': 'red', 'warning': 'orange', 'info': 'blue'}[a['severity']] ?? 'blue';
                    final (fg, bgc) = AppColors.tone(tone);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.warning_amber_rounded, size: 15, color: fg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(a['message']?.toString() ?? a['alert_type']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class TreesPage extends StatelessWidget {
  final List<Map<String, dynamic>> trees;
  final void Function(int tab) openQuickAdd;
  const TreesPage({required this.trees, required this.openQuickAdd, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        SectionCard(
          title: 'ทะเบียนต้นทุเรียน (${trees.length})',
          onAdd: () => openQuickAdd(0),
          child: Column(children: [
            const SearchBar2(),
            const SizedBox(height: 10),
            CompactDataGrid(
              headers: const ['รหัส', 'พันธุ์', 'วันที่ปลูก', 'สุขภาพ'],
              keys: const ['tree_code', 'variety', 'planted_date', 'health_status'],
              healthKey: 'health_status',
              rows: trees,
            ),
          ]),
        ),
      ],
    );
  }
}

class OperationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> operations;
  final void Function(int tab) openQuickAdd;
  const OperationsPage({required this.operations, required this.openQuickAdd, super.key});

  @override
  Widget build(BuildContext context) {
    final display = operations.map((o) => {
          ...o,
          'operation_type_label': opLabels[o['operation_type']] ?? o['operation_type'],
          'date': (o['performed_at']?.toString() ?? '').split('T').first,
        }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        SectionCard(
          title: 'บันทึกกิจกรรมสวน (${operations.length})',
          onAdd: () => openQuickAdd(2),
          child: Column(children: [
            const SearchBar2(),
            const SizedBox(height: 10),
            CompactDataGrid(
              headers: const ['วันที่', 'ประเภท', 'รายละเอียด', 'ค่าใช้จ่าย'],
              keys: const ['date', 'operation_type_label', 'description', 'cost'],
              rows: display,
            ),
          ]),
        ),
      ],
    );
  }
}

class SoilPage extends StatelessWidget {
  final List<Map<String, dynamic>> soil;
  final void Function(int tab) openQuickAdd;
  const SoilPage({required this.soil, required this.openQuickAdd, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        SectionCard(
          title: 'ผลวิเคราะห์ดิน (${soil.length})',
          onAdd: () => openQuickAdd(1),
          child: Column(children: [
            const SearchBar2(),
            const SizedBox(height: 10),
            CompactDataGrid(
              headers: const ['วันที่', 'pH', 'EC', 'P', 'K'],
              keys: const ['reading_date', 'ph', 'ec', 'p', 'k'],
              rows: soil,
            ),
          ]),
        ),
      ],
    );
  }
}

// ============================================================
// QUICK ACTION — bottom sheet เขียนลง Supabase จริงแล้ว pop(true) ให้ MainShell รีเฟรช
// ============================================================
Future<bool?> openQuickActionSheet(
  BuildContext context, {
  required SupabaseService service,
  required List<Map<String, dynamic>> trees,
  int? startTab,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => QuickActionSheet(service: service, trees: trees, startTab: startTab),
  );
}

class QuickActionSheet extends StatefulWidget {
  final SupabaseService service;
  final List<Map<String, dynamic>> trees;
  final int? startTab;
  const QuickActionSheet({required this.service, required this.trees, this.startTab, super.key});

  @override
  State<QuickActionSheet> createState() => _QuickActionSheetState();
}

class _QuickActionSheetState extends State<QuickActionSheet> {
  String? mode;

  @override
  void initState() {
    super.initState();
    if (widget.startTab != null) {
      mode = ['tree', 'soil', 'operation', 'expense'][widget.startTab!];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_titleFor(mode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context, false)),
          ]),
          const SizedBox(height: 8),
          if (mode == null) _buildMenu() else _buildForm(mode!),
        ]),
      ),
    );
  }

  String _titleFor(String? m) => switch (m) {
        'tree' => 'ลงทะเบียนต้นทุเรียน',
        'soil' => 'บันทึกผลวิเคราะห์ดิน',
        'operation' => 'บันทึกกิจกรรมสวน',
        'expense' => 'รายรับ-รายจ่าย',
        _ => 'เพิ่มข้อมูลด่วน',
      };

  Widget _buildMenu() {
    final items = [
      ('operation', 'บันทึกกิจกรรม', Icons.assignment, 'green'),
      ('tree', 'ลงทะเบียนต้น', Icons.park, 'green'),
      ('soil', 'วิเคราะห์ดิน', Icons.science, 'blue'),
      ('expense', 'รายรับ-รายจ่าย', Icons.payments, 'orange'),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
      children: items.map((it) {
        final (key, label, icon, tone) = it;
        final (fg, bgc) = AppColors.tone(tone);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => mode = key),
          child: Container(
            decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildForm(String m) {
    switch (m) {
      case 'tree':
        return _TreeForm(service: widget.service);
      case 'soil':
        return _SoilForm(service: widget.service);
      case 'expense':
        return _OperationOrExpenseForm(service: widget.service, trees: widget.trees, isExpense: true);
      default:
        return _OperationOrExpenseForm(service: widget.service, trees: widget.trees, isExpense: false);
    }
  }
}

InputDecoration _fieldDeco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    );

Widget _primaryButton(String label, Color color, VoidCallback? onTap, {bool loading = false}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(loading ? 'กำลังบันทึก...' : label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _TreeForm extends StatefulWidget {
  final SupabaseService service;
  const _TreeForm({required this.service});
  @override
  State<_TreeForm> createState() => _TreeFormState();
}

class _TreeFormState extends State<_TreeForm> {
  final codeCtrl = TextEditingController();
  String variety = 'หมอนทอง';
  String health = 'healthy';
  bool saving = false;
  String? error;

  Future<void> _save() async {
    if (codeCtrl.text.trim().isEmpty) {
      setState(() => error = 'กรุณากรอกรหัสต้น');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await widget.service.addTree(treeCode: codeCtrl.text.trim(), variety: variety, healthStatus: health);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = 'บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(controller: codeCtrl, decoration: _fieldDeco('รหัสต้น', hint: 'เช่น A-022')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: variety,
        decoration: _fieldDeco('พันธุ์'),
        items: ['หมอนทอง', 'ก้านยาว', 'ชะนี', 'อื่นๆ'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => variety = v!),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: health,
        decoration: _fieldDeco('สถานะสุขภาพ'),
        items: const [
          DropdownMenuItem(value: 'healthy', child: Text('ปกติ')),
          DropdownMenuItem(value: 'watch', child: Text('เฝ้าระวัง')),
          DropdownMenuItem(value: 'sick', child: Text('ป่วย')),
        ],
        onChanged: (v) => setState(() => health = v!),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.my_location, size: 16), label: const Text('ปักหมุด GPS (เพิ่ม geolocator ภายหลัง)')),
      if (error != null) ...[const SizedBox(height: 8), Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12))],
      const SizedBox(height: 14),
      _primaryButton('บันทึกต้นทุเรียน', AppColors.green, _save, loading: saving),
    ]);
  }
}

class _SoilForm extends StatefulWidget {
  final SupabaseService service;
  const _SoilForm({required this.service});
  @override
  State<_SoilForm> createState() => _SoilFormState();
}

class _SoilFormState extends State<_SoilForm> {
  final phCtrl = TextEditingController();
  final ecCtrl = TextEditingController();
  final pCtrl = TextEditingController();
  final kCtrl = TextEditingController();
  String? phError;
  bool saving = false;
  String? error;

  void _validatePh(String v) {
    final val = double.tryParse(v);
    setState(() => phError = (val == null || val < 0 || val > 14) ? 'ค่า pH ต้องอยู่ระหว่าง 0–14' : null);
  }

  Future<void> _save() async {
    setState(() { saving = true; error = null; });
    try {
      await widget.service.addSoilReading(
        readingDate: DateTime.now(),
        ph: double.tryParse(phCtrl.text),
        ec: double.tryParse(ecCtrl.text),
        p: double.tryParse(pCtrl.text),
        k: double.tryParse(kCtrl.text),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = 'บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: phCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _validatePh,
            decoration: _fieldDeco('pH (0–14)', hint: '5.5–6.5 เหมาะสม').copyWith(errorText: phError),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: ecCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _fieldDeco('EC (dS/m)'))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: _fieldDeco('P (mg/kg)'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: kCtrl, keyboardType: TextInputType.number, decoration: _fieldDeco('K (mg/kg)'))),
      ]),
      if (error != null) ...[const SizedBox(height: 8), Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12))],
      const SizedBox(height: 14),
      _primaryButton('บันทึกผลวิเคราะห์ดิน', AppColors.blue, _save, loading: saving),
    ]);
  }
}

class _OperationOrExpenseForm extends StatefulWidget {
  final SupabaseService service;
  final List<Map<String, dynamic>> trees;
  final bool isExpense;
  const _OperationOrExpenseForm({required this.service, required this.trees, required this.isExpense});
  @override
  State<_OperationOrExpenseForm> createState() => _OperationOrExpenseFormState();
}

class _OperationOrExpenseFormState extends State<_OperationOrExpenseForm> {
  String? treeId;
  String opType = 'fertilizer';
  String txType = 'expense';
  String txCategory = 'fertilizer';
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool saving = false;
  String? error;

  Future<void> _save() async {
    setState(() { saving = true; error = null; });
    try {
      if (widget.isExpense) {
        if (amountCtrl.text.trim().isEmpty) throw Exception('กรุณากรอกจำนวนเงิน');
        await widget.service.addTransaction(
          transactionType: txType,
          category: txCategory,
          amount: num.parse(amountCtrl.text),
          transactionDate: DateTime.now(),
          description: descCtrl.text,
        );
      } else {
        await widget.service.addOperation(
          operationType: opType,
          description: descCtrl.text,
          cost: num.tryParse(amountCtrl.text) ?? 0,
          treeId: treeId,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = 'บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isExpense) {
      return Column(children: [
        DropdownButtonFormField<String>(
          initialValue: txType,
          decoration: _fieldDeco('ประเภท'),
          items: const [DropdownMenuItem(value: 'expense', child: Text('รายจ่าย')), DropdownMenuItem(value: 'income', child: Text('รายรับ'))],
          onChanged: (v) => setState(() => txType = v!),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: txCategory,
          decoration: _fieldDeco('หมวด'),
          items: (txType == 'expense'
                  ? const [
                      DropdownMenuItem(value: 'fertilizer', child: Text('ปุ๋ย/สารเคมี')),
                      DropdownMenuItem(value: 'labor', child: Text('ค่าแรง')),
                      DropdownMenuItem(value: 'fuel', child: Text('น้ำมัน')),
                      DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
                    ]
                  : const [
                      DropdownMenuItem(value: 'harvest_sale', child: Text('ขายผลผลิต')),
                      DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
                    ]),
          onChanged: (v) => setState(() => txCategory = v!),
        ),
        const SizedBox(height: 10),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _fieldDeco('จำนวนเงิน (บาท)')),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, decoration: _fieldDeco('หมายเหตุ')),
        if (error != null) ...[const SizedBox(height: 8), Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12))],
        const SizedBox(height: 14),
        _primaryButton('บันทึก', AppColors.orange, _save, loading: saving),
      ]);
    }

    return Column(children: [
      DropdownButtonFormField<String?>(
        initialValue: treeId,
        decoration: _fieldDeco('ต้น (ไม่ระบุ = ทั้งสวน)'),
        items: [
          const DropdownMenuItem(value: null, child: Text('-- ไม่ระบุ --')),
          ...widget.trees.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['tree_code'].toString()))),
        ],
        onChanged: (v) => setState(() => treeId = v),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: opType,
        decoration: _fieldDeco('ประเภท'),
        items: opLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => opType = v!),
      ),
      const SizedBox(height: 10),
      TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _fieldDeco('ค่าใช้จ่าย (บาท)')),
      const SizedBox(height: 10),
      TextField(controller: descCtrl, decoration: _fieldDeco('หมายเหตุ')),
      if (error != null) ...[const SizedBox(height: 8), Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12))],
      const SizedBox(height: 14),
      _primaryButton('บันทึก', AppColors.orange, _save, loading: saving),
    ]);
  }
}
