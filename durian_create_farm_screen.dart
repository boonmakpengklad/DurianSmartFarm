// durian_create_farm_screen.dart
// แสดงหลัง login สำเร็จถ้าบัญชียังไม่มีสวน — สร้างสวนแล้วตั้ง service.farmId ก่อนเข้า MainShell

import 'package:flutter/material.dart';
import 'durian_supabase_service.dart';

class CreateFarmScreen extends StatefulWidget {
  final SupabaseService service;
  const CreateFarmScreen({required this.service, super.key});

  @override
  State<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends State<CreateFarmScreen> {
  final nameCtrl = TextEditingController();
  bool saving = false;
  String? error;

  static const green = Color(0xFF2F6B3C);
  static const bg = Color(0xFFF6F7F2);
  static const surface2 = Color(0xFFF0F2EC);
  static const border = Color(0xFFE1E5DA);
  static const red = Color(0xFFB23A3A);
  static const inkSoft = Color(0xFF5B6B5D);

  Future<void> _create() async {
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => error = 'กรุณากรอกชื่อสวน');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      final farm = await widget.service.createFarm(nameCtrl.text.trim());
      widget.service.farmId = farm['id'] as String;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = 'สร้างสวนไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('สร้างสวนแรกของคุณ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('ยังไม่มีสวนในบัญชีนี้ ตั้งชื่อสวนเพื่อเริ่มต้นใช้งาน',
                    style: TextStyle(fontSize: 12.5, color: inkSoft)),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'ชื่อสวน',
                    hintText: 'เช่น สวนทุเรียนบ้านสวนสุข',
                    filled: true,
                    fillColor: surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: border),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: red, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(saving ? 'กำลังสร้าง...' : 'สร้างสวน'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
