> **⚠️ GHI CHÚ NGHIÊN CỨU — CHƯA KIỂM CHỨNG. KHÔNG DÙNG LÀM ĐẶC TẢ.**
>
> Đây là bản chép cuộc hỏi đáp với trợ lý AI. Nhiều chi tiết kỹ thuật **sai so với văn bản gốc QĐ 130/QĐ-BYT** (không phải "QĐ-BHXH"):
> tên thẻ XML (`MA_QUAN_HUYEN`, `MA_PHUONG_XA`, `MA_BENH`, `CHAN_DOAN`, `TINH_TRANG_RA_VIEN`, `MA_DUONG_DUNG` không tồn tại),
> mã `KET_QUA_DTRI` sai, `NGAY_SINH` phải 12 ký tự, `MA_THE_BHYT` phải lưu đủ 15 ký tự, thẻ bao `HO_SO/CHECK_SUM` là phỏng đoán.
>
> Kế hoạch chính thức: `01_Ke_Hoach_Module_Clinic_Pharmacy_QD130.md` (mục "Phụ lục A" liệt kê đầy đủ các lỗi).

---

ứng dụng của bạn phải kết nối trung gian thông qua hạ tầng tiêu chuẩn của Bộ Y tế và Bảo hiểm Xã hội (BHXH) Việt Nam. Dữ liệu từ app của bạn đẩy lên các cổng này sẽ tự động đồng bộ sang Sổ sức khỏe điện tử trên VNeID.
Dưới đây là kiến trúc và quy trình kỹ thuật để bạn phát triển ứng dụng này:

1. Mô hình kiến trúc kết nối (Data Flow)

Hệ thống của bạn sẽ bao gồm 2 cấu phần app chính, hoạt động theo luồng đi của dữ liệu như sau:
• App phía Người dân (Khai báo/Đặt lịch): Người dân đăng ký tài khoản → Khai báo thông tin y tế/Đặt lịch khám → App xuất ra một mã QR Code định danh cuộc hẹn.
• App/Phần mềm phía Phòng khám (HIS): Quét mã QR của người dân để tiếp nhận → Bác sĩ khám, kê đơn, nhập liệu kết quả → Hệ thống phòng khám đóng gói dữ liệu theo chuẩn XML/JSON → Đẩy lên Cổng tiếp nhận dữ liệu Hệ thống Thông tin giám định BHYT (của BHXH Việt Nam) hoặc Cổng Hồ sơ sức khỏe điện tử (của Bộ Y tế).
• Đồng bộ sang VNeID: BHXH Việt Nam và Bộ Y tế phối hợp với Bộ Công an để tự động hiển thị các dữ liệu này lên mục "Sổ sức khỏe điện tử" trên ứng dụng VNeID của người dân.

2. Các tính năng cốt lõi cần lập trình

Để hoàn thiện ứng dụng, đội ngũ phát triển (Dev) của bạn cần xây dựng các tính năng đồng bộ sau:

Phía Ứng dụng cho Người dân (Bệnh nhân)

• Đăng nhập bằng VNeID (SSO - Single Sign-On): Tích hợp dịch vụ chia sẻ định danh mã nguồn mở của Bộ Công an nếu được cấp phép, hoặc đơn giản hơn là tích hợp bộ quét OCR/Mã QR trên thẻ Căn cước công dân (CCCD) để tự động điền thông tin cá nhân chính xác 100% giống trên VNeID.
• Khai báo y tế & Đặt lịch: Cho phép chọn chuyên khoa, giờ khám, và khai báo trước tiền sử bệnh lý, dị ứng.

Phía Ứng dụng cho Phòng khám (Web/App HIS)

