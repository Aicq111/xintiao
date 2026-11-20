# -*- coding: utf-8 -*-
import sqlite3, sys, json
sys.stdout.reconfigure(encoding='utf-8')
db = sqlite3.connect(r'C:\Users\33426.AICQ\AppData\Local\Sideloadly\installations.db')
cur = db.cursor()
tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
print('tables:', tables)
for t in tables:
    print('=== table', t, '===')
    cols = [c[1] for c in cur.execute(f'PRAGMA table_info({t})').fetchall()]
    print('cols:', cols)
    for row in cur.execute(f'SELECT * FROM {t}').fetchall():
        print(row)
