Vai trò: Bạn là kiến trúc sư dữ liệu (Data Architect) với kinh nghiệm triển khai 
và vận hành hệ thống database cho các giải pháp doanh nghiệp lớn (ERP, WMS/WHS, 
WCS), có kinh nghiệm thực tế về chiến lược backup/DR và migrate hệ quản trị CSDL.

Bối cảnh:
- Hệ thống hiện tại: iZiiServer (nêu rõ: đây là hệ thống WMS/WCS nội bộ hay 
  phần mềm của bên thứ ba; đang chạy trên DB engine nào - MSSQL, MySQL, Oracle...)
- Quy mô dữ liệu hiện tại: [số GB/TB, số bảng lớn nhất, tốc độ tăng trưởng dữ liệu/tháng]
- Hạ tầng: on-premise / cloud / hybrid
- Tần suất giao dịch: [số transaction/ngày, giờ cao điểm]
- Yêu cầu RTO/RPO (nếu có): thời gian tối đa chấp nhận downtime và mất dữ liệu

Mục tiêu cần tư vấn (giải quyết riêng từng phần):

1. Chiến lược backup theo chu kỳ (tuần/tháng/quý/năm)
   - Đề xuất mô hình backup: Full / Differential / Incremental / Log backup, 
     áp dụng cho từng chu kỳ
   - Chính sách retention (giữ bao lâu, khi nào archive, khi nào xoá)
   - Cách đặt lịch tự động (job scheduler, tool đề xuất)
   - Vị trí lưu trữ: local, offsite, cloud storage, và chiến lược 3-2-1 backup

2. Thiết kế hướng tới khả năng mở rộng (scalability)
   - Chuẩn hoá schema, chiến lược partitioning/sharding nếu dữ liệu lớn dần
   - Tách read/write (replication) để chuẩn bị load tăng
   - Đề xuất cách version hoá schema để dễ thêm server/instance sau này

3. Chuẩn bị migrate sang PostgreSQL hoặc SQL Server
   - So sánh ngắn gọn 2 hướng migrate này (ưu/nhược trong bối cảnh WMS/WCS)
   - Những rủi ro/khác biệt cần lưu ý khi chuyển từ DB hiện tại (kiểu dữ liệu, 
     stored procedure, collation, transaction isolation...)
   - Cách thiết kế backup/schema NGAY TỪ BÂY GIỜ để việc migrate sau này ít đau đớn nhất
   - Công cụ hỗ trợ migrate (native tool, third-party) phù hợp quy mô

Định dạng đầu ra mong muốn:
- Trình bày theo 3 mục lớn ở trên, mỗi mục có bảng tóm tắt đề xuất (Tần suất | 
  Phương pháp | Công cụ | Lưu ý)
- Có phần "Rủi ro & lưu ý" riêng ở cuối
- Nếu thiếu thông tin để tư vấn chính xác, hãy liệt kê rõ các câu hỏi cần tôi 
  bổ sung trước khi đưa giải pháp chi tiết