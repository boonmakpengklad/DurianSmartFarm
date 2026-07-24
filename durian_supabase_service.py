"""
durian_supabase_service.py
เชื่อม Desktop App (PyQt6) เข้ากับ Supabase จริง — Auth + CRUD
ต้องติดตั้งก่อน: pip install supabase python-dotenv

ตั้งค่าใน .env (โฟลเดอร์เดียวกับไฟล์นี้):
    SUPABASE_URL=https://qperhmjkmqkuiwnbxjck.supabase.co
    SUPABASE_ANON_KEY=sb_publishable_-B3rAdCdJ7ATnoCppfRqLg_khuX-keB
"""

import os
from datetime import date
from dotenv import load_dotenv
from supabase import create_client, Client

from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QFormLayout, QLineEdit, QPushButton, QLabel,
    QMessageBox, QHBoxLayout
)

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")


class SupabaseService:
    """ห่อ supabase-py client ไว้ที่เดียว ใช้ร่วมกันทั้งแอป (singleton-style)"""

    def __init__(self):
        if not SUPABASE_URL or not SUPABASE_ANON_KEY:
            raise RuntimeError("ไม่พบ SUPABASE_URL / SUPABASE_ANON_KEY ใน .env")
        self.client: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        self.session = None
        self.farm_id = None  # ตั้งค่าหลัง login สำเร็จและเลือกสวน

    # ---------------- Auth ----------------
    def sign_in(self, email: str, password: str):
        res = self.client.auth.sign_in_with_password({"email": email, "password": password})
        self.session = res.session
        return res.user

    def sign_up(self, email: str, password: str, full_name: str):
        res = self.client.auth.sign_up({
            "email": email,
            "password": password,
            "options": {"data": {"full_name": full_name}},
        })
        return res.user

    def sign_out(self):
        self.client.auth.sign_out()
        self.session = None
        self.farm_id = None

    def my_farms(self):
        res = self.client.table("farms").select("id, name").order("created_at").execute()
        return res.data

    def create_farm(self, name: str):
        user = self.client.auth.get_user()
        owner_id = user.user.id
        res = self.client.table("farms").insert({"name": name, "owner_id": owner_id}).execute()
        return res.data[0]

    # ---------------- Dashboard ----------------
    def get_dashboard_kpis(self):
        res = self.client.rpc("get_dashboard_kpis", {"p_farm_id": self.farm_id}).execute()
        return res.data

    def list_active_alerts(self):
        res = (
            self.client.table("weather_alerts")
            .select("*")
            .eq("farm_id", self.farm_id)
            .eq("resolved", False)
            .order("triggered_at", desc=True)
            .execute()
        )
        return res.data

    # ---------------- Trees ----------------
    def list_trees(self):
        res = self.client.table("trees").select("*").eq("farm_id", self.farm_id).order("tree_code").execute()
        return res.data

    def add_tree(self, tree_code, variety, zone_notes, planted_date: date, health_status, lat=None, lng=None):
        payload = {
            "farm_id": self.farm_id,
            "tree_code": tree_code,
            "variety": variety,
            "notes": zone_notes,
            "planted_date": planted_date.isoformat() if planted_date else None,
            "health_status": health_status,
            "latitude": lat,
            "longitude": lng,
        }
        res = self.client.table("trees").insert(payload).execute()
        return res.data[0]

    # ---------------- Operations ----------------
    def list_operations(self, limit=50):
        res = (
            self.client.table("operations")
            .select("*")
            .eq("farm_id", self.farm_id)
            .order("performed_at", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data

    def add_operation(self, operation_type, description, cost, tree_id=None):
        payload = {
            "farm_id": self.farm_id,
            "tree_id": tree_id,
            "operation_type": operation_type,
            "description": description,
            "cost": cost,
        }
        res = self.client.table("operations").insert(payload).execute()
        return res.data[0]

    # ---------------- Harvest ----------------
    def list_harvest(self, limit=200):
        res = (
            self.client.table("harvest_records")
            .select("*")
            .eq("farm_id", self.farm_id)
            .order("harvest_date", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data

    def add_harvest(self, harvest_date: date, weight_kg, price_per_kg=None, grade="", tree_id=None):
        payload = {
            "farm_id": self.farm_id,
            "tree_id": tree_id,
            "harvest_date": harvest_date.isoformat(),
            "weight_kg": weight_kg,
            "price_per_kg": price_per_kg,
            "grade": grade,
        }
        res = self.client.table("harvest_records").insert(payload).execute()
        return res.data[0]

    # ---------------- Soil ----------------
    def list_soil_readings(self, limit=50):
        res = (
            self.client.table("soil_readings")
            .select("*")
            .eq("farm_id", self.farm_id)
            .order("reading_date", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data

    def add_soil_reading(self, reading_date: date, ph, ec, om, p, k, ca, mg, notes=""):
        if ph is not None and not (0 <= ph <= 14):
            raise ValueError("ค่า pH ต้องอยู่ระหว่าง 0–14")
        payload = {
            "farm_id": self.farm_id,
            "reading_date": reading_date.isoformat(),
            "ph": ph, "ec": ec, "om": om, "p": p, "k": k, "ca": ca, "mg": mg,
            "notes": notes,
        }
        res = self.client.table("soil_readings").insert(payload).execute()
        return res.data[0]

    # ---------------- Transactions ----------------
    def list_transactions(self, limit=50):
        res = (
            self.client.table("transactions")
            .select("*")
            .eq("farm_id", self.farm_id)
            .order("transaction_date", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data

    def add_transaction(self, transaction_type, category, amount, transaction_date: date, description=""):
        payload = {
            "farm_id": self.farm_id,
            "transaction_type": transaction_type,
            "category": category,
            "amount": amount,
            "transaction_date": transaction_date.isoformat(),
            "description": description,
        }
        res = self.client.table("transactions").insert(payload).execute()
        return res.data[0]


# ============================================================
# LOGIN DIALOG — แสดงก่อนเปิด MainWindow
# ============================================================
class LoginDialog(QDialog):
    def __init__(self, service: SupabaseService, parent=None):
        super().__init__(parent)
        self.service = service
        self.setWindowTitle("เข้าสู่ระบบ - Durian Smart Farm")
        self.resize(340, 260)

        v = QVBoxLayout(self)
        title = QLabel("Durian Smart Farm")
        title.setStyleSheet("font-size: 16px; font-weight: 700;")
        v.addWidget(title)

        form = QFormLayout()
        self.email = QLineEdit()
        self.password = QLineEdit()
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        form.addRow("อีเมล", self.email)
        form.addRow("รหัสผ่าน", self.password)
        v.addLayout(form)

        self.error_label = QLabel("")
        self.error_label.setStyleSheet("color: #B23A3A; font-size: 12px;")
        v.addWidget(self.error_label)

        btn_row = QHBoxLayout()
        login_btn = QPushButton("เข้าสู่ระบบ")
        login_btn.setObjectName("primary")
        login_btn.clicked.connect(self.do_login)
        btn_row.addWidget(login_btn)
        v.addLayout(btn_row)

        # ผลลัพธ์: หลัง login สำเร็จ ให้เรียก self.service.my_farms() แล้วให้ผู้ใช้เลือกสวน
        # จากนั้นตั้ง self.service.farm_id ก่อนเปิด MainWindow

    def do_login(self):
        try:
            self.service.sign_in(self.email.text().strip(), self.password.text())
            farms = self.service.my_farms()
            if not farms:
                create_dlg = CreateFarmDialog(self.service, self)
                create_dlg.setStyleSheet(self.styleSheet())
                if create_dlg.exec() == QDialog.DialogCode.Accepted:
                    self.accept()
                else:
                    self.error_label.setText("ต้องสร้างสวนอย่างน้อย 1 สวนจึงจะเข้าใช้งานได้")
                return
            self.service.farm_id = farms[0]["id"]  # ถ้ามีหลายสวน ให้เพิ่ม dropdown เลือกภายหลัง
            self.accept()
        except Exception as e:
            self.error_label.setText(f"เข้าสู่ระบบไม่สำเร็จ: {e}")


# ============================================================
# CREATE FIRST FARM DIALOG — แสดงหลัง login สำเร็จถ้าบัญชียังไม่มีสวน
# ============================================================
class CreateFarmDialog(QDialog):
    def __init__(self, service: SupabaseService, parent=None):
        super().__init__(parent)
        self.service = service
        self.setWindowTitle("สร้างสวนแรก")
        self.resize(340, 200)

        v = QVBoxLayout(self)
        title = QLabel("สร้างสวนแรกของคุณ")
        title.setStyleSheet("font-size: 16px; font-weight: 700;")
        v.addWidget(title)

        subtitle = QLabel("ยังไม่มีสวนในบัญชีนี้ ตั้งชื่อสวนเพื่อเริ่มต้นใช้งาน")
        subtitle.setStyleSheet("font-size: 12px; color: #5B6B5D;")
        subtitle.setWordWrap(True)
        v.addWidget(subtitle)

        form = QFormLayout()
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("เช่น สวนทุเรียนบ้านสวนสุข")
        form.addRow("ชื่อสวน", self.name_input)
        v.addLayout(form)

        self.error_label = QLabel("")
        self.error_label.setStyleSheet("color: #B23A3A; font-size: 12px;")
        v.addWidget(self.error_label)

        create_btn = QPushButton("สร้างสวน")
        create_btn.setObjectName("primary")
        create_btn.clicked.connect(self.do_create)
        v.addWidget(create_btn)

    def do_create(self):
        name = self.name_input.text().strip()
        if not name:
            self.error_label.setText("กรุณากรอกชื่อสวน")
            return
        try:
            farm = self.service.create_farm(name)
            self.service.farm_id = farm["id"]
            self.accept()
        except Exception as e:
            self.error_label.setText(f"สร้างสวนไม่สำเร็จ: {e}")


# ============================================================
# ตัวอย่างการใช้งานร่วมกับ main.py เดิม (durian_desktop_app.py)
# ============================================================
"""
if __name__ == "__main__":
    app = QApplication(sys.argv)
    service = SupabaseService()

    login = LoginDialog(service)
    if login.exec() == QDialog.DialogCode.Accepted:
        win = MainWindow(service)   # ส่ง service เข้าไปแทน mock data
        win.show()
        sys.exit(app.exec())
    else:
        sys.exit(0)
"""
