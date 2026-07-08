  
📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:23:40.874908  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:50374 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A23%3A40.874908 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:50380 \- "←\[1mPOST /api/v1/devices/heartbeat HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:50380 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:50386 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:23:45.866156  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:50394 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A23%3A45.866156 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:57350 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:57358 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

\==================================================  
📥 \[PUSH\] Nhận được 2 thay đổi lúc 2026-07-08T13:23:55.397358  
\==================================================  
   \[1\] 🔹 Bảng: tasks | Thao tác: insert  
       \- id: 8787a0ad-8a0e-4852-a2ba-478076cc2f8f  
       \- project\_id: 24a2379d-baea-4064-aeef-4968b721ad74  
       \- title: FILLING (Room 11\)  
       \- description:  
       \- status: todo  
       \- priority: medium  
       \- due\_date: 2026-07-08T14:00:00.000  
       \- created\_at: 2026-07-08T13:23:53.012096  
   \[2\] 🔹 Bảng: mushroom\_jobs | Thao tác: insert  
       \- id: 3ef4392d-e9c9-470c-aed9-7a2471bc2cbe  
       \- roomId: 7e59807c-5ef7-4815-9036-4cc6816f3175  
       \- jobType: filling  
       \- name: FILLING  
       \- status: todo  
       \- assignee: Production  
       \- priority: normal  
       \- scheduledAt: 2026-07-08T14:00:00.000  
       \- planDetails: None  
       \- prochlorazRate: None  
       \- linkedTaskId: 8787a0ad-8a0e-4852-a2ba-478076cc2f8f  
       \- created\_at: 2026-07-08T13:23:53.025526  
←\[32mINFO←\[0m:     10.107.156.166:57370 \- "←\[1mPOST /sync/push HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:23:50.859157  
   📦 Gửi 2 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:57370 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A23%3A50.859157 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:57384 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:57400 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

\==================================================  
📥 \[PUSH\] Nhận được 3 thay đổi lúc 2026-07-08T13:24:00.381737  
\==================================================  
   \[1\] 🔹 Bảng: mushroom\_jobs | Thao tác: update  
       \- id: 3ef4392d-e9c9-470c-aed9-7a2471bc2cbe  
       \- status: in\_progress  
       \- completedAt: None  
       \- alarmTriggered: False  
   \[2\] 🔹 Bảng: tasks | Thao tác: update  
       \- id: 8787a0ad-8a0e-4852-a2ba-478076cc2f8f  
       \- status: in\_progress  
   \[3\] 🔹 Bảng: grow\_rooms | Thao tác: update  
       \- id: 7e59807c-5ef7-4815-9036-4cc6816f3175  
       \- status: active  
       \- current\_stage: filling  
       \- updated\_at: 2026-07-08T13:23:58.704559  
←\[32mINFO←\[0m:     10.107.156.166:57412 \- "←\[1mPOST /sync/push HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:23:55.979259  
   📦 Gửi 3 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:57412 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A23%3A55.979259 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:46966 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:46970 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:00.969744  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:46978 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A00.969744 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:46988 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:46996 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:05.849542  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:47008 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A05.849542 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:42580 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:42586 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:10.881800  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:42602 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A10.881800 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:42610 \- "←\[1mPOST /api/v1/devices/heartbeat HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:42610 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:42622 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:15.861569  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:42636 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A15.861569 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:57422 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:57436 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:20.856206  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:57440 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A20.856206 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:57452 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:57468 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:25.894547  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:57470 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A25.894547 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:51500 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:51504 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:24:30.851624  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:51506 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A24%3A30.851624 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55102 \- "←\[1mPOST /api/v1/devices/heartbeat HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55114 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:55124 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:25:35.834262  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:55134 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A25%3A35.834262 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55124 \- "←\[1mPOST /api/v1/devices/heartbeat HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55124 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:55114 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:17.936137  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:55134 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A17.936137 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:55146 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:43936 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:43942 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:20.871198  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:43954 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A20.871198 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:43970 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:43982 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:43990 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:25.848768  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:44004 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A25.848768 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:44020 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:33234 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:33242 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:30.847700  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:33252 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A30.847700 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:33266 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:33272 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:33282 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:35.963412  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:33296 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A35.963412 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:33298 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55198 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:55212 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:40.893440  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:55220 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A40.893440 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:55234 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55246 \- "←\[1mPOST /api/v1/devices/heartbeat HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:55246 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:55262 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:45.889890  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:55274 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A45.889890 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:55284 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:36650 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:36644 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:50.874498  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:36658 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A50.874498 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m  
←\[33mWARNING←\[0m:  Unsupported upgrade request.  
←\[33mWARNING←\[0m:  No supported WebSocket library detected. Please use "pip install 'uvicorn\[standard\]'", or install 'websockets' or 'wsproto' manually.  
←\[32mINFO←\[0m:     10.107.156.166:36664 \- "←\[1mGET /chat HTTP/1.1←\[0m" ←\[31m404 Not Found←\[0m  
←\[32mINFO←\[0m:     10.107.156.166:36678 \- "←\[1mGET /api/v1/messages/pending?device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📡 \[ONLINE\] Queried online devices → 0 active  
←\[32mINFO←\[0m:     10.107.156.166:36686 \- "←\[1mGET /api/v1/devices/online?exclude\_device\_id=izii-d-27fd1f53 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:52:55.854957  
   📦 Gửi 0 bản ghi  
←\[32mINFO←\[0m:     10.107.156.166:36702 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A52%3A55.854957 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

📤 \[PULL\] Thiết bị đang tải về các cập nhật mới...  
   🕐 Lọc từ: 2026-07-08T13:12:35.268183  
   📦 Gửi 11 bản ghi  
←\[32mINFO←\[0m:     10.107.156.93:56489 \- "←\[1mGET /sync/pull?since=2026-07-08T13%3A12%3A35.268183 HTTP/1.1←\[0m" ←\[32m200 OK←\[0m

