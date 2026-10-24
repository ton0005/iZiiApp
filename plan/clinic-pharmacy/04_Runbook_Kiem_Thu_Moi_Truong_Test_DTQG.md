# RUNBOOK — KIỂM THỬ TRÊN MÔI TRƯỜNG TEST ĐƠN THUỐC QUỐC GIA

Dùng khi phòng khám đối tác đã cấp **mã liên thông + mật khẩu** (cơ sở và ít nhất một bác sĩ) và URL môi trường test. Liên quan: `03_Ke_Hoach_Clinic_Pharmacy_Don_Thuoc_Quoc_Gia_QD808.md` (mục 9: các mâu thuẫn cần xác minh).

> **Quy tắc an toàn:** đơn đã gửi **không sửa, không xóa** (FAQ 1.14, 1.19). Chỉ chạy trên môi trường TEST, với bệnh nhân giả. Mật khẩu chỉ đặt qua biến môi trường hoặc API quản trị, không ghi vào file trong repo.

## 0. Chuẩn bị (một lần)

| Việc | Cách làm |
|---|---|
| Khóa mã hóa mật khẩu | `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` → `IZIIAPP_DTQG_CRED_KEY` trong `server/.env`. **Sao lưu khóa này** — mất khóa phải nhập lại mật khẩu |
| URL test | `IZIIAPP_DTQG_API_BASE`, `IZIIAPP_DTQG_WEB_BASE` (hai địa chỉ có thể khác nhau, xem plan mục 2) |
| Mã cơ sở KCB 5 ký tự | Lấy từ mã liên thông cơ sở: bỏ tiền tố `01` (VD `0101aaa` → `01aaa`). Nhập ở app: Phòng khám → biểu tượng cài đặt |
| Bác sĩ | Nhập số CCHN ở form bác sĩ → app tự sinh mã liên thông `01` + CCHN bỏ `/`. **Đối chiếu với mã hệ thống thật cấp**; nếu khác, sửa công thức (`DtqgRules.maLienThongBacSi` trong Dart, dùng ở `repository.addDoctor`) |

## 1. Thử đăng nhập (không tạo dữ liệu)

```bash
cd server
export DTQG_API_BASE=<url test> DTQG_WEB_BASE=<url test>
export DTQG_FACILITY_CODE=... DTQG_FACILITY_PASS=... DTQG_DOCTOR_CODE=... DTQG_DOCTOR_PASS=...
python scripts/dtqg_smoke.py login
```

Kiểm tra:
- [ ] Đăng nhập cơ sở trả `token` (mục III).
- [ ] Thêm bác sĩ: 200, hoặc 422 "đã tồn tại" đều chấp nhận được. **Ghi lại nguyên văn câu 422** — `DtqgGateway._ensure_linked` đang nhận diện bằng các cụm "tồn tại", "đã có", "đã được thêm"; nếu câu thật khác, sửa danh sách đó.
- [ ] Đăng nhập bác sĩ trả `token` (khóa kiểu `token_type` hay `tocken_type` — code chỉ đọc `token`, không phụ thuộc).
- [ ] Bác sĩ chưa được thêm → 422 chứa "chưa được thêm vào cơ sở"? Câu này `dtqg_service._doctor_token` dùng để tự thêm lại. Nếu câu thật khác → sửa.

## 2. Chốt các mâu thuẫn tài liệu (gửi đơn thử)

```bash
python scripts/dtqg_smoke.py send --yes --variants        # tạo 3 đơn thử (test)
# có app-name/app-key thì thêm DTQG_APP_NAME / DTQG_APP_KEY để tra lại đơn
```

| # | Điểm cần chốt | Cách đọc kết quả | Sửa ở |
|---|---|---|---|
| 1 | Khóa chẩn đoán: `ma_benh/ten_benh` hay `ma_chan_doan/ten_chan_doan` | Biến thể nào trả 200 (hoặc cả hai). Nếu cả hai 200, đối chiếu "chẩn đoán trả về" khi tra lại đơn | `server/dtqg_payload.py` → `KEYS`; `DtqgRules.buildGuiDonPayload` (Dart) |
| 2 | Khóa số thẻ BHYT: `ma_so_bao_hiem_y_te` hay `ma_so_the_bao_hiem_y_te` | Như trên. Đơn thử không có thẻ BHYT nên có thể cả hai đều 200 — cần thử thêm đơn có thẻ BHYT thật (10 ký tự?) | `KEYS["bhyt"]` |
| 3 | Độ dài thẻ BHYT: bảng ghi 10, thẻ thật 15 | Gửi thẻ 15 ký tự: 422 → phải cắt/đổi | `validate_body` + `DtqgRules.validate` |
| 4 | Giờ kê đơn `H:m:s` hay `H:i:s` | So "ngày giờ kê đơn trả về" với giờ đã gửi (phút có đúng không); 422 nếu sai định dạng | `DATETIME_FORMAT` |
| 5 | JSON hay form-data | Nếu 200 với JSON thì giữ nguyên. Nếu 415/422 về định dạng → đổi `DtqgClient._call` | `dtqg_client.py` |
| 6 | `hinh_thuc_dieu_tri`: giá trị hợp lệ | Thử 1 và 2 (hiện mặc định 2 = ngoại trú); hỏi hỗ trợ kỹ thuật danh mục | `_VisitPaneState._hinhThuc` |
| 7 | `ma_thuoc`: có kiểm tra theo danh mục không | Gửi mã tự đặt (`TEST0001`): 200 hay 422? Quyết định có cần import danh mục thuốc | plan mục 9 (câu 9) |
| 8 | `signature` để trống có được không | Đơn thử đã gửi `signature: null` | `build_body` |
| 9 | Mã lỗi khi token hết hạn | Chờ token hết hạn hoặc dùng token sai: 401? Code xử lý 401 → đăng nhập lại 1 lần | `DtqgGateway._deliver` |
| 10 | Mã đơn trùng | Gửi lại đúng mã đơn đã gửi: trả gì? (Mock giả định 422) | `dtqg_service._send` (xử lý lỗi trùng) |

