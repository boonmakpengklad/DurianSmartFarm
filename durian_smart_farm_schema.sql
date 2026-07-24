-- ============================================================
-- Durian Smart Farm - Supabase (PostgreSQL) Schema
-- ออกแบบสำหรับ Web App / Desktop App (PyQt6) / Mobile App (Flutter)
-- ============================================================
-- หมายเหตุ:
--   - ใช้ auth.users ของ Supabase Auth เป็นฐาน แล้วขยายด้วยตาราง profiles
--   - เฟส 1 = ต้องมีก่อนเปิดใช้งานจริง
--   - เฟส 2 = เพิ่มหลังระบบหลักนิ่งแล้ว (Soil, Photos, AI Chat, Reports)
--   - เฟส 3 = ฟีเจอร์เสริม (Notification, Offline sync, AI Vision)
-- ============================================================

create extension if not exists "uuid-ossp";

-- ============================================================
-- เฟส 1: CORE
-- ============================================================

-- โปรไฟล์ผู้ใช้ (ขยายจาก auth.users)
create table profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null,
    phone text,
    avatar_url text,
    global_role text not null default 'worker'
        check (global_role in ('admin', 'manager', 'worker')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- สวน/ฟาร์ม (รองรับหลายสวน)
create table farms (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    address text,
    area_rai numeric(10,2),
    latitude double precision,
    longitude double precision,
    boundary_geojson jsonb,          -- ขอบเขตสวน (polygon) สำหรับ Leaflet
    owner_id uuid references profiles(id),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- สิทธิ์การเข้าถึงสวนรายคน (multi-farm access + role ต่อสวน)
create table farm_members (
    farm_id uuid references farms(id) on delete cascade,
    user_id uuid references profiles(id) on delete cascade,
    farm_role text not null default 'worker'
        check (farm_role in ('admin', 'manager', 'worker')),
    joined_at timestamptz not null default now(),
    primary key (farm_id, user_id)
);

-- ต้นทุเรียน
create table trees (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    tree_code text not null,          -- รหัสต้น เช่น A-001
    variety text,                     -- พันธุ์ เช่น หมอนทอง, ก้านยาว
    planted_date date,
    latitude double precision,
    longitude double precision,
    health_status text default 'healthy'
        check (health_status in ('healthy', 'watch', 'sick', 'dead')),
    qr_code_url text,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (farm_id, tree_code)
);

-- กิจกรรมสวน (ใส่ปุ๋ย / ฉีดยา / ตัดหญ้า / รดน้ำ / ตัดแต่งกิ่ง ฯลฯ)
create table operations (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    tree_id uuid references trees(id) on delete set null,   -- null = ทั้งสวน
    operation_type text not null
        check (operation_type in ('fertilizer','spray','mowing','pruning','watering','pest_control','other')),
    description text,
    cost numeric(12,2) default 0,
    performed_by uuid references profiles(id),
    performed_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

-- งาน/เช็คลิสต์รายวัน
create table tasks (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    title text not null,
    description text,
    assigned_to uuid references profiles(id),
    due_date date,
    priority text default 'normal' check (priority in ('low','normal','high','urgent')),
    status text default 'pending' check (status in ('pending','in_progress','done','overdue')),
    created_by uuid references profiles(id),
    created_at timestamptz not null default now(),
    completed_at timestamptz
);

-- บันทึกผลผลิต/การเก็บเกี่ยว
create table harvest_records (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    tree_id uuid references trees(id) on delete set null,
    harvest_date date not null,
    weight_kg numeric(10,2) not null,
    grade text,                       -- เกรด AB / ตกไซส์ ฯลฯ
    price_per_kg numeric(10,2),
    total_amount numeric(12,2) generated always as (weight_kg * coalesce(price_per_kg,0)) stored,
    recorded_by uuid references profiles(id),
    created_at timestamptz not null default now()
);

-- รายรับ-รายจ่าย (ใช้ทั้งรายจ่ายดำเนินงานและรายรับจากขายผลผลิต)
create table transactions (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    transaction_type text not null check (transaction_type in ('income','expense')),
    category text not null,           -- labor, fertilizer, chemical, fuel, harvest_sale, other
    amount numeric(12,2) not null,
    description text,
    transaction_date date not null,
    related_harvest_id uuid references harvest_records(id),
    created_by uuid references profiles(id),
    created_at timestamptz not null default now()
);

-- แจ้งเตือนสภาพอากาศ (ผลลัพธ์จาก OpenWeatherMap + เงื่อนไข alert)
create table weather_alerts (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    alert_type text not null check (alert_type in ('rain','heat','storm','wind')),
    severity text default 'info' check (severity in ('info','warning','severe')),
    message text,
    triggered_at timestamptz not null default now(),
    resolved boolean default false
);

-- ============================================================
-- เฟส 2: SOIL / PHOTOS / AI CHAT / REPORTS
-- ============================================================

-- ข้อมูลดิน
create table soil_readings (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    reading_date date not null,
    ph numeric(4,2),
    ec numeric(6,2),
    om numeric(6,2),
    p numeric(6,2),
    k numeric(6,2),
    ca numeric(6,2),
    mg numeric(6,2),
    notes text,
    recorded_by uuid references profiles(id),
    created_at timestamptz not null default now()
);

-- รูปภาพ (เก็บไฟล์จริงใน Supabase Storage, ตารางนี้เก็บ metadata)
create table photos (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid not null references farms(id) on delete cascade,
    tree_id uuid references trees(id) on delete set null,
    category text default 'other'
        check (category in ('tree','fruit','disease','soil','operation','damage','other')),
    storage_path text not null,       -- path ใน Supabase Storage bucket
    caption text,
    taken_by uuid references profiles(id),
    taken_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

-- ประวัติแชทกับ AI (ถามข้อมูลสวน)
create table ai_chat_logs (
    id uuid primary key default uuid_generate_v4(),
    farm_id uuid references farms(id) on delete cascade,
    user_id uuid references profiles(id),
    question text not null,
    answer text,
    created_at timestamptz not null default now()
);

-- ============================================================
-- เฟส 3: NOTIFICATION / AI VISION
-- ============================================================

create table notifications (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    farm_id uuid references farms(id) on delete cascade,
    title text not null,
    body text,
    notification_type text default 'general'
        check (notification_type in ('task','weather','harvest','system','general')),
    is_read boolean default false,
    scheduled_for timestamptz,
    created_at timestamptz not null default now()
);

-- ผลวิเคราะห์ภาพจาก AI (ใบ/โรค/ประเมินผลผลิต)
create table ai_vision_results (
    id uuid primary key default uuid_generate_v4(),
    photo_id uuid references photos(id) on delete cascade,
    analysis_type text not null check (analysis_type in ('leaf','disease','yield_estimate')),
    result_json jsonb not null,       -- ผลลัพธ์ดิบจาก Gemini Vision
    confidence numeric(5,2),
    created_at timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================
create index idx_trees_farm_id on trees(farm_id);
create index idx_operations_farm_id on operations(farm_id);
create index idx_operations_performed_at on operations(performed_at);
create index idx_tasks_farm_id_status on tasks(farm_id, status);
create index idx_harvest_farm_id_date on harvest_records(farm_id, harvest_date);
create index idx_transactions_farm_id_date on transactions(farm_id, transaction_date);
create index idx_soil_farm_id_date on soil_readings(farm_id, reading_date);
create index idx_photos_farm_id on photos(farm_id);
create index idx_notifications_user_unread on notifications(user_id, is_read);

-- ============================================================
-- ROW LEVEL SECURITY (ตัวอย่าง — ใช้ pattern เดียวกันกับทุกตารางที่มี farm_id)
-- แนวคิด: ผู้ใช้เห็น/แก้ไขได้เฉพาะข้อมูลของสวนที่ตนเป็นสมาชิก (farm_members)
-- ============================================================

alter table farms enable row level security;
alter table trees enable row level security;
alter table operations enable row level security;
alter table tasks enable row level security;
alter table harvest_records enable row level security;
alter table transactions enable row level security;

-- ผู้ใช้เห็นเฉพาะสวนที่ตนเป็นสมาชิก
create policy "farms_select_member" on farms
    for select using (
        id in (select farm_id from farm_members where user_id = auth.uid())
    );

-- ตัวอย่าง policy สำหรับตารางลูก (ใช้ pattern เดียวกันนี้กับ trees, operations, tasks, harvest_records, transactions, soil_readings, photos)
create policy "trees_select_member" on trees
    for select using (
        farm_id in (select farm_id from farm_members where user_id = auth.uid())
    );

create policy "trees_write_manager_up" on trees
    for insert with check (
        farm_id in (
            select farm_id from farm_members
            where user_id = auth.uid() and farm_role in ('admin','manager')
        )
    );

-- ============================================================
-- หมายเหตุการนำไปใช้
-- ============================================================
-- 1. รูปภาพ: สร้าง Storage bucket ชื่อ "farm-photos" ใน Supabase แล้วอ้างอิง path ในตาราง photos
-- 2. weather_cache ไม่จำเป็นต้องเก็บถาวร แนะนำ fetch สดจาก OpenWeatherMap แล้ว cache ใน memory/redis
--    หากต้องการเก็บประวัติ ค่อยเพิ่มตาราง weather_history ภายหลัง
-- 3. Realtime: เปิด Supabase Realtime บนตาราง tasks, notifications, weather_alerts
--    เพื่อให้ Dashboard/Mobile อัปเดตทันทีโดยไม่ต้อง poll
-- 4. Offline (เฟส 3, PyQt6/Flutter): ใช้ SQLite local schema แบบเดียวกัน (subset ของตารางนี้)
--    แล้ว sync ผ่าน upsert เมื่อมีอินเทอร์เน็ต โดยเพิ่มคอลัมน์ synced_at ในตารางที่ต้องการ offline
-- ============================================================