• Module tiếp nhận qua QR Code: Tích hợp máy quét (hoặc camera điện thoại) quét mã QR từ app người dân hoặc quét trực tiếp mã QR trên ứng dụng VNeID (thẻ BHYT/CCCD điện tử) để đối chiếu nhân thân.
• API Gateway kết nối Bộ Y tế: Đây là phần quan trọng nhất. Bạn cần lập trình cổng API để kết xuất dữ liệu tóm tắt hồ sơ bệnh án theo đúng định dạng chuẩn dữ liệu đầu ra quy định tại Quyết định 130/QĐ-BHXH (hoặc các thông tư, quyết định cập nhật mới nhất của Bộ Y tế về Sổ sức khỏe điện tử VNeID).

3. Thủ tục pháp lý & Các bước triển khai cho Doanh nghiệp

Để App của bạn chính thức đi vào hoạt động và dữ liệu có thể liên thông, bạn phải thực hiện các bước sau:
1. Đăng ký tài khoản doanh nghiệp/Cơ sở y tế: Phòng khám của bạn (hoặc các phòng khám đối tác sử dụng app của bạn) cần phải đăng ký cấp mã cơ sở khám chữa bệnh với Bộ Y tế và xin cấp tài khoản trên Cổng tiếp nhận dữ liệu giám định BHYT (kể cả phòng khám tư nhân không khám BHYT cũng phải đăng ký cổng này để liên thông dữ liệu sang VNeID).
2. Kiểm thử kết nối (Testing API): Đội ngũ kỹ thuật sử dụng tài khoản được cấp để gửi thử nghiệm các gói tin chứa dữ liệu khám bệnh (mã bệnh ICD-10, đơn thuốc, thông tin hành chính) lên môi trường Sandbox (thử nghiệm) của Cổng tiếp nhận.
3. Phê duyệt và chuyển đổi môi trường thật (Production): Sau khi dữ liệu test đạt chuẩn, cơ quan quản lý sẽ kích hoạt cổng chính thức. Từ lúc này, mỗi khi phòng khám hoàn tất một ca khám trên app của bạn, dữ liệu sẽ chạy thẳng lên hệ thống quốc gia và hiển thị trên VNeID của bệnh nhân.
Để tôi có thể tư vấn sâu hơn về mặt kỹ thuật cho dự án này, bạn vui lòng cho biết thêm:
• Bạn là đơn vị tự phát triển phần mềm (Tech Company) hay là chủ phòng khám muốn thuê dịch vụ bên ngoài làm?
• Đội ngũ của bạn đã từng làm việc với các giao thức kết nối API của cơ quan nhà nước (như BHXH hay Bộ Y tế) trước đây chưa?
• 
Facebook
Bộ Y tế hướng dẫn kết nối dữ liệu khám sức khỏe và cập nhật Sổ ...
7 June 2026 — Từ nay, lịch sử khám chữa bệnh sẽ được tích hợp trên VNeID Dữ liệu khám sức khỏe, khám chữa bệnh sẽ được liên thông lên VNeID,
• 
Facebook
Người dân sử dụng Sổ sức khoẻ điện tử VNeID khi đi khám, chữa ...
26 Nov 2024 — Chú ý: các thông tin trên VNeID có giá trị như trên bản giấy: thông tin cá nhân; số định danh công dân; thông tin thẻ BHYT; lịch s...
• 
Facebook·Sức Khỏe Cộng Đồng
5 bước dùng Sổ sức khỏe điện tử VNeID khi đi khám bệnh
21 Sept 2026 — VNeID khi đi khám bệnh … 5 bước dùng Sổ sức khỏe điện tử VNeID khi đi khám bệnh. Summarized by AI from the post below
Show all

Tech Company, chưa từng làm việc với các  giao thức kết nối API của cơ quan nhà nước (như BHXH hay Bộ Y tế)

Chào bạn, vì bạn là một Tech Company bắt đầu từ số 0 với các hệ thống API ngành y tế, bạn cần lưu ý rằng việc kết nối này đòi hỏi sự chuẩn chỉnh về mặt cấu trúc dữ liệu theo quy định pháp luật.
Dưới đây là cẩm nang kỹ thuật và quy trình thực tế giúp đội ngũ của bạn bắt tay vào xây dựng hệ thống kết nối dữ liệu từ App lên hệ thống để hiển thị trên VNeID.

