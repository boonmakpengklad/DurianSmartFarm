// src/lib/AuthGate.jsx
// Auth Context + หน้า Login/Signup — ครอบ <App /> ด้วย <AuthGate> เพื่อบังคับ login ก่อนเข้าระบบ
//
// การใช้งานใน main.jsx:
//   import { AuthGate, useAuth } from "./lib/AuthGate";
//   <AuthGate><App /></AuthGate>
// แล้วในหน้าไหนก็ตาม เรียก const { user, farmId, signOut } = useAuth();

import React, { createContext, useContext, useEffect, useState } from "react";
import { supabase } from "./supabaseClient";

const AuthContext = createContext(null);
export const useAuth = () => useContext(AuthContext);

export function AuthGate({ children }) {
  const [session, setSession] = useState(undefined); // undefined = กำลังโหลด
  const [farms, setFarms] = useState([]);
  const [farmId, setFarmId] = useState(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_event, sess) => {
      setSession(sess);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  // โหลดรายชื่อสวนที่ผู้ใช้เป็นสมาชิก หลัง login สำเร็จ
  useEffect(() => {
    if (!session) return;
    (async () => {
      const { data, error } = await supabase
        .from("farms")
        .select("id, name")
        .order("created_at", { ascending: true });
      if (!error && data) {
        setFarms(data);
        if (data.length > 0) setFarmId(data[0].id);
      }
    })();
  }, [session]);

  if (session === undefined) {
    return <CenteredMessage text="กำลังตรวจสอบสถานะการเข้าสู่ระบบ..." />;
  }

  if (!session) {
    return <LoginScreen />;
  }

  if (farms.length === 0) {
    return <CreateFirstFarmScreen onCreated={(id) => { setFarmId(id); setFarms([{ id }]); }} />;
  }

  return (
    <AuthContext.Provider
      value={{
        user: session.user,
        farmId,
        farms,
        setFarmId,
        signOut: () => supabase.auth.signOut(),
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

function CenteredMessage({ text }) {
  return (
    <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", color: "#5B6B5D" }}>
      {text}
    </div>
  );
}

function LoginScreen() {
  const [mode, setMode] = useState("login"); // login | signup
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      if (mode === "login") {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
      } else {
        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: { data: { full_name: fullName } },
        });
        if (error) throw error;
        setError("สมัครสำเร็จ กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ");
      }
    } catch (err) {
      setError(err.message || "เกิดข้อผิดพลาด");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", background: "#F6F7F2", fontFamily: "'Noto Sans Thai', sans-serif" }}>
      <form onSubmit={submit} style={{ background: "#fff", border: "1px solid #E1E5DA", borderRadius: 14, padding: 28, width: 340 }}>
        <div style={{ fontWeight: 700, fontSize: 18, marginBottom: 4 }}>Durian Smart Farm</div>
        <div style={{ fontSize: 13, color: "#5B6B5D", marginBottom: 18 }}>
          {mode === "login" ? "เข้าสู่ระบบเพื่อจัดการสวน" : "สร้างบัญชีใหม่"}
        </div>

        {mode === "signup" && (
          <Field label="ชื่อ-นามสกุล" value={fullName} onChange={setFullName} />
        )}
        <Field label="อีเมล" value={email} onChange={setEmail} type="email" />
        <Field label="รหัสผ่าน" value={password} onChange={setPassword} type="password" />

        {error && <div style={{ color: "#B23A3A", fontSize: 12, marginBottom: 10 }}>{error}</div>}

        <button type="submit" disabled={loading} style={{ width: "100%", background: "#2F6B3C", color: "#fff", border: "none", borderRadius: 10, padding: "10px", fontWeight: 600, marginTop: 4 }}>
          {loading ? "กำลังดำเนินการ..." : mode === "login" ? "เข้าสู่ระบบ" : "สมัครสมาชิก"}
        </button>

        <div style={{ textAlign: "center", fontSize: 12, color: "#5B6B5D", marginTop: 14 }}>
          {mode === "login" ? (
            <>ยังไม่มีบัญชี? <a href="#" onClick={(e) => { e.preventDefault(); setMode("signup"); }}>สมัครสมาชิก</a></>
          ) : (
            <>มีบัญชีอยู่แล้ว? <a href="#" onClick={(e) => { e.preventDefault(); setMode("login"); }}>เข้าสู่ระบบ</a></>
          )}
        </div>
      </form>
    </div>
  );
}

function Field({ label, value, onChange, type = "text" }) {
  return (
    <div style={{ marginBottom: 12 }}>
      <label style={{ fontSize: 12, fontWeight: 600, color: "#5B6B5D", display: "block", marginBottom: 4 }}>{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required
        style={{ width: "100%", background: "#F0F2EC", border: "1px solid #E1E5DA", borderRadius: 8, padding: "8px 10px", fontSize: 14 }}
      />
    </div>
  );
}

function CreateFirstFarmScreen({ onCreated }) {
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const create = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    const { data: userData } = await supabase.auth.getUser();
    const { data, error } = await supabase
      .from("farms")
      .insert({ name, owner_id: userData.user.id })
      .select()
      .single();
    setLoading(false);
    if (error) { setError(error.message); return; }
    onCreated(data.id);
  };

  return (
    <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", background: "#F6F7F2" }}>
      <form onSubmit={create} style={{ background: "#fff", border: "1px solid #E1E5DA", borderRadius: 14, padding: 28, width: 340 }}>
        <div style={{ fontWeight: 700, fontSize: 16, marginBottom: 6 }}>สร้างสวนแรกของคุณ</div>
        <div style={{ fontSize: 13, color: "#5B6B5D", marginBottom: 16 }}>ยังไม่มีสวนในบัญชีนี้ ตั้งชื่อสวนเพื่อเริ่มต้นใช้งาน</div>
        <Field label="ชื่อสวน" value={name} onChange={setName} />
        {error && <div style={{ color: "#B23A3A", fontSize: 12, marginBottom: 10 }}>{error}</div>}
        <button type="submit" disabled={loading} style={{ width: "100%", background: "#2F6B3C", color: "#fff", border: "none", borderRadius: 10, padding: "10px", fontWeight: 600 }}>
          {loading ? "กำลังสร้าง..." : "สร้างสวน"}
        </button>
      </form>
    </div>
  );
}
