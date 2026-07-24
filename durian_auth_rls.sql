-- ============================================================
-- Durian Smart Farm - Auth Triggers + Full RLS Policies
-- รันไฟล์นี้ต่อจาก durian_smart_farm_schema.sql
-- ============================================================

-- ============================================================
-- 1) AUTH: สร้าง profile อัตโนมัติเมื่อสมัครสมาชิกใหม่
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, full_name, global_role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        'worker'
    );
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ============================================================
-- 2) AUTH: ผู้สร้างสวนกลายเป็น admin ของสวนนั้นโดยอัตโนมัติ
-- ============================================================
create or replace function public.handle_new_farm()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.farm_members (farm_id, user_id, farm_role)
    values (new.id, new.owner_id, 'admin')
    on conflict (farm_id, user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_farm_created on farms;
create trigger on_farm_created
    after insert on farms
    for each row execute function public.handle_new_farm();

-- ============================================================
-- 3) HELPER: เช็คสิทธิ์ต่อสวนแบบใช้ซ้ำได้ทุก policy
--    ป้องกัน infinite recursion ด้วย security definer (ข้าม RLS ของ farm_members เอง)
-- ============================================================
create or replace function public.has_farm_role(p_farm_id uuid, p_roles text[])
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1 from farm_members
        where farm_id = p_farm_id
          and user_id = auth.uid()
          and farm_role = any(p_roles)
    );
$$;

-- ============================================================
-- 4) เปิด RLS ทุกตาราง
-- ============================================================
alter table profiles enable row level security;
alter table farms enable row level security;
alter table farm_members enable row level security;
alter table trees enable row level security;
alter table operations enable row level security;
alter table tasks enable row level security;
alter table harvest_records enable row level security;
alter table transactions enable row level security;
alter table weather_alerts enable row level security;
alter table soil_readings enable row level security;
alter table photos enable row level security;
alter table ai_chat_logs enable row level security;
alter table notifications enable row level security;
alter table ai_vision_results enable row level security;

-- ล้าง policy เก่าที่เคยสร้างไว้ในไฟล์ schema หลัก (กันซ้ำ)
drop policy if exists "farms_select_member" on farms;
drop policy if exists "trees_select_member" on trees;
drop policy if exists "trees_write_manager_up" on trees;

-- ============================================================
-- 5) PROFILES — เห็นชื่อกันได้ทุกคน (ใช้แสดงคอลัมน์ "ผู้บันทึก") แก้ได้เฉพาะของตัวเอง
-- ============================================================
create policy "profiles_select_all" on profiles
    for select using (true);

create policy "profiles_update_self" on profiles
    for update using (id = auth.uid());

-- ============================================================
-- 6) FARMS — สมาชิกเห็นสวนของตัวเอง / ใครก็ตั้งสวนใหม่ได้ (กลายเป็น admin อัตโนมัติ)
--    แก้ไข/ลบได้เฉพาะ admin ของสวนนั้น
-- ============================================================
create policy "farms_select" on farms
    for select using (has_farm_role(id, array['admin','manager','worker']));

create policy "farms_insert" on farms
    for insert with check (owner_id = auth.uid());

create policy "farms_update" on farms
    for update using (has_farm_role(id, array['admin']));

create policy "farms_delete" on farms
    for delete using (has_farm_role(id, array['admin']));

-- ============================================================
-- 7) FARM_MEMBERS — สมาชิกเห็นรายชื่อทีมในสวนตน / จัดการทีมได้เฉพาะ admin
-- ============================================================
create policy "farm_members_select" on farm_members
    for select using (has_farm_role(farm_id, array['admin','manager','worker']));

create policy "farm_members_insert" on farm_members
    for insert with check (has_farm_role(farm_id, array['admin']));

create policy "farm_members_update" on farm_members
    for update using (has_farm_role(farm_id, array['admin']));

create policy "farm_members_delete" on farm_members
    for delete using (has_farm_role(farm_id, array['admin']));

-- ============================================================
-- 8) ตารางข้อมูลภาคสนาม (trees, operations, tasks, harvest, soil, photos)
--    อ่านได้ทุก role ในสวน / เพิ่มได้ทุก role (worker บันทึกหน้างานได้)
--    แก้ไขได้เฉพาะ admin+manager / ลบได้เฉพาะ admin
-- ============================================================
create policy "trees_select" on trees for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "trees_insert" on trees for insert with check (has_farm_role(farm_id, array['admin','manager']));
create policy "trees_update" on trees for update using (has_farm_role(farm_id, array['admin','manager']));
create policy "trees_delete" on trees for delete using (has_farm_role(farm_id, array['admin']));