1. Kiến trúc luồng dữ liệu chuẩn (Technical Data Flow)

Do không được kết nối trực tiếp vào VNeID, luồng đi của dữ liệu sẽ được thiết lập như sau:
Hide Code
Download diagram SVG
ASCII
[App người dân] -> (Khai báo/Đặt lịch) 
      ↓
[Hệ thống Backend của bạn] 
      ↓ (Bác sĩ nhập liệu lâm sàng, đơn thuốc)
[Cổng API của bạn] 
      ↓ (Gửi gói tin XML/JSON qua HTTPS)
[Cổng tiếp nhận dữ liệu BHXH Việt Nam / Bộ Y tế] 
      ↓ (Hệ thống quốc gia tự đồng bộ)
[Ứng dụng VNeID của người dân]
Use code with caution.

2. Hai chuẩn kết nối bắt buộc phải lập trình

Hiện tại, Bộ Y tế và Bảo hiểm xã hội (BHXH) Việt Nam quản lý việc liên thông này qua 2 kênh chính. Đội Dev của bạn cần nghiên cứu tài liệu kỹ thuật sau:
• Chuẩn dữ liệu đầu ra 130 (Quyết định 130/QĐ-BHXH): Đây là chuẩn cốt lõi nhất. Hệ thống của bạn phải đóng gói dữ liệu khám chữa bệnh thành các file XML (gồm XML1 đến XML5, mở rộng thêm XML7, XML8... tùy dịch vụ) chứa thông tin hành chính, đơn thuốc, cận lâm sàng, vật tư y tế.
• Chuẩn kết nối XML/JSON qua Web Service/API: Thường sử dụng giao thức HTTPS SOAP hoặc RESTful API để đẩy gói dữ liệu đã ký số (Digital Signature) lên cổng giám định.

3. Lộ trình triển khai cho Đội ngũ Kỹ thuật (Dev Roadmap)

Do công ty bạn chưa từng làm việc với API nhà nước, hãy đi theo 4 bước thực tế sau để tránh bỡ ngỡ:

Bước 1: Nghiên cứu tài liệu nghiệp vụ y tế

• Yêu cầu BA/Dev đọc kỹ Quyết định 130/QĐ-BHXH và các thông tư hướng dẫn về Sổ sức khỏe điện tử của Bộ Y tế.
• Hiểu rõ các bảng mã danh mục dùng chung (Mã bệnh ICD-10, mã thuốc tân dược, mã hoạt chất, mã tỉnh thành/quận huyện). Toàn bộ dữ liệu người dùng nhập vào phải được map (ánh xạ) về các mã danh mục chuẩn này trước khi gửi đi.

Bước 2: Tích hợp Chữ ký số (Token CA) vào Backend

• Mọi gói tin gửi lên API của Cơ quan Nhà nước đều yêu cầu phải được ký số của Cơ sở y tế (phòng khám sử dụng App của bạn).
• Đội Dev cần viết module kết nối với USB Token hoặc giải pháp Ký số từ xa (Remote Signing) để tự động ký vào file dữ liệu (XML/JSON) trước khi gọi API push dữ liệu.

Bước 3: Mượn tài khoản Sandbox (Môi trường Test)

• Do bạn là bên làm phần mềm (Vendor), bạn không tự xin tài khoản được. Bạn cần phối hợp với 1 phòng khám đối tác (đơn vị có giấy phép hoạt động y tế).
• Nhờ phòng khám này làm đơn xin cấp tài khoản test (Cổng tiếp nhận dữ liệu của BHXH Việt Nam hoặc Cổng hồ sơ sức khỏe điện tử địa phương). Cơ quan quản lý sẽ cấp cho họ (và họ giao lại cho bạn) tài liệu API, URL Endpoint test và Account test.

Bước 4: Viết API Client, Test lỗi và Đối soát

