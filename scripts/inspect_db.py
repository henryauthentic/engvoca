# -*- coding: utf-8 -*-
import sqlite3, sys
sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/database/EnglishMaster_cleaned.db')
c = conn.cursor()

print("=== TOPICS schema ===")
c.execute('PRAGMA table_info(topics)')
for col in c.fetchall():
    print(f"  {col}")

print("\n=== WORDS schema ===")
c.execute('PRAGMA table_info(words)')
for col in c.fetchall():
    print(f"  {col}")

print("\n=== Counts ===")
c.execute('SELECT COUNT(*) FROM topics WHERE parent_id IS NULL')
print(f"Parent topics: {c.fetchone()[0]}")
c.execute('SELECT COUNT(*) FROM topics WHERE parent_id IS NOT NULL')
print(f"Child topics: {c.fetchone()[0]}")
c.execute('SELECT COUNT(*) FROM words')
print(f"Total words: {c.fetchone()[0]}")

print("\n=== Sample parent topics ===")
c.execute('SELECT id, name, icon_url, color_hex, total_words, parent_id, order_index FROM topics WHERE parent_id IS NULL LIMIT 10')
for row in c.fetchall():
    print(f"  {row}")

print("\n=== Sample child topics ===")
c.execute('SELECT id, name, parent_id, total_words, order_index FROM topics WHERE parent_id IS NOT NULL LIMIT 10')
for row in c.fetchall():
    print(f"  {row}")

print("\n=== Sample words ===")
c.execute('SELECT id, word, pronunciation, meaning, a_topic_id, pos FROM words LIMIT 5')
for row in c.fetchall():
    print(f"  {row}")

# Check for column name: total_words or totar_words?
c.execute('PRAGMA table_info(topics)')
cols = [col[1] for col in c.fetchall()]
print(f"\n=== Topics column names: {cols}")

# Check if users table exists
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [t[0] for t in c.fetchall()]
print(f"=== All tables: {tables}")

conn.close()
