import sqlite3
import sys
sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect(r'e:\vocabulary_app_v2\assets\database\EnglishMaster_cleaned.db')
cur = conn.cursor()

cur.execute("SELECT DISTINCT pos FROM words WHERE pos IS NOT NULL AND pos != ''")
print("Distinct POS values:", [r[0] for r in cur.fetchall()])

cur.execute("SELECT COUNT(*) FROM words WHERE pos IS NOT NULL AND pos != ''")
print(f"Words with POS: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM words")
print(f"Total words: {cur.fetchone()[0]}")

cur.execute("SELECT word, pos FROM words WHERE pos != '' LIMIT 20")
for row in cur.fetchall():
    print(f"  {row[0]:20s} -> {row[1]}")

conn.close()