• Tiến hành lập trình module kết nối, bắt các mã lỗi trả về (Response Code) từ hệ thống nhà nước (ví dụ: lỗi sai định dạng ngày tháng, lỗi sai mã ICD-10, lỗi chữ ký số không hợp lệ).
• Khi đẩy dữ liệu test thành công 100% không còn lỗi, phòng khám đối tác sẽ làm thủ tục nghiệm thu kỹ thuật với cơ quan quản lý để chuyển sang môi trường chạy thật (Production).

4. Đề xuất tính năng "Khai báo nhanh" cho App người dân

Trong lúc chờ hoàn thiện cổng kết nối API phức tạp phía Backend với Nhà nước, ở phiên bản đầu tiên (MVP) của App phía người dân, bạn có thể làm ngay tính năng sau để tăng trải nghiệm:
• Quét QR Code của VNeID/CCCD: Lập trình tính năng bật camera quét mã QR trên ứng dụng VNeID (hoặc trên thẻ CCCD chip) của người dân.
• Tự động điền (Auto-fill): Giải mã chuỗi text từ QR đó để tự động điền các trường: Họ tên, Số định danh cá nhân (CCCD), Ngày sinh, Giới tính, Địa chỉ. Việc này giúp người dân khai báo y tế/đặt lịch trong 2 giây mà không cần gõ chữ, đồng thời đảm bảo thông tin khớp chính xác 100% với VNeID khi đồng bộ sau này.
Để hỗ trợ đội ngũ của bạn định hướng công nghệ, bạn có thể chia sẻ:
• Backend của hệ thống bên bạn dự định xây dựng bằng ngôn ngữ/framework nào (Node.js, Java, .NET, Python...)?
• Bạn có cần tôi cung cấp cấu trúc ví dụ của gói dữ liệu chuẩn XML 130 để các bạn hình dung không?
AI can make mistakes, so double-check responses 

các phần mềm quản lý phòng khám cho dùng thử cài đặt trên window

Để nghiên cứu, phân tích tính năng hoặc phục vụ mục đích thiết kế ngược (reverse engineering) cấu trúc dữ liệu y tế, đội ngũ phát triển của bạn có thể tham khảo các phần mềm quản lý phòng khám (HIS/Clinic Software) chạy trên nền tảng Windows cho phép tải bộ cài hoặc đăng ký dùng thử.
Dưới đây là danh sách phân loại theo mô hình vận hành (Offline cài trực tiếp hoặc Hybrid/Cloud chạy qua Windows Client) để bạn dễ lựa chọn:

1. Nhóm phần mềm Offline (Cài đặt file .exe/.msi trực tiếp lên Windows)

Nhóm này rất phù hợp để Dev nghiên cứu vì dữ liệu (SQL Server, MS Access hoặc MySQL) lưu cục bộ trên máy, dễ dàng "soi" cấu trúc DB để học cách họ thiết kế bảng mã danh mục y tế.
• MeClinic (Medict): Hỗ trợ đầy đủ các phiên bản hệ điều hành từ Windows 7 đến Windows 11. Bạn có thể tải trực tiếp gói cài đặt từ trang chủ Medict.mobi. Phần mềm này có cơ chế kích hoạt tự động và cho phép cài đặt chạy thử nghiệm trực tiếp.
• TinNghe (TinNghe.com): Hoạt động theo mô hình Client-Server (dữ liệu nằm tập trung tại máy chủ Windows hoặc máy trạm). Đơn vị này cho phép dùng thử 1 tháng, giao diện thuần Việt, rất thích hợp cho mô hình phòng khám nhỏ và vừa để nghiên cứu luồng tiếp nhận - kê đơn.
• Nano-Clinic (của Nanosoft): Phiên bản offline của đơn vị này chạy hoàn toàn cục bộ trên hệ điều hành Windows mà không cần kết nối Internet. Bạn có thể liên hệ thông qua website Nanosoft.vn để xin bản Setup demo nhằm phân tích sâu cấu trúc của một hệ thống có hơn 13 năm kinh nghiệm trong ngành y tế.

