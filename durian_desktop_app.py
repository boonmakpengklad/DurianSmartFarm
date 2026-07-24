"""
Durian Smart Farm - Desktop App (PyQt6) — เชื่อม Supabase จริง
ต้องมีไฟล์ durian_supabase_service.py อยู่โฟลเดอร์เดียวกัน และตั้งค่า .env (SUPABASE_URL / SUPABASE_ANON_KEY)

รัน: pip install PyQt6 pyqtgraph supabase python-dotenv
     python durian_desktop_app.py
"""

import sys
from datetime import date, datetime

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QGridLayout,
    QLabel, QPushButton, QFrame, QStackedWidget, QTableWidget, QTableWidgetItem,
    QLineEdit, QComboBox, QDateEdit, QDoubleSpinBox, QSpinBox, QFormLayout,
    QDialog, QTabWidget, QHeaderView, QScrollArea, QMessageBox
)
from PyQt6.QtCore import Qt, QDate
import pyqtgraph as pg

from durian_supabase_service import SupabaseService, LoginDialog

# ============================================================
# DESIGN TOKENS (เหมือน Web/Mobile)
# ============================================================
COLORS = {
    "bg": "#F6F7F2", "surface": "#FFFFFF", "surface2": "#F0F2EC",
    "ink": "#1E2A20", "ink_soft": "#5B6B5D", "border": "#E1E5DA",
    "green": "#2F6B3C", "green_soft": "#E4F0E6",
    "blue": "#2B6CA3", "blue_soft": "#E3EEF7",
    "orange": "#CE6A0B", "orange_soft": "#FBEAD5",
    "red": "#B23A3A", "red_soft": "#F8E3E1",
}
DARK_COLORS = {
    "bg": "#151C16", "surface": "#1D2620", "surface2": "#232E26",
    "ink": "#EAF0EA", "ink_soft": "#9AAA9C", "border": "#2E3A31",
    "green": "#5EA96E", "green_soft": "#213329", "blue": "#6FA8D6",
    "blue_soft": "#1E2C36", "orange": "#E68A32", "orange_soft": "#3A2A18",
    "red": "#D97070", "red_soft": "#3A2222",
}
HEALTH_LABEL = {"healthy": "ปกติ", "watch": "เฝ้าระวัง", "sick": "ป่วย", "dead": "ตาย"}
HEALTH_TONE = {"healthy": "green", "watch": "orange", "sick": "red", "dead": "red"}
OP_LABEL = {
    "fertilizer": "ใส่ปุ๋ย", "spray": "ฉีดยา", "mowing": "ตัดหญ้า", "watering": "รดน้ำ",
    "pruning": "ตัดแต่งกิ่ง", "pest_control": "กำจัดศัตรูพืช", "other": "อื่นๆ",
}


class ThemeManager:
    def __init__(self):
        self.dark = False

    @property
    def c(self):
        return DARK_COLORS if self.dark else COLORS

    def toggle(self):
        self.dark = not self.dark

    def stylesheet(self):
        c = self.c
        return f"""
            QMainWindow, QWidget {{ background: {c['bg']}; color: {c['ink']}; font-family: 'Segoe UI'; font-size: 13px; }}
            QFrame#card {{ background: {c['surface']}; border: 1px solid {c['border']}; border-radius: 10px; }}
            QFrame#sidebar {{ background: {c['surface']}; border-right: 1px solid {c['border']}; }}
            QPushButton#navBtn {{ text-align: left; padding: 10px 14px; border: none; border-radius: 8px; color: {c['ink_soft']}; font-weight: 600; }}
            QPushButton#navBtn:hover {{ background: {c['surface2']}; }}
            QPushButton#navBtnActive {{ text-align: left; padding: 10px 14px; border: none; border-radius: 8px; background: {c['green_soft']}; color: {c['green']}; font-weight: 700; }}
            QPushButton#primary {{ background: {c['green']}; color: white; border: none; border-radius: 8px; padding: 9px 16px; font-weight: 600; }}
            QPushButton#ghost {{ background: {c['surface2']}; color: {c['ink']}; border: 1px solid {c['border']}; border-radius: 8px; padding: 8px 14px; }}
            QTableWidget {{ background: {c['surface']}; border: 1px solid {c['border']}; border-radius: 8px; gridline-color: {c['border']}; }}
            QHeaderView::section {{ background: {c['surface2']}; color: {c['ink_soft']}; border: none; padding: 6px; font-weight: 600; }}
            QLineEdit, QComboBox, QDateEdit, QDoubleSpinBox, QSpinBox {{
                background: {c['surface2']}; border: 1px solid {c['border']}; border-radius: 6px; padding: 6px 8px;
            }}
            QTabWidget::pane {{ border: 1px solid {c['border']}; border-radius: 8px; }}
            QTabBar::tab {{ padding: 8px 14px; }}
        """


