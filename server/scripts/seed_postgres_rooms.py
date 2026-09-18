import psycopg
from datetime import datetime, timezone

ALL_ROOMS = [
    # Plant M1
    'Room 1', 'Room 2', 'Room 3', 'Room 4', 'Room 5', 'Room 6', 'Room 6A', 'Room 6B',
    'Room 7', 'Room 8', 'Room 9', 'Room 10', 'Room 11', 'Room 12', 'Room 13', 'Room 14',
    'Room 15', 'Room 16', 'Room 17', 'Room 18', 'Room 19', 'Room 20', 'Room 21', 'Room 22',
    'Room 22A', 'Room 23', 'Room 24', 'Room 25', 'Room 26', 'Room 27', 'Room 28', 'Room 29',
    'Room 30', 'Room 31', 'Room 32',
    # Plant M2
    'Room 33', 'Room 34', 'Room 35', 'Room 36', 'Room 37', 'Room 38', 'Room 39', 'Room 40',
    'Room 41', 'Room 42', 'Room 43', 'Room 44', 'Room 45', 'Room 46', 'Room 47', 'Room 48',
    'Room 49', 'Room 50', 'Room 51', 'Room 52', 'Room 52A', 'Room 53', 'Room 54', 'Room 55',
    'Room 56', 'Room 57', 'Room 58', 'Room 59', 'Room 60', 'Room 61', 'Room 62', 'Room 63',
    'Room 64', 'Room 65', 'Room 66'
]

def seed_grow_rooms():
    dsn = 'postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp'
    now = datetime.now(timezone.utc)
    inserted = 0
    updated = 0

    with psycopg.connect(dsn) as conn:
        with conn.cursor() as cur:
            for name in ALL_ROOMS:
                room_id = name.lower().replace(' ', '_')
                cur.execute("SELECT id, name FROM grow_rooms WHERE id = %s", (room_id,))
                row = cur.fetchone()
                if row is None:
                    cur.execute("""
                        INSERT INTO grow_rooms (
                            id, name, status, current_stage, day_in_cycle,
                            target_yield, picked_yield, created_at, updated_at,
                            tenant_id, is_seed
                        ) VALUES (
                            %s, %s, 'idle', 'idle', 1,
                            0.0, 0.0, %s, %s,
                            'default', TRUE
                        )
                    """, (room_id, name, now, now))
                    inserted += 1
                elif not row[1] or row[1].strip() == '':
                    cur.execute("""
                        UPDATE grow_rooms 
                        SET name = %s, updated_at = %s, is_seed = TRUE 
                        WHERE id = %s
                    """, (name, now, room_id))
                    updated += 1
        conn.commit()

    print(f"Seed grow_rooms complete: {inserted} inserted, {updated} updated, total standard rooms: {len(ALL_ROOMS)}")

if __name__ == '__main__':
    seed_grow_rooms()
