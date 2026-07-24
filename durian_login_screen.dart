// durian_login_screen.dart
// หน้า Login/Signup — แสดงก่อนเข้า MainShell ถ้ายังไม่มี session
//
// ใน main.dart:
//   home: supabase.auth.currentSession == null ? const LoginScreen() : const MainShell(),
// และฟัง supabase.auth.onAuthStateChange เพื่อสลับหน้าอัตโนมัติ

import 'package:flutter/material.dart';
import 'durian_supabase_service.dart';
import 'durian_create_farm_screen.dart';

class LoginScreen extends StatefulWidget {
  final SupabaseService service;
  final VoidCallback onLoggedIn;
  const LoginScreen({required this.service, required this.onLoggedIn, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  bool isSignup = false;
  bool loading = false;
  String? error;

  static const green = Color(0xFF2F6B3C);
  static const bg = Color(0xFFF6F7F2);
  static const surface2 = Color(0xFFF0F2EC);
  static const border = Color(0xFFE1E5DA);
  static const red = Color(0xFFB23A3A);

  Future<void> _submit() async {
    setState(() { loading = true; error = null; });
    try {
      if (isSignup) {
        await widget.service.signUp(emailCtrl.text.trim(), passwordCtrl.text, nameCtrl.text.trim());
        setState(() => error = 'สมัครสำเร็จ กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ');
      } else {
        await widget.service.signIn(emailCtrl.text.trim(), passwordCtrl.text);
        final farms = await widget.service.myFarms();
        if (farms.isEmpty) {
          if (!mounted) return;
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => CreateFarmScreen(service: widget.service)),
          );
          if (created == true) {
            widget.onLoggedIn();
          }
        } else {
          widget.service.farmId = farms.first['id'] as String;
          widget.onLoggedIn();
        }
      }
    } catch (e) {
      setState(() => error = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => loading = false);
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
                const Text('Durian Smart Farm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(isSignup ? 'สร้างบัญชีใหม่' : 'เข้าสู่ระบบเพื่อจัดการสวน',
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                const SizedBox(height: 18),
                if (isSignup) ...[
                  _field('ชื่อ-นามสกุล', nameCtrl),
                  const SizedBox(height: 10),
                ],
                _field('อีเมล', emailCtrl, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field('รหัสผ่าน', passwordCtrl, obscure: true),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: red, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(loading ? 'กำลังดำเนินการ...' : (isSignup ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ')),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => isSignup = !isSignup),
                    child: Text(
                      isSignup ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool obscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
      ),
    );
  }
}
