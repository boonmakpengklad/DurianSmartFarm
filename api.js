// src/lib/api.js
// Data access layer — ทุกฟังก์ชันถูกกรองด้วย RLS ตาม role ของผู้ใช้ที่ login อยู่โดยอัตโนมัติ
import { supabase } from "./supabaseClient";

// ---------- Dashboard ----------
export async function getDashboardKpis(farmId) {
  const { data, error } = await supabase.rpc("get_dashboard_kpis", { p_farm_id: farmId });
  if (error) throw error;
  return data; // { total_trees, yield_mtd_kg, revenue_mtd, expense_mtd, open_tasks, sick_trees }
}

export async function listActiveAlerts(farmId) {
  const { data, error } = await supabase
    .from("weather_alerts")
    .select("*")
    .eq("farm_id", farmId)
    .eq("resolved", false)
    .order("triggered_at", { ascending: false });
  if (error) throw error;
  return data;
}

// ---------- Trees ----------
export async function listTrees(farmId) {
  const { data, error } = await supabase
    .from("trees")
    .select("*")
    .eq("farm_id", farmId)
    .order("tree_code");
  if (error) throw error;
  return data;
}

export async function addTree(farmId, tree) {
  // tree: { tree_code, variety, planted_date, health_status, latitude, longitude }
  const { data, error } = await supabase
    .from("trees")
    .insert({ farm_id: farmId, ...tree })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Operations ----------
export async function listOperations(farmId, { limit = 50 } = {}) {
  const { data, error } = await supabase
    .from("operations")
    .select("*, trees(tree_code)")
    .eq("farm_id", farmId)
    .order("performed_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data;
}

export async function addOperation(farmId, op) {
  // op: { tree_id, operation_type, description, cost, performed_by }
  const { data, error } = await supabase
    .from("operations")
    .insert({ farm_id: farmId, ...op })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Harvest ----------
export async function listHarvest(farmId, { limit = 50 } = {}) {
  const { data, error } = await supabase
    .from("harvest_records")
    .select("*")
    .eq("farm_id", farmId)
    .order("harvest_date", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data;
}

export async function addHarvest(farmId, record) {
  // record: { tree_id, harvest_date, weight_kg, grade, price_per_kg }
  const { data, error } = await supabase
    .from("harvest_records")
    .insert({ farm_id: farmId, ...record })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Transactions (รายรับ-รายจ่าย) ----------
export async function listTransactions(farmId, { limit = 50 } = {}) {
  const { data, error } = await supabase
    .from("transactions")
    .select("*")
    .eq("farm_id", farmId)
    .order("transaction_date", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data;
}

export async function addTransaction(farmId, tx) {
  // tx: { transaction_type: 'income'|'expense', category, amount, transaction_date, description }
  const { data, error } = await supabase
    .from("transactions")
    .insert({ farm_id: farmId, ...tx })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Soil ----------
export async function listSoilReadings(farmId, { limit = 50 } = {}) {
  const { data, error } = await supabase
    .from("soil_readings")
    .select("*")
    .eq("farm_id", farmId)
    .order("reading_date", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data;
}

export async function addSoilReading(farmId, reading) {
  // reading: { reading_date, ph, ec, om, p, k, ca, mg, notes }
  if (reading.ph !== undefined && (reading.ph < 0 || reading.ph > 14)) {
    throw new Error("ค่า pH ต้องอยู่ระหว่าง 0–14");
  }
  const { data, error } = await supabase
    .from("soil_readings")
    .insert({ farm_id: farmId, ...reading })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Tasks ----------
export async function listTasks(farmId) {
  const { data, error } = await supabase
    .from("tasks")
    .select("*")
    .eq("farm_id", farmId)
    .order("due_date", { ascending: true });
  if (error) throw error;
  return data;
}

export async function addTask(farmId, task) {
  const { data, error } = await supabase
    .from("tasks")
    .insert({ farm_id: farmId, ...task })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function updateTaskStatus(taskId, status) {
  const { data, error } = await supabase
    .from("tasks")
    .update({ status, completed_at: status === "done" ? new Date().toISOString() : null })
    .eq("id", taskId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Realtime (ตัวอย่าง: ฟัง alert ใหม่แบบสด) ----------
export function subscribeToAlerts(farmId, onNewAlert) {
  const channel = supabase
    .channel(`weather_alerts:${farmId}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "weather_alerts", filter: `farm_id=eq.${farmId}` },
      (payload) => onNewAlert(payload.new)
    )
    .subscribe();
  return () => supabase.removeChannel(channel);
}
