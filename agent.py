from langchain_ollama import ChatOllama
from langchain_core.tools import tool
from langchain.agents import create_agent

# 1. Tool สำหรับคำนวณตัวเลขทั่วไป
@tool
def calculate(expression: str) -> str:
    """คำนวณทางคณิตศาสตร์พื้นฐาน ส่งค่ามาเป็นสมการเช่น 5 * 10 หรือ 145 * 23"""
    try:
        return str(eval(expression))
    except Exception as e:
        return f"Error: {e}"

# 2. Tool สำหรับเช็คค่าความชื้นในดินตามโซนแปลงทุเรียน
@tool
def get_soil_moisture(zone: str) -> str:
    """ตรวจสอบค่าความชื้นในดินของโซนปลูกทุเรียน เช่น โซน A, โซน B, โซน C"""
    # จำลองข้อมูลจากเซ็นเซอร์ในฟาร์ม
    sensor_data = {
        "โซน A": "ความชื้น 42% (ดินปกติ ต้นทุเรียนเติบโตได้ดี)",
        "โซน B": "ความชื้น 26% (ดินแห้งเกินไป ควรเปิดระบบน้ำ)",
        "โซน C": "ความชื้น 68% (ดินแฉะ ระวังรากเน่า)"
    }
    return sensor_data.get(zone, "ไม่พบข้อมูลของโซนที่คุณระบุ กรุณาตรวจสอบชื่อโซนอีกครั้ง")

# 3. Tool สำหรับควบคุมปั๊มน้ำในแปลง
@tool
def control_water_pump(zone: str, action: str) -> str:
    """สั่งเปิดหรือปิดระบบปั๊มน้ำสำหรับรดน้ำทุเรียน ระบุโซนและสถานะ เช่น action เป็น 'เปิด' หรือ 'ปิด'"""
    if action not in ["เปิด", "ปิด"]:
        return "คำสั่งไม่ถูกต้อง กรุณาระบุสถานะเป็น 'เปิด' หรือ 'ปิด' เท่านั้น"
    
    # จำลองการส่งคำสั่งไปที่ฮาร์ดแวร์หรือระบบรีเลย์
    return f"ระบบได้ส่งสัญญาณทำการ '{action}น้ำ' ให้กับ {zone} เรียบร้อยแล้ว"

# รวม Tool ทั้งหมดเข้าด้วยกัน
tools = [calculate, get_soil_moisture, control_water_pump]

# เชื่อมต่อกับ Ollama (ใช้โมเดล qwen3:8b ในเครื่อง)
model = ChatOllama(
    model="qwen3:8b",
    temperature=0
)

# สร้าง Agent
agent_executor = create_agent(model, tools)

if __name__ == "__main__":
    # คุณสามารถเปลี่ยนคำสั่ง (Prompt) ตรงนี้เพื่อทดสอบ Agent ได้ตามต้องการ
    user_query = "ตอนนี้ความชื้นในดินโซน B เป็นอย่างไรบ้าง ถ้าต่ำเกินไปช่วยสั่งเปิดน้ำให้หน่อย"
    
    inputs = {"messages": [("user", user_query)]}
    
    print(f"คำสั่ง: {user_query}\n")
    print("กำลังประมวลผล...")
    
    # วนลูปแสดงผลลัพธ์ขั้นตอนการทำงานและคำตอบสุดท้าย
    for event in agent_executor.stream(inputs, stream_mode="values"):
        latest_message = event["messages"][-1]
        
    print("\n--- ผลลัพธ์จาก AI Agent ---")
    latest_message.pretty_print()