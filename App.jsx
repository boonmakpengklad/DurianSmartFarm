import React, { useState, useEffect, useCallback } from "react";
import {
  Home, TreeDeciduous, ClipboardList, FlaskConical, Plus, X, Search,
  SlidersHorizontal, AlertTriangle, TrendingUp, TrendingDown, Wallet,
  MapPin, Leaf, Sprout, LogOut
} from "lucide-react";
import {
  ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid,
  LineChart, Line
} from "recharts";

import { AuthGate, useAuth } from "./AuthGate";
import {
  getDashboardKpis, listActiveAlerts, listTrees, addTree,
  listOperations, addOperation, listHarvest, addHarvest,
  listSoilReadings, addSoilReading, addTransaction,
} from "./api";

/* ============================================================
   DESIGN TOKENS (เหมือนเดิม)
   ============================================================ */
const TOKENS = `
  @import url('https://fonts.googleapis.com/css2?family=Prompt:wght@500;600;700&family=Noto+Sans+Thai:wght@400;500;600&display=swap');
  .dsf {
    --bg: #F6F7F2; --surface: #FFFFFF; --surface-2: #F0F2EC;
    --ink: #1E2A20; --ink-soft: #5B6B5D; --border: #E1E5DA;
    --green: #2F6B3C; --green-soft: #E4F0E6;
    --blue: #2B6CA3; --blue-soft: #E3EEF7;
    --orange: #CE6A0B; --orange-soft: #FBEAD5;
    --red: #B23A3A; --red-soft: #F8E3E1;
    font-family: 'Noto Sans Thai', 'Prompt', sans-serif;
    background: var(--bg); color: var(--ink); min-height: 100vh;
    position: relative; padding-bottom: 88px;
  }
  .dsf .disp { font-family: 'Prompt', 'Noto Sans Thai', sans-serif; }
  .dsf .num { font-variant-numeric: tabular-nums; font-family: 'Prompt', sans-serif; }
  .spike {
    height: 6px; margin: 6px 0 14px 0;
    background-image: linear-gradient(135deg, var(--green) 25%, transparent 25%),
                       linear-gradient(225deg, var(--green) 25%, transparent 25%);
    background-size: 10px 6px; background-position: left top; background-repeat: repeat-x; opacity: 0.55;
  }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 14px; }
  .chip { border-radius: 999px; font-size: 12px; font-weight: 600; padding: 3px 10px; display: inline-flex; align-items: center; gap: 4px; }
  .rowline:not(:last-child) { border-bottom: 1px solid var(--border); }
  input.dsf-input, select.dsf-input {
    background: var(--surface-2); border: 1px solid var(--border); border-radius: 10px;
    padding: 9px 12px; font-size: 14px; width: 100%; color: var(--ink);
  }
  input.dsf-input:focus, select.dsf-input:focus { outline: 2px solid var(--green); outline-offset: 1px; }
  label.dsf-label { font-size: 12px; font-weight: 600; color: var(--ink-soft); margin-bottom: 4px; display: block; }
`;

const TONE = {
  green: { fg: "var(--green)", bg: "var(--green-soft)" },
  blue: { fg: "var(--blue)", bg: "var(--blue-soft)" },
  orange: { fg: "var(--orange)", bg: "var(--orange-soft)" },
  red: { fg: "var(--red)", bg: "var(--red-soft)" },
};
const SEVERITY_TONE = { severe: "red", warning: "orange", info: "blue" };
const HEALTH_TONE = { healthy: "green", watch: "orange", sick: "red", dead: "red" };
const HEALTH_LABEL = { healthy: "ปกติ", watch: "เฝ้าระวัง", sick: "ป่วย", dead: "ตาย" };

const OPERATION_TYPES = [
  { value: "fertilizer", label: "ใส่ปุ๋ย" }, { value: "spray", label: "ฉีดยา" },
  { value: "mowing", label: "ตัดหญ้า" }, { value: "watering", label: "รดน้ำ" },
  { value: "pruning", label: "ตัดแต่งกิ่ง" }, { value: "pest_control", label: "กำจัดศัตรูพืช" },
  { value: "other", label: "อื่นๆ" },
];
const EXPENSE_CATEGORIES = [
  { value: "fertilizer", label: "ปุ๋ย/สารเคมี" }, { value: "labor", label: "ค่าแรง" },
  { value: "fuel", label: "น้ำมัน" }, { value: "other", label: "อื่นๆ" },
];

