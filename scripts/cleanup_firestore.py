import sqlite3
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

try:
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import firestore
except ImportError:
    print("Thiếu firebase-admin")
    sys.exit(1)

DB_PATH = 'assets/database/EnglishMaster_cleaned.db'
SERVICE_ACCOUNT_PATH = 'scripts/serviceAccountKey.json'

if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print(f"❌ Không tìm thấy {SERVICE_ACCOUNT_PATH}")
    sys.exit(1)

print("🔗 Khởi tạo Firebase Admin SDK...")
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def cleanup_words():
    print("\n🔄 Đang đọc ID từ thiện 'words' từ SQLite...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM words")
    valid_word_ids = {row[0] for row in cursor.fetchall()}
    conn.close()
    
    print(f"✅ Tìm thấy {len(valid_word_ids)} từ vựng hợp lệ trong DB nội bộ")
    
    print("🔄 Đang fetch dữ liệu 'words' từ Firestore...")
    words_ref = db.collection('words')
    docs = words_ref.stream()
    
    deleted_count = 0
    batch = db.batch()
    batch_count = 0
    
    for doc in docs:
        doc_id = doc.id
        if doc_id not in valid_word_ids:
            batch.delete(doc.reference)
            deleted_count += 1
            batch_count += 1
            
            if batch_count == 400:
                batch.commit()
                print(f"  Đã xoá {deleted_count} từ vựng rác...")
                batch = db.batch()
                batch_count = 0
                
    if batch_count > 0:
        batch.commit()
        print(f"  Đã xoá {deleted_count} từ vựng rác...")
        
    print(f"🎉 Hoàn thành xoá {deleted_count} từ vựng thừa trên Firestore!")

def cleanup_topics():
    print("\n🔄 Đang đọc ID từ 'topics' từ SQLite...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM topics")
    valid_topic_ids = {row[0] for row in cursor.fetchall()}
    conn.close()
    
    print("🔄 Đang fetch dữ liệu 'topics' từ Firestore...")
    topics_ref = db.collection('topics')
    docs = topics_ref.stream()
    
    deleted_count = 0
    batch = db.batch()
    batch_count = 0
    
    for doc in docs:
        if doc.id not in valid_topic_ids:
            batch.delete(doc.reference)
            deleted_count += 1
            batch_count += 1
            if batch_count == 400:
                batch.commit()
                batch = db.batch()
                batch_count = 0
                
    if batch_count > 0:
        batch.commit()
        
    print(f"🎉 Hoàn thành xoá {deleted_count} topic thừa trên Firestore!")

if __name__ == "__main__":
    cleanup_words()
    cleanup_topics()
    print("✨ Sạch sẽ! Data trên Firestore giờ chuẩn khớp 1:1 với SQL.")
