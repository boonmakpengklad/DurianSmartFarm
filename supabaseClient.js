// src/lib/supabaseClient.js
// ตั้งค่า Supabase client ฝั่ง Web
// ต้องติดตั้งก่อน: npm install @supabase/supabase-js
//
// ใส่ค่าจริงใน .env (Vite):
//   VITE_SUPABASE_URL=https://xxxx.supabase.co
//   VITE_SUPABASE_ANON_KEY=xxxxx

import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn(
    "[Supabase] ไม่พบ VITE_SUPABASE_URL หรือ VITE_SUPABASE_ANON_KEY ใน .env"
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});
