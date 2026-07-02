# Flutter Build & Release Guide

## 1. Cài đặt phụ thuộc
```bash
flutter pub get
```

## 2. Kiểm tra lỗi code
```bash
flutter analyze
```

## 3. Build bản debug
```bash
flutter build apk --debug
```

## 4. Build bản release cho Android
```bash
flutter build apk --release
```

## 5. Build bản release cho iOS
```bash
flutter build ios --release
```

## 6. Kiểm tra version
Trong file pubspec.yaml, kiểm tra:
```yaml
version: 1.0.0+1
```

- `1.0.0` = version name
- `1` = version code

## 7. Checklist trước khi release
- [ ] Đã chạy `flutter analyze`
- [ ] Đã build thành công bản release
- [ ] Đã test trên device/emulator
- [ ] Đã kiểm tra tên app và icon
- [ ] Đã cập nhật version nếu cần
- [ ] Đã tạo tag hoặc release trên GitHub nếu cần

## 8. Tạo tag Git cho release
```bash
git tag v1.0.0
git push origin v1.0.0
```

## 9. Gợi ý cho nhánh Mushroom Farm
- Dùng nhánh `mushroom-farm-fork` cho bản riêng của Farm
- Build release từ nhánh này để tránh ảnh hưởng tới main
- Nếu cần, tạo release riêng cho Farm bằng tag khác
