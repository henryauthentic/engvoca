import sqlite3
import json
import os
import sys

# Configure UTF-8 for Windows PowerShell
sys.stdout.reconfigure(encoding='utf-8')

# YÊU CẦU:
# 1. Cài đặt thư viện: pip install firebase-admin
# 2. Tải Service Account Key từ Firebase Console:
#    Project Settings -> Service Accounts -> Generate new private key
# 3. Lưu file đó với tên: serviceAccountKey.json vào cùng thư mục với script này
# 4. Chạy script: python scripts/migrate_firestore.py

try:
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import firestore
except ImportError:
    print("Vui lòng chạy lệnh sau trước khi chạy script:")
    print("pip install firebase-admin")
    sys.exit(1)

# Đường dẫn file
DB_PATH = 'assets/database/EnglishMaster_cleaned.db'
SERVICE_ACCOUNT_PATH = 'scripts/serviceAccountKey.json'

if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print(f"❌ Không tìm thấy file {SERVICE_ACCOUNT_PATH}")
    print("Vui lòng vào Firebase Console -> Project Settings -> Service Accounts -> Generate new private key.")
    print("Đổi tên file tải về thành 'serviceAccountKey.json' và đặt vào thư mục 'scripts'.")
    sys.exit(1)

if not os.path.exists(DB_PATH):
    print(f"❌ Không tìm thấy csdl SQLite: {DB_PATH}")
    sys.exit(1)

print("🔗 Khởi tạo Firebase Admin SDK...")
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def migrate_topics():
    print("\n🔄 Đang đọc bảng 'topics' từ SQLite...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, name, description, icon_url, color_hex, total_words, learned_words, is_unlocked, order_index, parent_id FROM topics")
    
    topics_count = 0
    batch = db.batch()
    
    for row in cursor.fetchall():
        doc_id = row[0]
        data = {
            'id': row[0],
            'name': row[1],
            'description': row[2] if row[2] else '',
            'icon_url': row[3] if row[3] else '',
            'color_hex': row[4] if row[4] else '',
            'total_words': row[5] if row[5] is not None else 0,
            'learned_words': row[6] if row[6] is not None else 0,
            'is_unlocked': row[7] if row[7] is not None else 1,
            'order_index': row[8] if row[8] is not None else 0,
        }
        # Thêm parent_id nếu có
        if row[9] is not None:
             data['parent_id'] = row[9]
             
        doc_ref = db.collection('topics').document(doc_id)
        batch.set(doc_ref, data, merge=True)
        topics_count += 1
        
        # Firestore batch giới hạn 500 actions
        if topics_count % 400 == 0:
            batch.commit()
            print(f"  Đã upload {topics_count} topics...")
            batch = db.batch()
            
    # Commit phần còn lại
    if topics_count % 400 != 0:
        batch.commit()
        
    conn.close()
    print(f"✅ Hoàn thành upload {topics_count} topic lên Firestore!")

def migrate_words():
    print("\n🔄 Đang đọc bảng 'words' từ SQLite...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, word, pronunciation, meaning, example, image_url, audio_url, a_topic_id, is_favorite, is_learned, difficulty_level, created_at, learned_at, pos FROM words")
    
    words_count = 0
    batch = db.batch()
    
    for row in cursor.fetchall():
        doc_id = row[0]
        data = {
            'id': row[0],
            'word': row[1] if row[1] else '',
            'pronunciation': row[2] if row[2] else '',
            'meaning': row[3] if row[3] else '',
            'example': row[4] if row[4] else '',
            'image_url': row[5],
            'audio_url': row[6],
            'a_topic_id': row[7],
            'topic_id': row[7], # Đẩy lên cả topic_id để dự phòng
            'is_favorite': row[8] if row[8] is not None else 0,
            'is_learned': row[9] if row[9] is not None else 1,
            'difficulty_level': row[10] if row[10] is not None else 1,
            'created_at': row[11],
            'learned_at': row[12],
        }
        # Nếu DB mới có cột 'pos', đẩy lên luôn
        if len(row) > 13 and row[13] is not None:
             data['pos'] = row[13]

        doc_ref = db.collection('words').document(doc_id)
        batch.set(doc_ref, data, merge=True)
        words_count += 1
        
        if words_count % 400 == 0:
            batch.commit()
            print(f"  Đã upload {words_count} words...")
            batch = db.batch()
            
    if words_count % 400 != 0:
        batch.commit()
        
    conn.close()
    print(f"✅ Hoàn thành upload {words_count} từ vựng lên Firestore!")

if __name__ == "__main__":
    print("="*50)
    print("BẮT ĐẦU MIGRATE DATA LÊN FIRESTORE")
    print("="*50)
    
    try:
        migrate_topics()
        migrate_words()
        print("\n🎉 XONG TẤT CẢ! Data trên Firestore đã được sync.")
    except Exception as e:
        print(f"\n❌ Lỗi trong quá trình chạy: {e}")