THEME = ThemeManager()


def chip_style(tone_key, c):
    tone = {
        "green": (c["green"], c["green_soft"]), "blue": (c["blue"], c["blue_soft"]),
        "orange": (c["orange"], c["orange_soft"]), "red": (c["red"], c["red_soft"]),
    }[tone_key]
    return f"color: {tone[0]}; background: {tone[1]}; border-radius: 10px; padding: 2px 8px; font-weight: 600; font-size: 11px;"


# ============================================================
# WIDGETS
# ============================================================
class KpiCard(QFrame):
    def __init__(self, label, value, unit, tone):
        super().__init__()
        self.setObjectName("card")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(14, 12, 14, 12)
        badge = QLabel(unit)
        badge.setStyleSheet(chip_style(tone, THEME.c))
        lay.addWidget(badge)
        val = QLabel(str(value))
        val.setStyleSheet(f"font-size: 20px; font-weight: 700; color: {THEME.c['ink']};")
        lay.addWidget(val)
        lab = QLabel(label)
        lab.setStyleSheet(f"color: {THEME.c['ink_soft']}; font-size: 12px;")
        lay.addWidget(lab)


class SectionCard(QFrame):
    def __init__(self, title):
        super().__init__()
        self.setObjectName("card")
        self.v = QVBoxLayout(self)
        self.v.setContentsMargins(14, 12, 14, 12)
        self.head = QLabel(title)
        self.head.setStyleSheet(f"font-size: 15px; font-weight: 700; color: {THEME.c['ink']};")
        self.v.addWidget(self.head)

    def set_title(self, title):
        self.head.setText(title)


def fill_table(table: QTableWidget, headers, rows, health_col=None):
    table.clear()
    table.setColumnCount(len(headers))
    table.setRowCount(len(rows))
    table.setHorizontalHeaderLabels(headers)
    table.verticalHeader().setVisible(False)
    table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
    table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
    table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
    for r, row in enumerate(rows):
        for cidx, val in enumerate(row):
            item = QTableWidgetItem(str(val))
            table.setItem(r, cidx, item)
        table.setRowHeight(r, 30)


def make_table():
    t = QTableWidget(0, 0)
    return t


