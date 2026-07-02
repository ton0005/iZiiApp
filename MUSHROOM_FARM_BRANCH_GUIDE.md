# Mushroom Farm Branch Guide

## Mục đích
Tài liệu này giúp bạn phát triển FrontEnd riêng cho Mushroom Farm trên nhánh riêng, đồng thời vẫn có thể quay lại phát triển cho iZiiApp trên nhánh main một cách an toàn.

## 1. Tạo và chuyển sang nhánh riêng
```bash
git checkout -b mushroom-farm-fork
```

Nếu bạn đã ở nhánh khác và muốn chuyển sang nhánh này:
```bash
git checkout mushroom-farm-fork
```

## 2. Phát triển feature cho Mushroom Farm
Tất cả thay đổi FrontEnd dành cho Farm nên được làm trên nhánh này.

## 3. Commit thay đổi
```bash
git add .
git commit -m "feat: add mushroom farm frontend updates"
```

## 4. Push nhánh lên remote
```bash
git push -u origin mushroom-farm-fork
```

## 5. Build và Release cho Mushroom Farm
### Build Flutter
```bash
flutter pub get
flutter analyze
flutter build apk --release
# hoặc cho iOS
flutter build ios --release
```

### Checklist Release
- [ ] Đã test trên device/emulator
- [ ] Đã chạy `flutter analyze`
- [ ] Đã build bản release thành công
- [ ] Đã kiểm tra tên app, icon, theme riêng cho Farm
- [ ] Đã lưu bản build và version code/version name
- [ ] Đã tạo tag hoặc release riêng nếu cần

### Ghi chú cho Farm
- Dùng bản build từ nhánh này cho sản phẩm riêng
- Nếu cần đổi tên app hoặc branding, nên làm riêng trên nhánh này
- Không để các thay đổi Farm ảnh hưởng trực tiếp tới main

## 6. Quay lại phát triển cho iZiiApp trên main
```bash
git checkout main
```

## 7. Nếu muốn dùng lại code từ nhánh Farm vào main
### Chọn một commit cụ thể
```bash
git checkout main
git cherry-pick <commit-id>
```

### Hoặc merge toàn bộ nhánh Farm vào main
```bash
git checkout main
git merge mushroom-farm-fork
```

## 8. Mẹo an toàn
- Luôn commit trước khi chuyển nhánh
- Không làm trực tiếp trên main nếu đang phát triển riêng cho Farm
- Nếu cần, tạo nhánh phụ cho từng feature lớn

## 9. Kiểm tra trạng thái hiện tại
```bash
git status
git branch --show-current
```

## 10. Mẫu workflow thường dùng
```bash
git checkout mushroom-farm-fork
git add .
git commit -m "feat: add farm frontend feature"
git push -u origin mushroom-farm-fork
flutter pub get
flutter analyze
flutter build apk --release
```