/* ============================================================
   SMALL COMPONENTS
   ============================================================ */
function KpiCard({ label, value, unit, trend, icon: Icon, tone }) {
  const t = TONE[tone];
  const up = trend >= 0;
  return (
    <div className="card" style={{ padding: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div className="chip" style={{ background: t.bg, color: t.fg }}><Icon size={13} /> {unit}</div>
        {trend !== undefined && trend !== 0 && (
          <div style={{ display: "flex", alignItems: "center", gap: 2, fontSize: 12, fontWeight: 600, color: up ? "var(--green)" : "var(--red)" }}>
            {up ? <TrendingUp size={13} /> : <TrendingDown size={13} />}{Math.abs(trend)}%
          </div>
        )}
      </div>
      <div className="num" style={{ fontSize: 22, fontWeight: 700, marginTop: 8 }}>{value}</div>
      <div style={{ fontSize: 12, color: "var(--ink-soft)", marginTop: 2 }}>{label}</div>
    </div>
  );
}

function AlertRow({ a }) {
  const t = TONE[SEVERITY_TONE[a.severity] || "blue"];
  return (
    <div style={{ display: "flex", gap: 10, padding: "10px 4px" }} className="rowline">
      <div style={{ width: 30, height: 30, borderRadius: 9, background: t.bg, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
        <AlertTriangle size={15} color={t.fg} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 600 }}>{a.title}</div>
        <div style={{ fontSize: 12, color: "var(--ink-soft)" }}>{a.message}</div>
      </div>
    </div>
  );
}

function HealthChip({ health }) {
  const t = TONE[HEALTH_TONE[health] || "green"];
  return <span className="chip" style={{ background: t.bg, color: t.fg }}>{HEALTH_LABEL[health] || health}</span>;
}

function GridShell({ title, count, onAdd, children }) {
  const [q, setQ] = useState("");
  return (
    <div className="card" style={{ padding: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
        <div className="disp" style={{ fontWeight: 700, fontSize: 15 }}>{title} <span style={{ color: "var(--ink-soft)", fontWeight: 500, fontSize: 13 }}>({count})</span></div>
        <button onClick={onAdd} style={{ background: "var(--green)", color: "#fff", border: "none", borderRadius: 9, padding: "6px 10px", fontSize: 12, fontWeight: 600, display: "flex", alignItems: "center", gap: 4 }}>
          <Plus size={13} /> เพิ่ม
        </button>
      </div>
      <div style={{ display: "flex", gap: 8, marginBottom: 10 }}>
        <div style={{ flex: 1, position: "relative" }}>
          <Search size={14} style={{ position: "absolute", left: 10, top: 10, color: "var(--ink-soft)" }} />
          <input className="dsf-input" style={{ paddingLeft: 30 }} placeholder="ค้นหา..." value={q} onChange={e => setQ(e.target.value)} />
        </div>
        <button style={{ background: "var(--surface-2)", border: "1px solid var(--border)", borderRadius: 10, padding: "0 10px" }}>
          <SlidersHorizontal size={15} color="var(--ink-soft)" />
        </button>
      </div>
      {children(q)}
    </div>
  );
}

/* ============================================================
   DATA HOOK — โหลด/รีเฟรชข้อมูลทั้งหมดของสวนที่เลือก
   ============================================================ */
function useFarmData(farmId) {
  const [state, setState] = useState({
    loading: true, error: null,
    kpis: null, alerts: [], trees: [], operations: [], harvest: [], soil: [],
  });

  const refresh = useCallback(async () => {
    if (!farmId) return;
    setState(s => ({ ...s, loading: true, error: null }));
    try {
      const [kpis, alerts, trees, operations, harvest, soil] = await Promise.all([
        getDashboardKpis(farmId), listActiveAlerts(farmId), listTrees(farmId),
        listOperations(farmId), listHarvest(farmId), listSoilReadings(farmId),
      ]);
      setState({ loading: false, error: null, kpis, alerts, trees, operations, harvest, soil });
    } catch (err) {
      setState(s => ({ ...s, loading: false, error: err.message }));
    }
  }, [farmId]);

  useEffect(() => { refresh(); }, [refresh]);

  return { ...state, refresh };
}

function monthlyYield(harvest) {
  const buckets = {};
  harvest.forEach(h => {
    const m = h.harvest_date?.slice(0, 7); // YYYY-MM
    if (!m) return;
    buckets[m] = (buckets[m] || 0) + Number(h.weight_kg || 0);
  });
  return Object.entries(buckets).sort().slice(-6).map(([m, kg]) => ({ m: m.slice(5), kg }));
}

/* ============================================================
   TAB VIEWS
   ============================================================ */
function DashboardView({ data, onOpenQuick }) {
  const { kpis, alerts, harvest, loading } = data;
  const cards = kpis ? [
    { label: "ต้นทุเรียนทั้งหมด", value: kpis.total_trees, unit: "ต้น", icon: TreeDeciduous, tone: "green" },
    { label: "ผลผลิตเดือนนี้", value: Number(kpis.yield_mtd_kg).toLocaleString(), unit: "กก.", icon: Sprout, tone: "green" },
    { label: "รายรับเดือนนี้", value: Number(kpis.revenue_mtd).toLocaleString(), unit: "บาท", icon: Wallet, tone: "blue" },
    { label: "กำไรสุทธิ", value: Number(kpis.revenue_mtd - kpis.expense_mtd).toLocaleString(), unit: "บาท", icon: TrendingUp, tone: "blue" },
    { label: "งานค้าง", value: kpis.open_tasks, unit: "รายการ", icon: ClipboardList, tone: "orange" },
    { label: "ต้นที่ป่วย", value: kpis.sick_trees, unit: "ต้น", icon: Leaf, tone: "red" },
  ] : [];

  return (
    <div style={{ display: "grid", gap: 14 }}>
      <div>
        <div className="disp" style={{ fontSize: 18, fontWeight: 700 }}>ภาพรวมสวน</div>
        <div className="spike" />
        {loading && !kpis ? <div style={{ color: "var(--ink-soft)", fontSize: 13 }}>กำลังโหลดข้อมูล...</div> : (
          <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 10 }}>
            {cards.map((k, i) => <KpiCard key={i} {...k} />)}
          </div>
        )}
      </div>

      <div className="card" style={{ padding: 14 }}>
        <div className="disp" style={{ fontWeight: 700, fontSize: 15, marginBottom: 4 }}>ผลผลิตรายเดือน (กก.)</div>
        <div style={{ height: 130 }}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={monthlyYield(harvest)}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
              <XAxis dataKey="m" tick={{ fontSize: 11, fill: "var(--ink-soft)" }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: "var(--ink-soft)" }} axisLine={false} tickLine={false} width={30} />
              <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
              <Bar dataKey="kg" fill="var(--green)" radius={[5, 5, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="card" style={{ padding: 14 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}>
          <div className="disp" style={{ fontWeight: 700, fontSize: 15 }}>การแจ้งเตือนที่ต้องดำเนินการ</div>
          <span className="chip" style={{ background: "var(--red-soft)", color: "var(--red)" }}>{alerts.length} รายการ</span>
        </div>
        {alerts.length === 0 && <div style={{ fontSize: 13, color: "var(--ink-soft)", padding: "6px 0" }}>ไม่มีการแจ้งเตือนขณะนี้</div>}
        {alerts.map(a => <AlertRow key={a.id} a={a} />)}
      </div>
    </div>
  );
}

function TreesView({ trees, onOpenQuick }) {
  return (
    <GridShell title="ทะเบียนต้นทุเรียน" count={trees.length} onAdd={() => onOpenQuick("tree")}>
      {(q) => {
        const rows = trees.filter(t => (t.tree_code + t.variety).toLowerCase().includes(q.toLowerCase()));
        return (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12.5 }}>
              <thead>
                <tr style={{ textAlign: "left", color: "var(--ink-soft)" }}>
                  <th style={{ padding: "4px 6px" }}>รหัส</th><th style={{ padding: "4px 6px" }}>พันธุ์</th>
                  <th style={{ padding: "4px 6px" }}>วันที่ปลูก</th><th style={{ padding: "4px 6px" }}>สุขภาพ</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((t) => (
                  <tr key={t.id} className="rowline">
                    <td className="num" style={{ padding: "7px 6px", fontWeight: 600 }}>{t.tree_code}</td>
                    <td style={{ padding: "7px 6px" }}>{t.variety}</td>
                    <td style={{ padding: "7px 6px" }}>{t.planted_date || "-"}</td>
                    <td style={{ padding: "7px 6px" }}><HealthChip health={t.health_status} /></td>
                  </tr>
                ))}
                {rows.length === 0 && <tr><td colSpan={4} style={{ padding: 10, color: "var(--ink-soft)" }}>ยังไม่มีข้อมูล</td></tr>}
              </tbody>
            </table>
          </div>
        );
      }}
    </GridShell>
  );
}

function OperationsView({ operations, onOpenQuick }) {
  return (
    <GridShell title="บันทึกกิจกรรมสวน" count={operations.length} onAdd={() => onOpenQuick("operation")}>
      {(q) => {
        const rows = operations.filter(o => (o.operation_type || "").toLowerCase().includes(q.toLowerCase()));
        return (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12.5 }}>
              <thead>
                <tr style={{ textAlign: "left", color: "var(--ink-soft)" }}>
                  <th style={{ padding: "4px 6px" }}>วันที่</th><th style={{ padding: "4px 6px" }}>ประเภท</th>
                  <th style={{ padding: "4px 6px" }}>รายละเอียด</th><th style={{ padding: "4px 6px" }}>ค่าใช้จ่าย</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((o) => (
                  <tr key={o.id} className="rowline">
                    <td style={{ padding: "7px 6px" }}>{o.performed_at?.slice(0, 10)}</td>
                    <td style={{ padding: "7px 6px" }}>
                      <span className="chip" style={{ background: "var(--green-soft)", color: "var(--green)" }}>
                        {OPERATION_TYPES.find(x => x.value === o.operation_type)?.label || o.operation_type}
                      </span>
                    </td>
                    <td style={{ padding: "7px 6px" }}>{o.description || "-"}</td>
                    <td className="num" style={{ padding: "7px 6px" }}>{o.cost ? `฿${Number(o.cost).toLocaleString()}` : "-"}</td>
                  </tr>
                ))}
                {rows.length === 0 && <tr><td colSpan={4} style={{ padding: 10, color: "var(--ink-soft)" }}>ยังไม่มีข้อมูล</td></tr>}
              </tbody>
            </table>
          </div>
        );
      }}
    </GridShell>
  );
}

