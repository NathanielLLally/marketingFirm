import psycopg2

conn = psycopg2.connect("dbname=postgres user=postgres host=127.0.0.1")

cur = conn.cursor()

cur.execute('select * from pending_lip')

print(cur.fetchall())

cur.close()
conn.close()