2. Nhóm phần mềm Hybrid / Cloud (Chạy qua Trình duyệt Windows hoặc App Client)

Nhóm này giúp bạn nghiên cứu giao diện (UI/UX) hiện đại, luồng đi của bệnh nhân (Workflow) và các tính năng đặt lịch online vốn là xu hướng kết nối với VNeID.
• YouMed Clinic: Hỗ trợ chạy mượt mà trên môi trường Windows thông qua mọi trình duyệt web. Điểm cộng lớn nhất cho Tech Company là họ cho phép dùng thử miễn phí lên đến 6 tháng. Bạn có thể đăng ký tài khoản test trực tiếp tại website của YouMed để nghiên cứu tính năng kê đơn thuốc điện tử liên thông Cổng Dược Quốc gia.
• EvoMed: Hỗ trợ ứng dụng native cho nền tảng Windows. Phần mềm này được đánh giá là rất chuyên sâu về nghiệp vụ cho các phòng khám đa khoa vừa và lớn, hỗ trợ kết nối hệ thống xét nghiệm (LIS) và chẩn đoán hình ảnh (PACS). Họ cho phép đăng ký dùng thử miễn phí trong vòng 1 tháng.
• TCSOFT Medical: Một giải pháp quản lý y tế chạy tốt trên Windows, giao diện trực quan và phân tách rõ ràng các luồng: Tiếp nhận → Phòng khám → Nhà thuốc. Phần mềm này hỗ trợ chính sách dùng thử miễn phí 1 tháng để doanh nghiệp trải nghiệm.

Kế hoạch hành động gợi ý cho Đội Dev (Tech Company):