create policy "operations_select" on operations for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "operations_insert" on operations for insert with check (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "operations_update" on operations for update using (has_farm_role(farm_id, array['admin','manager']));
create policy "operations_delete" on operations for delete using (has_farm_role(farm_id, array['admin']));

create policy "tasks_select" on tasks for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "tasks_insert" on tasks for insert with check (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "tasks_update" on tasks for update using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "tasks_delete" on tasks for delete using (has_farm_role(farm_id, array['admin','manager']));

create policy "harvest_select" on harvest_records for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "harvest_insert" on harvest_records for insert with check (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "harvest_update" on harvest_records for update using (has_farm_role(farm_id, array['admin','manager']));
create policy "harvest_delete" on harvest_records for delete using (has_farm_role(farm_id, array['admin']));

create policy "soil_select" on soil_readings for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "soil_insert" on soil_readings for insert with check (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "soil_update" on soil_readings for update using (has_farm_role(farm_id, array['admin','manager']));
create policy "soil_delete" on soil_readings for delete using (has_farm_role(farm_id, array['admin']));

create policy "photos_select" on photos for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "photos_insert" on photos for insert with check (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "photos_delete" on photos for delete using (has_farm_role(farm_id, array['admin','manager']));

-- ============================================================
-- 9) การเงิน (transactions) — ข้อมูลอ่อนไหว จำกัดเฉพาะ admin/manager ทั้งอ่าน-เขียน
-- ============================================================
create policy "transactions_select" on transactions for select using (has_farm_role(farm_id, array['admin','manager']));
create policy "transactions_insert" on transactions for insert with check (has_farm_role(farm_id, array['admin','manager']));
create policy "transactions_update" on transactions for update using (has_farm_role(farm_id, array['admin','manager']));
create policy "transactions_delete" on transactions for delete using (has_farm_role(farm_id, array['admin']));

-- ============================================================
-- 10) weather_alerts / ai_vision_results — ปกติเติมโดย backend job ด้วย service role (ข้าม RLS)
--     ฝั่ง client ให้สิทธิ์อ่านอย่างเดียว
-- ============================================================
create policy "weather_alerts_select" on weather_alerts for select using (has_farm_role(farm_id, array['admin','manager','worker']));
create policy "weather_alerts_insert" on weather_alerts for insert with check (has_farm_role(farm_id, array['admin','manager']));
create policy "weather_alerts_update" on weather_alerts for update using (has_farm_role(farm_id, array['admin','manager']));

create policy "ai_vision_select" on ai_vision_results for select using (
    exists (select 1 from photos p where p.id = photo_id and has_farm_role(p.farm_id, array['admin','manager','worker']))
);

-- ============================================================
-- 11) AI chat / notifications — ผูกกับผู้ใช้เอง
-- ============================================================
create policy "ai_chat_select_own" on ai_chat_logs for select using (user_id = auth.uid());
create policy "ai_chat_insert_own" on ai_chat_logs for insert with check (user_id = auth.uid());

create policy "notifications_select_own" on notifications for select using (user_id = auth.uid());
create policy "notifications_update_own" on notifications for update using (user_id = auth.uid());

-- ============================================================
-- 12) ฟังก์ชันสรุป KPI สำหรับ Dashboard (คำนวณฝั่ง DB ครั้งเดียว เร็วกว่า query แยกหลายรอบ)
--     ทำงานภายใต้สิทธิ์ของผู้เรียก (ไม่ใช่ security definer) จึงยังถูกกรองด้วย RLS ปกติ
-- ============================================================
create or replace function public.get_dashboard_kpis(p_farm_id uuid)
returns jsonb
language plpgsql
stable
as $$
declare
    result jsonb;
begin
    select jsonb_build_object(
        'total_trees', (select count(*) from trees where farm_id = p_farm_id),
        'yield_mtd_kg', (
            select coalesce(sum(weight_kg), 0) from harvest_records
            where farm_id = p_farm_id and harvest_date >= date_trunc('month', current_date)
        ),
        'revenue_mtd', (
            select coalesce(sum(amount), 0) from transactions
            where farm_id = p_farm_id and transaction_type = 'income'
              and transaction_date >= date_trunc('month', current_date)
        ),
        'expense_mtd', (
            select coalesce(sum(amount), 0) from transactions
            where farm_id = p_farm_id and transaction_type = 'expense'
              and transaction_date >= date_trunc('month', current_date)
        ),
        'open_tasks', (
            select count(*) from tasks
            where farm_id = p_farm_id and status in ('pending','in_progress')
        ),
        'sick_trees', (
            select count(*) from trees where farm_id = p_farm_id and health_status = 'sick'
        )
    ) into result;
    return result;
end;
$$;

-- ตัวอย่างเรียกใช้: select get_dashboard_kpis('<farm_uuid>');
