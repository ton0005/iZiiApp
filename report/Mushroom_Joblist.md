1. Danh sách chi tiết các trường (Fields) được đồng bộ
Khi tạo một New Job, hệ thống đồng bộ đồng thời trên 2 thực thể liên kết:

A. Bảng mushroom_jobs (Dữ liệu chuyên sâu ngành nấm)
Tên Field (Camel / Snake)	Kiểu dữ liệu	Ý nghĩa nghiệp vụ
id	String (UUID)	Khóa chính duy nhất định danh công việc
room_id / roomId	String	ID phòng trồng liên kết (vd: room_33, room_52a)
job_type / jobType	String	Loại công việc (clean_room, clean_bed, watering, filling, airing, prochloraz, packup_tree, alone_worker, ...)
name	String	Tên hiển thị công việc (vd: "Clean Bed", "Watering", "Prochloraz Spray")
status	String	Trạng thái (pending, in_progress, completed, review, todo, done)
assignee	String?	Tên nhân sự hoặc mã nhân viên được giao việc
plan_details / planDetails	String?	Chi tiết kế hoạch (vd: "2 Side 2.0 L/m²")
prochloraz_rate / prochlorazRate	String?	Định mức hóa chất (vd: "1.3g/m²")
completed_at / completedAt	DateTime?	Dấu thời gian hoàn thành công việc
linked_task_id / linkedTaskId	String?	Khóa ngoại trỏ sang bảng tasks của module Dự án & Công việc
is_solo_job / isSoloJob	bool	Cờ nhận diện công việc đơn độc (Alone Worker)
time_limit_minutes	int?	Thời hạn an toàn tối đa cho phép trong phòng kín (phút)
started_at / startedAt	DateTime?	Thời điểm bắt đầu thực hiện
alarm_triggered	bool	Trạng thái kích hoạt chuông cảnh báo an toàn
scheduled_at / scheduledAt	DateTime?	Thời gian lên lịch thực hiện
priority	String	Mức độ ưu tiên (low, normal, high, urgent)
co_level, co2_level	double?	Nồng độ khí CO và CO2 quan trắc tại phòng
check_in_time, check_out_time	DateTime?	Giờ điểm danh vào và ra khỏi phòng
created_at, updated_at	DateTime	Dấu thời gian tạo và cập nhật bản ghi
B. Bảng tasks (Dữ liệu module Dự án & Công việc)
Tên Field	Kiểu dữ liệu	Ý nghĩa
id	String (UUID)	Khóa chính của Task (trùng với linked_task_id)
project_id	String	ID dự án cha (mặc định: dự án Costa M2 Operations)
title	String	Tiêu đề Task: "$name ($roomName)"
description	String?	Mô tả chi tiết, phân công, nồng độ khí
status	String	Trạng thái: todo, in_progress, done
priority	String	Mức độ ưu tiên: low, medium, high
due_date	DateTime?	Hạn hoàn thành