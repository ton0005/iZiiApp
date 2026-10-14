import psycopg

with psycopg.connect('postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp') as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT count(1) FROM grow_rooms")
        print('Total grow_rooms in Postgres:', cur.fetchone()[0])
        cur.execute("SELECT id, name, status, current_stage, is_seed FROM grow_rooms WHERE id = 'room_34'")
        print('Room 34 in Postgres:', cur.fetchone())
        
        cur.execute("SELECT id, operation, seq, data FROM sync_mutations WHERE \"table\" = 'grow_rooms' ORDER BY seq DESC LIMIT 10")
        for r in cur.fetchall():
            print('seq:', r[2], 'op:', r[1], 'data:', r[3])