1. Nếu muốn nghiên cứu Database (Cơ sở dữ liệu): Hãy ưu tiên tải bản cài đặt của MeClinic hoặc xin bản offline của Nanosoft. Sau khi cài đặt trên Windows, bạn có thể kiểm tra thư mục cài đặt để xem hệ thống sử dụng hệ quản trị cơ sở dữ liệu nào (ví dụ SQL Server) nhằm phân tích cách họ liên kết bảng Bệnh nhân, bảng Đơn thuốc và bảng Mã bệnh ICD-10.
2. Nếu muốn nghiên cứu Workflow (Luồng nghiệp vụ): Hãy đăng ký ngay 1 tài khoản dùng thử của YouMed Clinic (được tới 6 tháng) để hiểu cách một bác sĩ thao tác lâm sàng trên máy tính Windows diễn ra như thế nào, từ đó thiết kế UI/UX cho phần mềm của riêng bạn sao cho tối ưu nhất.
Bạn có muốn tôi hướng dẫn cách phân tích cấu trúc cơ sở dữ liệu y tế (ví dụ các trường thông tin cần thiết của một bảng Bệnh_Nhân hay Đơn_Thuốc để sau này đẩy dữ liệu lên cổng BHXH/VNeID không?
• 
medict.mobi
Phần mềm quản lý phòng khám - Medict.mobi
Phần mềm phòng khám MeClinic Offline có sẵn gói cài đặt hỗ trợ các phiên bản. Windows từ Windows 7 trở lên, bao gồm: Windows 7; Wi...
• 
stdvietnam.vn
Top 5 phần mềm quản lý phòng khám tốt nhất hiện nay
phần mềm áp dụng tính phí theo hình thức giấy phép sử dụng có thời hạn tuy nhiên có thể dùng thử trong vòng 1 tháng trước khi đưa ...
• 
YouMed
Top 5 phần mềm quản lý phòng khám chất lượng
4 Mar 2023 — Microsoft Windows: Windows 10, Windows 8, Windows 7, Windows Vista. TCSoft Medical có thể dùng thử miễn phí trong vòng 1 tháng.
Show all

yes

Để chuẩn bị cho việc đồng bộ dữ liệu lên cổng Bảo hiểm Xã hội (BHXH) và hiển thị trên Sổ sức khỏe điện tử VNeID, cấu trúc Cơ sở dữ liệu (Database Schema) của bạn phải thiết kế theo Quyết định 130/QĐ-BHXH. Hệ thống của bạn không được tự chế các trường thông tin mà phải tuân thủ nghiêm ngặt các bảng mã danh mục chuẩn quốc gia.
Dưới đây là thiết kế cấu trúc Database thực tế cho 2 bảng cốt lõi nhất: Bảng Bệnh Nhân (Patient) và Bảng Đơn Thuốc/Khám Bệnh (Medical_Record) được tối ưu sẵn cho việc xuất file XML/JSON liên thông.

1. Bảng Bệnh Nhân (Table: Patients)

Bảng này lưu trữ thông tin hành chính. Để liên thông VNeID, Số định danh cá nhân (CCCD) và Mã số BHXH (Thẻ BHYT) là hai trường bắt buộc phải chính xác.

Tên trường (Column Name)	Kiểu dữ liệu	Ràng buộc	Mục đích & Chuẩn liên thông VNeID
id	BigInt / UUID	Primary Key	Khóa chính của hệ thống bên bạn.
patient_code	VARCHAR(20)	Unique	Mã quản lý bệnh nhân tại phòng khám (Mã YT).
citizen_id	VARCHAR(12)	Not Null / Unique	Số định danh cá nhân (12 số). Dùng để đồng bộ đúng tài khoản VNeID.
bhxh_code	VARCHAR(10)	Nullable	Mã số BHXH / Mã thẻ BHYT (10 số cuối). Bắt buộc nếu khám BHYT.
full_name	VARCHAR(100)	Not Null	Họ và tên (Phải viết HOA có dấu, ví dụ: NGUYỄN VĂN A).
dob	DATE / INT	Not Null	Ngày sinh. Chuẩn định dạng chuỗi gửi đi thường là YYYYMMDD.
gender_code	TINYINT	Not Null	Mã giới tính chuẩn: 1: Nam, 2: Nữ, 3: Khác (Theo chuẩn Bộ Y tế).
province_code	VARCHAR(3)	Not Null	Mã Tỉnh/Thành phố nơi cư trú (Theo danh mục Tổng cục Thống kê).
district_code	VARCHAR(3)	Not Null	Mã Quận/Huyện nơi cư trú.
ward_code	VARCHAR(5)	Not Null	Mã Phường/Xã nơi cư trú.
phone_number	VARCHAR(10)	Nullable	Số điện thoại liên hệ.


2. Bảng Hồ Sơ Khám Bệnh & Đơn Thuốc (Table: Medical_Records)

Bảng này tương ứng với dữ liệu lâm sàng, kết quả chẩn đoán và đơn thuốc mà bác sĩ kê trên Windows App của phòng khám. Khi xuất dữ liệu gửi lên cổng quốc gia, bảng này sẽ được tách ra thành các file XML con (XML1: Tổng hợp, XML2: Đơn thuốc...).

Tên trường (Column Name)	Kiểu dữ liệu	Ràng buộc	Mục đích & Chuẩn liên thông VNeID
id	BigInt / UUID	Primary Key	Khóa chính của lượt khám.
patient_id	BigInt / UUID	Foreign Key	Liên kết với bảng Patients(id).
clinic_code	VARCHAR(20)	Not Null	Mã cơ sở khám chữa bệnh do Bộ Y tế cấp cho phòng khám của bạn.
checkin_time	DATETIME	Not Null	Thời gian vào khám (Định dạng gửi đi: YYYYMMDDHHMM).
checkout_time	DATETIME	Not Null	Thời gian ra viện/kết thúc khám.
icd10_main_code	VARCHAR(10)	Not Null	Mã bệnh chính (Chuẩn ICD-10). Ví dụ: I10 (Cao huyết áp).
icd10_sub_codes	VARCHAR(255)	Nullable	Mã bệnh kèm theo (Các mã ICD-10 cách nhau bằng dấu phẩy).
diagnosis_text	NVARCHAR(500)	Not Null	Chẩn đoán lâm sàng bằng chữ của bác sĩ.
treatment_plan	NVARCHAR(500)	Nullable	Hướng điều trị / Lời dặn của bác sĩ.
prescription_json	JSON / Text	Nullable	Chi tiết đơn thuốc. (Xem cấu trúc chi tiết bên dưới).
status_xml	TINYINT	Default 0	Trạng thái đồng bộ: 0: Chưa gửi, 1: Đã gửi, 2: Lỗi đồng bộ.


Cấu trúc dữ liệu Đơn thuốc (prescription_json)

Cổng liên thông yêu cầu bóc tách từng mục thuốc rất chi tiết. Cấu trúc JSON bên trong trường này nên được thiết kế như sau để dễ dàng chuyển đổi sang XML:
json
[
  {
    "ma_thuoc": "01.234.567", // Phải lấy từ Danh mục thuốc Tân dược của Bộ Y tế
    "ten_thuoc": "Paracetamol 500mg",
    "don_vi_tinh": "Viên",
    "so_luong": 10,
    "lieu_dung": "Uống ngày 2 lần, mỗi lần 1 viên sau ăn",
    "ma_duong_dung": "1.01" // Mã đường uống theo danh mục chuẩn
  }
]
Use code with caution.

3. Lời khuyên thiết kế hệ thống (Architecture Tips cho Dev)

• Xây dựng Master Data Services: Ngay từ đầu, bạn phải tạo một module quản lý Danh mục dùng chung. Hệ thống phải nạp sẵn toàn bộ danh mục mã bệnh ICD-10, danh mục Thuốc quốc gia, danh mục Hành chính (Tỉnh/Huyện/Xã). Khi người dùng (bác sĩ/nhân viên) nhập liệu, họ chỉ được phép chọn (Select/Auto-complete) từ danh mục này, tuyệt đối không cho gõ tự do (free text) các trường mã định danh.
• Thiết kế sẵn Module Queue (Hàng đợi gửi tin): Việc gửi dữ liệu lên cổng BHXH/Bộ Y tế qua API đôi khi sẽ bị nghẽn mạng hoặc lỗi hệ thống phía nhà nước. Bạn nên dùng một hệ thống hàng đợi (như RabbitMQ, BullMQ trong Node.js, hoặc dùng bảng tạm trong DB) để lưu các bản ghi chờ gửi. Nếu gửi lỗi, hệ thống sẽ tự động gửi lại (Retry mechanism) sau mỗi 15-30 phút.
Để bắt tay vào code thử nghiệm, đội ngũ của bạn có cần tôi cung cấp một đoạn mẫu file XML chuẩn dữ liệu 130 (chứa thông tin bệnh nhân và đơn thuốc mẫu) để các bạn hình dung cấu trúc gói tin sẽ gửi đi không?

yes

Here is a standardized XML payload example formatted according to Decision 130/QĐ-BHXH.
When communicating with government gateways (Ministry of Health or Vietnam Social Security), data is split into multiple files (XML1 to XML5, etc.). The most foundational file is XML1, which handles the core Patient Demographics and Encounter Summary.

1. Sample XML1 File (Patient & Encounter Summary)

Save this structure as a template for your API serialization module. Note how every field uses rigid, uppercase tag names and standardized string formats (such as YYYYMMDDHHMM for timestamps):
xml
<?xml version="1.0" encoding="utf-8"?>
<HO_SO>
    <CHECK_SUM>STRING_MD5_HASH_OF_ENVELOPE</CHECK_SUM>
    <DATA>
        <XML1>
            <!-- 1. Administrative & VNeID Linking Data -->
            <MA_LK>PK202610140001</MA_LK> <!-- Unique Encounter ID generated by your App -->
            <MA_BN>BN_998877</MA_BN> <!-- Patient Code in your Clinic Database -->
            <HO_TEN>NGUYEN VAN A</HO_TEN> <!-- MUST BE UPPERCASE WITH SIGNS -->
            <NGAY_SINH>19900515</NGAY_SINH> <!-- Format: YYYYMMDD -->
            <GIOI_TINH>1</GIOI_TINH> <!-- 1: Male, 2: Female, 3: Other -->
            <SO_CCCD>012345678912</SO_CCCD> <!-- Critical: 12-digit Citizen ID for VNeID matching -->
            <MA_THE_BHYT></MA_THE_BHYT> <!-- Leave blank if private out-of-pocket patient -->
            <MA_DKBD></MA_DKBD> 
            
            <!-- 2. Address Codes (Must match General Statistics Office master data) -->
            <MA_QUAN_HUYEN>001</MA_QUAN_HUYEN> 
            <MA_PHUONG_XA>00001</MA_PHUONG_XA>
            <DIA_CHI>123 Duong Le Loi, Phuong Ben Nghe, Quan 1, TP.HCM</DIA_CHI>
            
            <!-- 3. Clinic Information -->
            <MA_CSKCB>79001</MA_CSKCB> <!-- Official Ministry of Health Clinic Code -->
            
            <!-- 4. Clinical Details -->
            <NGAY_VAO>202610140830</NGAY_VAO> <!-- Check-in: YYYYMMDDHHMM -->
            <NGAY_RA>202610140915</NGAY_RA> <!-- Check-out: YYYYMMDDHHMM -->
            <MA_BENH>I10</MA_BENH> <!-- Main Diagnosis: Standard ICD-10 Code (e.g., Essential Hypertension) -->
            <MA_BENH_KT>E11,K29</MA_BENH_KT> <!-- Comorbidities: Comma-separated ICD-10 codes -->
            <CHAN_DOAN>Cao huyet ap vo can, dai thao duong tuyp 2, viem da day</CHAN_DOAN>
            
            <!-- 5. Outcome -->
            <MA_LOAI_KCB>1</MA_LOAI_KCB> <!-- 1: Outpatient, 2: Inpatient -->
            <KET_QUA_DTRI>1</KET_QUA_DTRI> <!-- 1: Cured/Improved, 2: Unchanged, 3: Worse -->
            <TINH_TRANG_RA_VIEN>1</TINH_TRANG_RA_VIEN> <!-- 1: Discharged home, 2: Transferred -->
        </XML1>
    </DATA>
</HO_SO>
Use code with caution.

2. Sample XML2 File (Prescription Data)

If the doctor prescribes medication, your system must generate a corresponding XML2 node linked to the same MA_LK (Encounter ID). This is what injects the active prescription into the user's VNeID App:
xml
<XML2>
    <MA_LK>PK202610140001</MA_LK> <!-- Must exactly match the MA_LK in XML1 -->
    <STT>1</STT> <!-- Sequence number of the item -->
    <MA_THUOC>22.105.0192</MA_THUOC> <!-- Official National Drug Code issued by MoH -->
    <TEN_THUOC>Paracetamol 500mg</TEN_THUOC>
    <DON_VI_TINH>Vien</DON_VI_TINH>
    <SO_LUONG>10</SO_LUONG>
    <MA_DUONG_DUNG>1.01</MA_DUONG_DUNG> <!-- National Route of Administration Code (1.01 = Oral) -->
    <LIEU_DUNG>Uong ngay 2 lan, moi lan 1 vien sau khi an no</LIEU_DUNG>
</XML2>
Use code with caution.

3. Key Implementation Roadmap for your Dev Team

1. Map Backend to XML Classes: Create data transfer object (DTO) models or serialization classes in your backend framework (e.g., C# Classes, Java POJOs, or TypeScript Interfaces) that mirror these exact tag names.
2. Handle the MA_LK: Ensure your internal database generates an immutable, unique string for MA_LK per clinic visit. This serves as the foreign key tying all relational tables (Patient, Diagnosis, Drugs) together into a single cohesive VNeID electronic health record file.
3. The CHECK_SUM Header: Government gateways typically require you to hash the inner <DATA> content payload using an MD5 or SHA256 algorithm and place it in the <CHECK_SUM> header to verify data integrity during transmission.