function SoilView({ soil, onOpenQuick }) {
  const trend = [...soil].sort((a, b) => a.reading_date.localeCompare(b.reading_date)).map(s => ({ d: s.reading_date.slice(5), ph: s.ph }));
  return (
    <div style={{ display: "grid", gap: 14 }}>
      <div className="card" style={{ padding: 14 }}>
        <div className="disp" style={{ fontWeight: 700, fontSize: 15, marginBottom: 4 }}>แนวโน้มค่า pH</div>
        <div style={{ height: 110 }}>
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={trend}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
              <XAxis dataKey="d" tick={{ fontSize: 11, fill: "var(--ink-soft)" }} axisLine={false} tickLine={false} />
              <YAxis domain={[0, 14]} tick={{ fontSize: 11, fill: "var(--ink-soft)" }} axisLine={false} tickLine={false} width={26} />
              <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
              <Line type="monotone" dataKey="ph" stroke="var(--blue)" strokeWidth={2} dot={{ r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>
      <GridShell title="ผลวิเคราะห์ดิน" count={soil.length} onAdd={() => onOpenQuick("soil")}>
        {(q) => {
          const rows = soil.filter(s => (s.notes || "").toLowerCase().includes(q.toLowerCase()));
          return (
            <div style={{ overflowX: "auto" }}>
              <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12.5 }}>
                <thead>
                  <tr style={{ textAlign: "left", color: "var(--ink-soft)" }}>
                    <th style={{ padding: "4px 6px" }}>วันที่</th><th style={{ padding: "4px 6px" }}>pH</th>
                    <th style={{ padding: "4px 6px" }}>EC</th><th style={{ padding: "4px 6px" }}>P</th><th style={{ padding: "4px 6px" }}>K</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((s) => (
                    <tr key={s.id} className="rowline">
                      <td style={{ padding: "7px 6px" }}>{s.reading_date}</td>
                      <td className="num" style={{ padding: "7px 6px" }}>{s.ph}</td>
                      <td className="num" style={{ padding: "7px 6px" }}>{s.ec}</td>
                      <td className="num" style={{ padding: "7px 6px" }}>{s.p}</td>
                      <td className="num" style={{ padding: "7px 6px" }}>{s.k}</td>
                    </tr>
                  ))}
                  {rows.length === 0 && <tr><td colSpan={5} style={{ padding: 10, color: "var(--ink-soft)" }}>ยังไม่มีข้อมูล</td></tr>}
                </tbody>
              </table>
            </div>
          );
        }}
      </GridShell>
    </div>
  );
}

