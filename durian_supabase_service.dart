// durian_supabase_service.dart
// เชื่อม Mobile App (Flutter) เข้ากับ Supabase จริง — Auth + CRUD
//
// ติดตั้งก่อน (pubspec.yaml):
//   supabase_flutter: ^2.6.0
//
// เริ่มต้นใน main() ก่อน runApp:
//   await Supabase.initialize(url: 'https://xxxx.supabase.co', anonKey: 'xxxxx');

import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SupabaseService {
  String? farmId; // ตั้งค่าหลัง login และเลือกสวน

  // ---------------- Auth ----------------
  Future<AuthResponse> signIn(String email, String password) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password, String fullName) {
    return supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<List<Map<String, dynamic>>> myFarms() async {
    final res = await supabase.from('farms').select('id, name').order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> createFarm(String name) async {
    final userId = supabase.auth.currentUser!.id;
    final res = await supabase.from('farms').insert({'name': name, 'owner_id': userId}).select().single();
    return res;
  }

  // ---------------- Dashboard ----------------
  Future<Map<String, dynamic>> getDashboardKpis() async {
    final res = await supabase.rpc('get_dashboard_kpis', params: {'p_farm_id': farmId});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> listActiveAlerts() async {
    final res = await supabase
        .from('weather_alerts')
        .select()
        .eq('farm_id', farmId as Object)
        .eq('resolved', false)
        .order('triggered_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // ---------------- Trees ----------------
  Future<List<Map<String, dynamic>>> listTrees() async {
    final res = await supabase.from('trees').select().eq('farm_id', farmId as Object).order('tree_code');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addTree({
    required String treeCode,
    required String variety,
    String? healthStatus,
    double? latitude,
    double? longitude,
  }) async {
    final res = await supabase.from('trees').insert({
      'farm_id': farmId,
      'tree_code': treeCode,
      'variety': variety,
      'health_status': healthStatus ?? 'healthy',
      'latitude': latitude,
      'longitude': longitude,
    }).select().single();
    return res;
  }

  // ---------------- Operations ----------------
  Future<List<Map<String, dynamic>>> listOperations({int limit = 50}) async {
    final res = await supabase
        .from('operations')
        .select()
        .eq('farm_id', farmId as Object)
        .order('performed_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addOperation({
    required String operationType,
    String? description,
    num cost = 0,
    String? treeId,
  }) async {
    final res = await supabase.from('operations').insert({
      'farm_id': farmId,
      'tree_id': treeId,
      'operation_type': operationType,
      'description': description,
      'cost': cost,
    }).select().single();
    return res;
  }

  // ---------------- Soil ----------------
  Future<List<Map<String, dynamic>>> listSoilReadings({int limit = 50}) async {
    final res = await supabase
        .from('soil_readings')
        .select()
        .eq('farm_id', farmId as Object)
        .order('reading_date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addSoilReading({
    required DateTime readingDate,
    double? ph,
    double? ec,
    double? om,
    double? p,
    double? k,
  }) async {
    if (ph != null && (ph < 0 || ph > 14)) {
      throw ArgumentError('ค่า pH ต้องอยู่ระหว่าง 0–14');
    }
    final res = await supabase.from('soil_readings').insert({
      'farm_id': farmId,
      'reading_date': readingDate.toIso8601String().split('T').first,
      'ph': ph, 'ec': ec, 'om': om, 'p': p, 'k': k,
    }).select().single();
    return res;
  }

  // ---------------- Transactions ----------------
  Future<Map<String, dynamic>> addTransaction({
    required String transactionType, // 'income' | 'expense'
    required String category,
    required num amount,
    required DateTime transactionDate,
    String? description,
  }) async {
    final res = await supabase.from('transactions').insert({
      'farm_id': farmId,
      'transaction_type': transactionType,
      'category': category,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      'description': description,
    }).select().single();
    return res;
  }

  // ---------------- Realtime ----------------
  RealtimeChannel subscribeToAlerts(void Function(Map<String, dynamic>) onNewAlert) {
    final channel = supabase
        .channel('weather_alerts:$farmId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'weather_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'farm_id',
            value: farmId,
          ),
          callback: (payload) => onNewAlert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }
}