Sau mỗi sửa: `cd server && python -m unittest tests.test_dtqg_gateway tests.test_dtqg_pos tests.test_dtqg_router`, và `flutter test test/modules/clinic_pharma` nếu đổi phía Dart. Cập nhật **mock** (`tests/mock_dtqg_server.py`) cho khớp hành vi thật, bỏ nhãn "GIẢ ĐỊNH" ở điểm đã xác nhận.

## 3. Thử qua server iZii (đầu-cuối HIS)

1. Bật `IZIIAPP_DTQG_ENABLED=true`, khởi động lại server.
2. Đặt mật khẩu (token quản trị):
   ```bash
   curl -X PUT $SERVER/api/v1/dtqg/credentials -H "X-iZii-Admin-Token: $ADMIN" -H "Content-Type: application/json" \
     -d '{"subject_type":"facility","subject_code":"<mã cơ sở>","password":"<mk>"}'
   # lặp lại với subject_type "doctor", subject_code = mã liên thông bác sĩ
   ```
3. Trên app: tạo bác sĩ (trạng thái mã liên thông **Đã được duyệt**), thuốc có mã Cục QLD, bệnh nhân đủ SĐT/địa chỉ/ngày sinh; **Cài đặt cơ sở** có mã CSKCB.
4. Kê đơn → tab **Liên thông** phải chuyển Chờ gửi → Đã gửi (tối đa ~30 giây + thời gian đồng bộ).
5. Kiểm tra: `GET /api/v1/dtqg/status`, `GET /api/v1/dtqg/submissions?prescription_id=...`.
6. Thử lỗi cố ý: xóa SĐT bệnh nhân (bị chặn tại chỗ, không gọi mạng); sai mật khẩu bác sĩ (hiện 422 nguyên văn); tắt mạng server (đơn giữ Chờ gửi, bật lại tự gửi).

## 4. Thử nhà thuốc (POS)

Cần `app-name`/`app-key` do `hotrokythuat@donthuocquocgia.vn` cấp (đặt `IZIIAPP_DTQG_POS_APP_NAME/KEY`). Trên app: Nhà thuốc → **Bán theo đơn** → nhập/quét mã đơn đã gửi ở mục 3.
- [ ] Tra đơn trả đủ trường; thuốc khớp mã Cục QLD trong kho tự chọn đúng.
- [ ] Bán một phần → `cap-nhat-don-thuoc` 200; tra lại: iZii hiển thị đã bán/còn lại đúng.
- [ ] Bán thuốc thay thế: hệ thống nhận `ma_thuoc` mới + `ma_thuoc_da_ke_don` gốc?
- [ ] Bán vượt số kê: hệ thống thật có chặn 422 không (mock giả định có).
- [ ] Đơn quá 5 ngày: hệ thống có tự từ chối không, hay chỉ iZii chặn.
- [ ] `ma_hoa_don` tối đa 20 ký tự; `so_dien_thoai_co_so_cung_ung_thuoc` chỉ số.
- [ ] In biên nhận từ thông báo sau khi bán.

## 5. Tiêu chí hoàn thành (Giai đoạn D, E)

- Gửi thành công đơn `c` trên môi trường test, không còn lỗi.
- Lỗi 422 hiển thị nguyên văn cho bác sĩ; đơn `sent` không sửa/xóa được qua app.
- Token hết hạn tự đăng nhập lại; mất mạng tự gửi lại.
- Bán theo đơn cập nhật đúng số lượng, kho trừ đúng, đơn đã bán hết không bán tiếp.
- Mọi mục ở bảng mục 2 đã có kết luận và mock đã cập nhật.
