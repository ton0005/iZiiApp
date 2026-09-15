import sys, re

log_path = r'C:\Users\CHANH\AppData\Local\iZiiApp\server\logs\server.log'
with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

ws_hb = {}
ws_presence = {}
for l in lines[-4000:]:
    if 'event' in l and 'heartbeat' in l:
        m = re.search(r'"user_id"\s*:\s*"([^"]+)"', l)
        if m:
            uid = m.group(1)
            ws_hb[uid] = ws_hb.get(uid, 0) + 1
    if 'event' in l and 'presence_update' in l:
        m = re.search(r'"user_id"\s*:\s*"([^"]+)"', l)
        if m:
            uid = m.group(1)
            ws_presence[uid] = ws_presence.get(uid, 0) + 1

print('Recent WebSocket heartbeats by user_id:')
for k, v in ws_hb.items():
    print(f'  {k}: {v}')

print('Recent WebSocket presence_update by user_id:')
for k, v in ws_presence.items():
    print(f'  {k}: {v}')