# ============================================================
# PAGES — โหลดข้อมูลจริงจาก SupabaseService เมื่อถูกเรียก refresh()
# ============================================================
class DashboardPage(QWidget):
    def __init__(self, service: SupabaseService):
        super().__init__()
        self.service = service
        outer = QVBoxLayout(self)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        inner = QWidget()
        self.v = QVBoxLayout(inner)

        self.kpi_grid = QGridLayout()
        self.v.addLayout(self.kpi_grid)

        self.chart_card = SectionCard("ผลผลิตรายเดือน (กก.)")
        self.plot = pg.PlotWidget()
        self.plot.setFixedHeight(160)
        self.chart_card.v.addWidget(self.plot)
        self.v.addWidget(self.chart_card)

        self.alerts_card = SectionCard("การแจ้งเตือนที่ต้องดำเนินการ")
        self.v.addWidget(self.alerts_card)

        self.v.addStretch()
        scroll.setWidget(inner)
        outer.addWidget(scroll)

    def refresh(self):
        # --- KPI cards ---
        while self.kpi_grid.count():
            item = self.kpi_grid.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        try:
            kpis = self.service.get_dashboard_kpis()
        except Exception as e:
            QMessageBox.warning(self, "โหลดข้อมูลไม่สำเร็จ", str(e))
            kpis = {}
        cards = [
            ("ต้นทุเรียนทั้งหมด", kpis.get("total_trees", 0), "ต้น", "green"),
            ("ผลผลิตเดือนนี้", f'{kpis.get("yield_mtd_kg", 0):,.0f}', "กก.", "green"),
            ("รายรับเดือนนี้", f'฿{kpis.get("revenue_mtd", 0):,.0f}', "บาท", "blue"),
            ("กำไรสุทธิ", f'฿{kpis.get("revenue_mtd", 0) - kpis.get("expense_mtd", 0):,.0f}', "บาท", "blue"),
            ("งานค้าง", kpis.get("open_tasks", 0), "รายการ", "orange"),
            ("ต้นที่ป่วย", kpis.get("sick_trees", 0), "ต้น", "red"),
        ]
        for i, (label, value, unit, tone) in enumerate(cards):
            self.kpi_grid.addWidget(KpiCard(label, value, unit, tone), i // 3, i % 3)

        # --- ผลผลิตรายเดือน ---
        try:
            harvest = self.service.list_harvest(limit=200)
        except Exception:
            harvest = []
        buckets = {}
        for h in harvest:
            m = (h.get("harvest_date") or "")[:7]
            if not m:
                continue
            buckets[m] = buckets.get(m, 0) + float(h.get("weight_kg") or 0)
        months = sorted(buckets)[-6:]
        self.plot.clear()
        self.plot.setBackground(THEME.c["surface"])
        self.plot.plot(list(range(len(months))), [buckets[m] for m in months],
                        pen=pg.mkPen(COLORS["green"], width=2), symbol='o', symbolBrush=COLORS["green"])

        # --- alerts ---
        for i in reversed(range(self.alerts_card.v.count())):
            w = self.alerts_card.v.itemAt(i).widget()
            if w and w is not self.alerts_card.head:
                w.deleteLater()
        try:
            alerts = self.service.list_active_alerts()
        except Exception:
            alerts = []
        if not alerts:
            row = QLabel("ไม่มีการแจ้งเตือนขณะนี้")
            row.setStyleSheet(f"color: {THEME.c['ink_soft']};")
            self.alerts_card.v.addWidget(row)
        for a in alerts:
            tone = {"severe": "red", "warning": "orange", "info": "blue"}.get(a.get("severity"), "blue")
            row = QLabel(f"●  {a.get('message') or a.get('alert_type')}")
            row.setStyleSheet(f"color: {THEME.c[tone]}; padding: 4px 0; font-weight: 500;")
            self.alerts_card.v.addWidget(row)


class TreesPage(QWidget):
    def __init__(self, service: SupabaseService, open_quick_add):
        super().__init__()
        self.service = service
        v = QVBoxLayout(self)
        self.card = SectionCard("ทะเบียนต้นทุเรียน")
        toolbar = QHBoxLayout()
        search = QLineEdit(placeholderText="ค้นหา...")
        add_btn = QPushButton("+ เพิ่มรายการ")
        add_btn.setObjectName("primary")
        add_btn.clicked.connect(lambda: open_quick_add(0))
        toolbar.addWidget(search)
        toolbar.addWidget(add_btn)
        self.card.v.addLayout(toolbar)
        self.table = make_table()
        self.card.v.addWidget(self.table)
        v.addWidget(self.card)

    def refresh(self):
        try:
            trees = self.service.list_trees()
        except Exception as e:
            QMessageBox.warning(self, "โหลดข้อมูลไม่สำเร็จ", str(e))
            trees = []
        self.card.set_title(f"ทะเบียนต้นทุเรียน ({len(trees)})")
        rows = [
            (t["tree_code"], t.get("variety", "-"), t.get("planted_date") or "-",
             HEALTH_LABEL.get(t.get("health_status"), t.get("health_status")))
            for t in trees
        ]
        fill_table(self.table, ["รหัส", "พันธุ์", "วันที่ปลูก", "สุขภาพ"], rows)


class OperationsPage(QWidget):
    def __init__(self, service: SupabaseService, open_quick_add):
        super().__init__()
        self.service = service
        v = QVBoxLayout(self)
        self.card = SectionCard("บันทึกกิจกรรมสวน")
        toolbar = QHBoxLayout()
        search = QLineEdit(placeholderText="ค้นหา...")
        add_btn = QPushButton("+ เพิ่มรายการ")
        add_btn.setObjectName("primary")
        add_btn.clicked.connect(lambda: open_quick_add(2))
        toolbar.addWidget(search)
        toolbar.addWidget(add_btn)
        self.card.v.addLayout(toolbar)
        self.table = make_table()
        self.card.v.addWidget(self.table)
        v.addWidget(self.card)

    def refresh(self):
        try:
            ops = self.service.list_operations()
        except Exception as e:
            QMessageBox.warning(self, "โหลดข้อมูลไม่สำเร็จ", str(e))
            ops = []
        self.card.set_title(f"บันทึกกิจกรรมสวน ({len(ops)})")
        rows = [
            ((o.get("performed_at") or "")[:10], OP_LABEL.get(o.get("operation_type"), o.get("operation_type")),
             o.get("description") or "-", f'฿{o["cost"]:,.0f}' if o.get("cost") else "-")
            for o in ops
        ]
        fill_table(self.table, ["วันที่", "ประเภท", "รายละเอียด", "ค่าใช้จ่าย"], rows)


class SoilPage(QWidget):
    def __init__(self, service: SupabaseService, open_quick_add):
        super().__init__()
        self.service = service
        v = QVBoxLayout(self)

        self.trend_card = SectionCard("แนวโน้มค่า pH")
        self.plot = pg.PlotWidget()
        self.plot.setFixedHeight(140)
        self.plot.setYRange(0, 14)
        self.trend_card.v.addWidget(self.plot)
        v.addWidget(self.trend_card)

        self.table_card = SectionCard("ผลวิเคราะห์ดิน")
        toolbar = QHBoxLayout()
        search = QLineEdit(placeholderText="ค้นหา...")
        add_btn = QPushButton("+ เพิ่มรายการ")
        add_btn.setObjectName("primary")
        add_btn.clicked.connect(lambda: open_quick_add(1))
        toolbar.addWidget(search)
        toolbar.addWidget(add_btn)
        self.table_card.v.addLayout(toolbar)
        self.table = make_table()
        self.table_card.v.addWidget(self.table)
        v.addWidget(self.table_card)

    def refresh(self):
        try:
            soil = self.service.list_soil_readings()
        except Exception as e:
            QMessageBox.warning(self, "โหลดข้อมูลไม่สำเร็จ", str(e))
            soil = []
        self.table_card.set_title(f"ผลวิเคราะห์ดิน ({len(soil)})")

        ordered = sorted(soil, key=lambda s: s.get("reading_date") or "")
        self.plot.clear()
        self.plot.setBackground(THEME.c["surface"])
        if ordered:
            self.plot.plot(list(range(len(ordered))), [s.get("ph") or 0 for s in ordered],
                            pen=pg.mkPen(COLORS["blue"], width=2), symbol='o', symbolBrush=COLORS["blue"])

        rows = [(s.get("reading_date"), s.get("ph"), s.get("ec"), s.get("p"), s.get("k")) for s in soil]
        fill_table(self.table, ["วันที่", "pH", "EC", "P", "K"], rows)


# ============================================================
# QUICK ADD DIALOG — เขียนลง Supabase จริง
# ============================================================
class QuickAddDialog(QDialog):
    def __init__(self, service: SupabaseService, trees, start_tab=0, parent=None):
        super().__init__(parent)
        self.service = service
        self.trees = trees
        self.setWindowTitle("เพิ่มข้อมูลด่วน")
        self.resize(420, 460)
        v = QVBoxLayout(self)
        self.tabs = QTabWidget()
        self.tabs.addTab(self._tree_form(), "ลงทะเบียนต้น")
        self.tabs.addTab(self._soil_form(), "วิเคราะห์ดิน")
        self.tabs.addTab(self._operation_form(), "บันทึกกิจกรรม")
        self.tabs.addTab(self._expense_form(), "รายรับ-รายจ่าย")
        self.tabs.setCurrentIndex(start_tab)
        v.addWidget(self.tabs)

        self.error_label = QLabel("")
        self.error_label.setStyleSheet("color: #B23A3A; font-size: 12px;")
        v.addWidget(self.error_label)

        save_btn = QPushButton("บันทึก")
        save_btn.setObjectName("primary")
        save_btn.clicked.connect(self.save)
        v.addWidget(save_btn)

    # ---------- forms ----------
    def _tree_form(self):
        w = QWidget()
        f = QFormLayout(w)
        self.tree_code = QLineEdit(placeholderText="เช่น A-022")
        self.tree_variety = QComboBox()
        self.tree_variety.addItems(["หมอนทอง", "ก้านยาว", "ชะนี", "อื่นๆ"])
        self.tree_planted = QDateEdit(calendarPopup=True)
        self.tree_planted.setDate(QDate.currentDate())
        self.tree_health = QComboBox()
        self.tree_health.addItems(["ปกติ", "เฝ้าระวัง", "ป่วย"])
        f.addRow("รหัสต้น", self.tree_code)
        f.addRow("พันธุ์", self.tree_variety)
        f.addRow("วันที่ปลูก", self.tree_planted)
        f.addRow("สถานะสุขภาพ", self.tree_health)
        return w

    def _soil_form(self):
        w = QWidget()
        f = QFormLayout(w)
        self.soil_date = QDateEdit(calendarPopup=True)
        self.soil_date.setDate(QDate.currentDate())
        self.soil_ph = QDoubleSpinBox()
        self.soil_ph.setRange(0.0, 14.0)
        self.soil_ph.setSingleStep(0.1)
        self.soil_ph.setValue(6.0)
        self.soil_ph.setToolTip("ค่าที่เหมาะสมสำหรับทุเรียน 5.5 – 6.5")
        self.soil_ec = QDoubleSpinBox()
        self.soil_ec.setRange(0.0, 10.0)
        self.soil_ec.setSingleStep(0.1)
        self.soil_p = QSpinBox()
        self.soil_p.setRange(0, 999)
        self.soil_k = QSpinBox()
        self.soil_k.setRange(0, 999)
        f.addRow("วันที่เก็บตัวอย่าง", self.soil_date)
        f.addRow("pH (0–14)", self.soil_ph)
        f.addRow("EC (dS/m)", self.soil_ec)
        f.addRow("ฟอสฟอรัส P (mg/kg)", self.soil_p)
        f.addRow("โพแทสเซียม K (mg/kg)", self.soil_k)
        return w

    def _operation_form(self):
        w = QWidget()
        f = QFormLayout(w)
        self.op_tree = QComboBox()
        self.op_tree.addItem("-- ไม่ระบุ (ทั้งสวน) --", None)
        for t in self.trees:
            self.op_tree.addItem(t["tree_code"], t["id"])
        self.op_type = QComboBox()
        for value, label in OP_LABEL.items():
            self.op_type.addItem(label, value)
        self.op_date = QDateEdit(calendarPopup=True)
        self.op_date.setDate(QDate.currentDate())
        self.op_cost = QSpinBox()
        self.op_cost.setRange(0, 1_000_000)
        self.op_cost.setSuffix(" บาท")
        self.op_desc = QLineEdit()
        f.addRow("ต้น", self.op_tree)
        f.addRow("ประเภท", self.op_type)
        f.addRow("วันที่", self.op_date)
        f.addRow("ค่าใช้จ่าย", self.op_cost)
        f.addRow("หมายเหตุ", self.op_desc)
        return w

    def _expense_form(self):
        w = QWidget()
        f = QFormLayout(w)
        self.tx_type = QComboBox()
        self.tx_type.addItem("รายจ่าย", "expense")
        self.tx_type.addItem("รายรับ", "income")
        self.tx_category = QComboBox()
        self.tx_category.addItem("ปุ๋ย/สารเคมี", "fertilizer")
        self.tx_category.addItem("ค่าแรง", "labor")
        self.tx_category.addItem("น้ำมัน", "fuel")
        self.tx_category.addItem("ขายผลผลิต", "harvest_sale")
        self.tx_category.addItem("อื่นๆ", "other")
        self.tx_date = QDateEdit(calendarPopup=True)
        self.tx_date.setDate(QDate.currentDate())
        self.tx_amount = QSpinBox()
        self.tx_amount.setRange(0, 10_000_000)
        self.tx_amount.setSuffix(" บาท")
        self.tx_desc = QLineEdit()
        f.addRow("ประเภท", self.tx_type)
        f.addRow("หมวด", self.tx_category)
        f.addRow("วันที่", self.tx_date)
        f.addRow("จำนวนเงิน", self.tx_amount)
        f.addRow("หมายเหตุ", self.tx_desc)
        return w

    # ---------- save ----------
    def save(self):
        idx = self.tabs.currentIndex()
        try:
            if idx == 0:
                health_map = {"ปกติ": "healthy", "เฝ้าระวัง": "watch", "ป่วย": "sick"}
                if not self.tree_code.text().strip():
                    raise ValueError("กรุณากรอกรหัสต้น")
                self.service.add_tree(
                    tree_code=self.tree_code.text().strip(),
                    variety=self.tree_variety.currentText(),
                    zone_notes="",
                    planted_date=self.tree_planted.date().toPyDate(),
                    health_status=health_map[self.tree_health.currentText()],
                )
            elif idx == 1:
                self.service.add_soil_reading(
                    reading_date=self.soil_date.date().toPyDate(),
                    ph=self.soil_ph.value(), ec=self.soil_ec.value(), om=None,
                    p=self.soil_p.value(), k=self.soil_k.value(), ca=None, mg=None,
                )
            elif idx == 2:
                self.service.add_operation(
                    operation_type=self.op_type.currentData(),
                    description=self.op_desc.text(),
                    cost=self.op_cost.value(),
                    tree_id=self.op_tree.currentData(),
                )
            else:
                self.service.add_transaction(
                    transaction_type=self.tx_type.currentData(),
                    category=self.tx_category.currentData(),
                    amount=self.tx_amount.value(),
                    transaction_date=self.tx_date.date().toPyDate(),
                    description=self.tx_desc.text(),
                )
            self.accept()
        except Exception as e:
            self.error_label.setText(f"บันทึกไม่สำเร็จ: {e}")


# ============================================================
# MAIN WINDOW
# ============================================================
class MainWindow(QMainWindow):
    PAGES = ["ภาพรวม", "ต้นไม้", "กิจกรรม", "ดิน"]

    def __init__(self, service: SupabaseService):
        super().__init__()
        self.service = service
        self.setWindowTitle("Durian Smart Farm - Desktop")
        self.resize(1180, 760)

        central = QWidget()
        root = QHBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        sidebar = QFrame()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(210)
        sv = QVBoxLayout(sidebar)
        sv.setContentsMargins(12, 16, 12, 16)

        title = QLabel("🌳 Durian Smart Farm")
        title.setStyleSheet("font-size: 15px; font-weight: 700; padding: 0 8px 14px 8px;")
        sv.addWidget(title)

        self.nav_buttons = []
        for i, name in enumerate(self.PAGES):
            btn = QPushButton(name)
            btn.setObjectName("navBtnActive" if i == 0 else "navBtn")
            btn.clicked.connect(lambda _, idx=i: self.switch_page(idx))
            sv.addWidget(btn)
            self.nav_buttons.append(btn)

        sv.addStretch()

        theme_btn = QPushButton("🌓  สลับธีม")
        theme_btn.setObjectName("ghost")
        theme_btn.clicked.connect(self.toggle_theme)
        sv.addWidget(theme_btn)

        refresh_btn = QPushButton("⟳  รีเฟรชข้อมูล")
        refresh_btn.setObjectName("ghost")
        refresh_btn.clicked.connect(self.refresh_all)
        sv.addWidget(refresh_btn)

        add_btn = QPushButton("+  เพิ่มข้อมูลด่วน")
        add_btn.setObjectName("primary")
        add_btn.clicked.connect(lambda: self.open_quick_add(0))
        sv.addWidget(add_btn)

        logout_btn = QPushButton("ออกจากระบบ")
        logout_btn.setObjectName("ghost")
        logout_btn.clicked.connect(self.logout)
        sv.addWidget(logout_btn)

        root.addWidget(sidebar)

        self.stack = QStackedWidget()
        self.dashboard_page = DashboardPage(service)
        self.trees_page = TreesPage(service, self.open_quick_add)
        self.operations_page = OperationsPage(service, self.open_quick_add)
        self.soil_page = SoilPage(service, self.open_quick_add)
        for p in [self.dashboard_page, self.trees_page, self.operations_page, self.soil_page]:
            self.stack.addWidget(p)
        root.addWidget(self.stack)

        self.setCentralWidget(central)
        self.setStyleSheet(THEME.stylesheet())
        self.refresh_all()

    def refresh_all(self):
        self.dashboard_page.refresh()
        self.trees_page.refresh()
        self.operations_page.refresh()
        self.soil_page.refresh()

    def switch_page(self, idx):
        self.stack.setCurrentIndex(idx)
        for i, btn in enumerate(self.nav_buttons):
            btn.setObjectName("navBtnActive" if i == idx else "navBtn")
        self.setStyleSheet(THEME.stylesheet())

    def open_quick_add(self, start_tab):
        try:
            trees = self.service.list_trees()
        except Exception:
            trees = []
        dlg = QuickAddDialog(self.service, trees, start_tab, self)
        dlg.setStyleSheet(THEME.stylesheet())
        if dlg.exec() == QDialog.DialogCode.Accepted:
            self.refresh_all()

    def toggle_theme(self):
        THEME.toggle()
        self.setStyleSheet(THEME.stylesheet())

    def logout(self):
        self.service.sign_out()
        self.close()
        QApplication.instance().exit(RESTART_CODE)


RESTART_CODE = 1000


def run():
    while True:
        app = QApplication(sys.argv)
        service = SupabaseService()

        login = LoginDialog(service)
        login.setStyleSheet(THEME.stylesheet())
        if login.exec() != QDialog.DialogCode.Accepted:
            sys.exit(0)

        win = MainWindow(service)
        win.show()
        code = app.exec()
        if code != RESTART_CODE:
            sys.exit(code)
        # code == RESTART_CODE -> ออกจากระบบแล้ว วนกลับไปหน้า login ใหม่


if __name__ == "__main__":
    run()