/* ============================================================
   QUICK ACTION MODAL — ฟอร์มจริง เขียนลง Supabase แล้วรีเฟรช
   ============================================================ */
function QuickActionModal({ mode, farmId, trees, onClose, onSaved }) {
  const [form, setForm] = useState(mode || "menu");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  // form field state
  const [treeCode, setTreeCode] = useState("");
  const [variety, setVariety] = useState("หมอนทอง");
  const [plantedDate, setPlantedDate] = useState("");
  const [healthStatus, setHealthStatus] = useState("healthy");

  const [readingDate, setReadingDate] = useState("");
  const [ph, setPh] = useState("");
  const [ec, setEc] = useState("");
  const [om, setOm] = useState("");
  const [p, setP] = useState("");
  const [k, setK] = useState("");

  const [opTreeId, setOpTreeId] = useState("");
  const [opType, setOpType] = useState("fertilizer");
  const [opDate, setOpDate] = useState("");
  const [opCost, setOpCost] = useState("");
  const [opDesc, setOpDesc] = useState("");

  const [txType, setTxType] = useState("expense");
  const [txCategory, setTxCategory] = useState("fertilizer");
  const [txAmount, setTxAmount] = useState("");
  const [txDate, setTxDate] = useState("");
  const [txDesc, setTxDesc] = useState("");

  const Header = ({ title }) => (
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
      <div className="disp" style={{ fontWeight: 700, fontSize: 16 }}>{title}</div>
      <button onClick={onClose} style={{ background: "var(--surface-2)", border: "none", borderRadius: 8, padding: 6 }}>
        <X size={16} color="var(--ink-soft)" />
      </button>
    </div>
  );

  async function submitTree() {
    setSaving(true); setError("");
    try {
      if (!treeCode) throw new Error("กรุณากรอกรหัสต้น");
      await addTree(farmId, { tree_code: treeCode, variety, planted_date: plantedDate || null, health_status: healthStatus });
      onSaved();
    } catch (e) { setError(e.message); } finally { setSaving(false); }
  }

  async function submitSoil() {
    setSaving(true); setError("");
    try {
      const phVal = ph === "" ? null : Number(ph);
      if (phVal !== null && (phVal < 0 || phVal > 14)) throw new Error("ค่า pH ต้องอยู่ระหว่าง 0–14");
      await addSoilReading(farmId, {
        reading_date: readingDate || new Date().toISOString().slice(0, 10),
        ph: phVal, ec: ec === "" ? null : Number(ec), om: om === "" ? null : Number(om),
        p: p === "" ? null : Number(p), k: k === "" ? null : Number(k),
      });
      onSaved();
    } catch (e) { setError(e.message); } finally { setSaving(false); }
  }

  async function submitOperation() {
    setSaving(true); setError("");
    try {
      await addOperation(farmId, {
        tree_id: opTreeId || null, operation_type: opType, description: opDesc,
        cost: opCost === "" ? 0 : Number(opCost),
        performed_at: opDate ? new Date(opDate).toISOString() : new Date().toISOString(),
      });
      onSaved();
    } catch (e) { setError(e.message); } finally { setSaving(false); }
  }

  async function submitExpense() {
    setSaving(true); setError("");
    try {
      if (!txAmount) throw new Error("กรุณากรอกจำนวนเงิน");
      await addTransaction(farmId, {
        transaction_type: txType, category: txCategory, amount: Number(txAmount),
        transaction_date: txDate || new Date().toISOString().slice(0, 10), description: txDesc,
      });
      onSaved();
    } catch (e) { setError(e.message); } finally { setSaving(false); }
  }

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(30,42,32,0.45)", display: "flex", alignItems: "flex-end", justifyContent: "center", zIndex: 50 }} onClick={onClose}>
      <div className="dsf" style={{ background: "var(--surface)", width: "100%", maxWidth: 480, borderRadius: "18px 18px 0 0", padding: 18, maxHeight: "82vh", overflowY: "auto" }} onClick={e => e.stopPropagation()}>
        {form === "menu" && (
          <>
            <Header title="เพิ่มข้อมูลด่วน" />
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              {[
                { key: "operation", label: "บันทึกกิจกรรม", tone: "green" },
                { key: "tree", label: "ลงทะเบียนต้น", tone: "green" },
                { key: "soil", label: "วิเคราะห์ดิน", tone: "blue" },
                { key: "expense", label: "รายรับ-รายจ่าย", tone: "orange" },
              ].map((o, i) => {
                const t = TONE[o.tone];
                return (
                  <button key={i} onClick={() => setForm(o.key)} style={{ background: t.bg, border: "none", borderRadius: 12, padding: 16, fontSize: 13, fontWeight: 600, color: t.fg }}>
                    {o.label}
                  </button>
                );
              })}
            </div>
          </>
        )}

        {form === "tree" && (
          <>
            <Header title="ลงทะเบียนต้นทุเรียน" />
            <div style={{ display: "grid", gap: 10 }}>
              <div><label className="dsf-label">รหัสต้น</label><input className="dsf-input" placeholder="เช่น A-022" value={treeCode} onChange={e => setTreeCode(e.target.value)} /></div>
              <div><label className="dsf-label">พันธุ์</label>
                <select className="dsf-input" value={variety} onChange={e => setVariety(e.target.value)}>
                  <option>หมอนทอง</option><option>ก้านยาว</option><option>ชะนี</option><option>อื่นๆ</option>
                </select>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                <div><label className="dsf-label">วันที่ปลูก</label><input type="date" className="dsf-input" value={plantedDate} onChange={e => setPlantedDate(e.target.value)} /></div>
                <div><label className="dsf-label">สถานะสุขภาพ</label>
                  <select className="dsf-input" value={healthStatus} onChange={e => setHealthStatus(e.target.value)}>
                    <option value="healthy">ปกติ</option><option value="watch">เฝ้าระวัง</option><option value="sick">ป่วย</option>
                  </select>
                </div>
              </div>
              {error && <div style={{ color: "var(--red)", fontSize: 12 }}>{error}</div>}
              <button disabled={saving} onClick={submitTree} style={{ marginTop: 6, background: "var(--green)", color: "#fff", border: "none", borderRadius: 10, padding: "11px", fontWeight: 600, fontSize: 14 }}>
                {saving ? "กำลังบันทึก..." : "บันทึกต้นทุเรียน"}
              </button>
            </div>
          </>
        )}

        {form === "soil" && (
          <>
            <Header title="บันทึกผลวิเคราะห์ดิน" />
            <div style={{ display: "grid", gap: 10 }}>
              <div><label className="dsf-label">วันที่เก็บตัวอย่าง</label><input type="date" className="dsf-input" value={readingDate} onChange={e => setReadingDate(e.target.value)} /></div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                <div><label className="dsf-label">pH (0–14)</label><input type="number" step="0.1" min="0" max="14" className="dsf-input" value={ph} onChange={e => setPh(e.target.value)} /></div>
                <div><label className="dsf-label">EC (dS/m)</label><input type="number" step="0.1" className="dsf-input" value={ec} onChange={e => setEc(e.target.value)} /></div>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                <div><label className="dsf-label">OM (%)</label><input type="number" step="0.1" className="dsf-input" value={om} onChange={e => setOm(e.target.value)} /></div>
                <div><label className="dsf-label">P (mg/kg)</label><input type="number" className="dsf-input" value={p} onChange={e => setP(e.target.value)} /></div>
              </div>
              <div><label className="dsf-label">K (mg/kg)</label><input type="number" className="dsf-input" value={k} onChange={e => setK(e.target.value)} /></div>
              {error && <div style={{ color: "var(--red)", fontSize: 12 }}>{error}</div>}
              <button disabled={saving} onClick={submitSoil} style={{ marginTop: 6, background: "var(--blue)", color: "#fff", border: "none", borderRadius: 10, padding: "11px", fontWeight: 600, fontSize: 14 }}>
                {saving ? "กำลังบันทึก..." : "บันทึกผลวิเคราะห์ดิน"}
              </button>
            </div>
          </>
        )}

        {form === "operation" && (
          <>
            <Header title="บันทึกกิจกรรมสวน" />
            <div style={{ display: "grid", gap: 10 }}>
              <div><label className="dsf-label">ต้น (ไม่ระบุ = ทั้งสวน)</label>
                <select className="dsf-input" value={opTreeId} onChange={e => setOpTreeId(e.target.value)}>
                  <option value="">-- ไม่ระบุ --</option>
                  {trees.map(t => <option key={t.id} value={t.id}>{t.tree_code}</option>)}
                </select>
              </div>
              <div><label className="dsf-label">ประเภท</label>
                <select className="dsf-input" value={opType} onChange={e => setOpType(e.target.value)}>
                  {OPERATION_TYPES.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                <div><label className="dsf-label">วันที่</label><input type="date" className="dsf-input" value={opDate} onChange={e => setOpDate(e.target.value)} /></div>
                <div><label className="dsf-label">ค่าใช้จ่าย (บาท)</label><input type="number" className="dsf-input" value={opCost} onChange={e => setOpCost(e.target.value)} /></div>
              </div>
              <div><label className="dsf-label">หมายเหตุ</label><input className="dsf-input" value={opDesc} onChange={e => setOpDesc(e.target.value)} /></div>
              {error && <div style={{ color: "var(--red)", fontSize: 12 }}>{error}</div>}
              <button disabled={saving} onClick={submitOperation} style={{ marginTop: 6, background: "var(--orange)", color: "#fff", border: "none", borderRadius: 10, padding: "11px", fontWeight: 600, fontSize: 14 }}>
                {saving ? "กำลังบันทึก..." : "บันทึก"}
              </button>
            </div>
          </>
        )}

        {form === "expense" && (
          <>
            <Header title="รายรับ-รายจ่าย" />
            <div style={{ display: "grid", gap: 10 }}>
              <div><label className="dsf-label">ประเภท</label>
                <select className="dsf-input" value={txType} onChange={e => setTxType(e.target.value)}>
                  <option value="expense">รายจ่าย</option><option value="income">รายรับ</option>
                </select>
              </div>
              <div><label className="dsf-label">หมวด</label>
                <select className="dsf-input" value={txCategory} onChange={e => setTxCategory(e.target.value)}>
                  {txType === "expense"
                    ? EXPENSE_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)
                    : <><option value="harvest_sale">ขายผลผลิต</option><option value="other">อื่นๆ</option></>}
                </select>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                <div><label className="dsf-label">วันที่</label><input type="date" className="dsf-input" value={txDate} onChange={e => setTxDate(e.target.value)} /></div>
                <div><label className="dsf-label">จำนวนเงิน (บาท)</label><input type="number" className="dsf-input" value={txAmount} onChange={e => setTxAmount(e.target.value)} /></div>
              </div>
              <div><label className="dsf-label">หมายเหตุ</label><input className="dsf-input" value={txDesc} onChange={e => setTxDesc(e.target.value)} /></div>
              {error && <div style={{ color: "var(--red)", fontSize: 12 }}>{error}</div>}
              <button disabled={saving} onClick={submitExpense} style={{ marginTop: 6, background: "var(--orange)", color: "#fff", border: "none", borderRadius: 10, padding: "11px", fontWeight: 600, fontSize: 14 }}>
                {saving ? "กำลังบันทึก..." : "บันทึก"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* ============================================================
   ROOT (ใช้จริงในโปรเจกต์)
   ============================================================ */
function DurianDashboardContent() {
  const { user, farmId, farms, setFarmId, signOut } = useAuth();
  const data = useFarmData(farmId);
  const [tab, setTab] = useState("dashboard");
  const [quick, setQuick] = useState(null);

  const NAV = [
    { key: "dashboard", label: "ภาพรวม", icon: Home },
    { key: "trees", label: "ต้นไม้", icon: TreeDeciduous },
    { key: "quick", label: "", icon: Plus },
    { key: "operations", label: "กิจกรรม", icon: ClipboardList },
    { key: "soil", label: "ดิน", icon: FlaskConical },
  ];

  return (
    <div className="dsf">
      <style>{TOKENS}</style>

      <div style={{ position: "sticky", top: 0, zIndex: 10, background: "var(--bg)", padding: "14px 16px 6px 16px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <div className="disp" style={{ fontWeight: 700, fontSize: 17 }}>
            {farms.find(f => f.id === farmId)?.name || "สวนทุเรียน"}
          </div>
          <div style={{ fontSize: 12, color: "var(--ink-soft)", display: "flex", alignItems: "center", gap: 4 }}>
            <MapPin size={12} /> {user?.email}
          </div>
        </div>
        <button onClick={signOut} title="ออกจากระบบ" style={{ background: "var(--surface-2)", border: "1px solid var(--border)", borderRadius: "50%", width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <LogOut size={16} color="var(--ink-soft)" />
        </button>
      </div>

      {data.error && (
        <div style={{ margin: "0 16px", padding: 10, background: "var(--red-soft)", color: "var(--red)", borderRadius: 10, fontSize: 13 }}>
          โหลดข้อมูลไม่สำเร็จ: {data.error}
        </div>
      )}

      <div style={{ padding: "8px 16px 0 16px", maxWidth: 640, margin: "0 auto" }}>
        {tab === "dashboard" && <DashboardView data={data} onOpenQuick={setQuick} />}
        {tab === "trees" && <TreesView trees={data.trees} onOpenQuick={setQuick} />}
        {tab === "operations" && <OperationsView operations={data.operations} onOpenQuick={setQuick} />}
        {tab === "soil" && <SoilView soil={data.soil} onOpenQuick={setQuick} />}
      </div>

      <div style={{ position: "fixed", bottom: 0, left: 0, right: 0, background: "var(--surface)", borderTop: "1px solid var(--border)", display: "flex", justifyContent: "space-around", alignItems: "center", padding: "8px 10px calc(8px + env(safe-area-inset-bottom))", zIndex: 20 }}>
        {NAV.map((n, i) => {
          if (n.key === "quick") {
            return (
              <button key={i} onClick={() => setQuick("menu")} style={{ background: "var(--green)", border: "none", borderRadius: "50%", width: 46, height: 46, display: "flex", alignItems: "center", justifyContent: "center", marginTop: -22, boxShadow: "0 4px 10px rgba(47,107,60,0.35)" }}>
                <Plus size={22} color="#fff" />
              </button>
            );
          }
          const Icon = n.icon;
          const active = tab === n.key;
          return (
            <button key={i} onClick={() => setTab(n.key)} style={{ background: "none", border: "none", display: "flex", flexDirection: "column", alignItems: "center", gap: 3, padding: "4px 10px", color: active ? "var(--green)" : "var(--ink-soft)" }}>
              <Icon size={20} strokeWidth={active ? 2.4 : 2} />
              <span style={{ fontSize: 10.5, fontWeight: active ? 700 : 500 }}>{n.label}</span>
            </button>
          );
        })}
      </div>

      {quick && (
        <QuickActionModal
          mode={quick === "menu" ? "menu" : quick}
          farmId={farmId}
          trees={data.trees}
          onClose={() => setQuick(null)}
          onSaved={() => { setQuick(null); data.refresh(); }}
        />
      )}
    </div>
  );
}

export default function App() {
  return (
    <AuthGate>
      <DurianDashboardContent />
    </AuthGate>
  );
}
