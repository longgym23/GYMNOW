# Hướng Dẫn Build Ứng Dụng Gym Now

## Yêu Cầu Trước Khi Build

1. **Cài đặt Flutter SDK** (nếu chưa có):
   ```bash
   flutter doctor
   ```

2. **Cài đặt dependencies**:
   ```bash
   flutter pub get
   ```

## Build Cho Các Nền Tảng

### 1. Android (APK/AAB)

#### Build APK (để cài trực tiếp):
```bash
flutter build apk --release
```
File sẽ được tạo tại: `build/app/outputs/flutter-apk/app-release.apk`

#### Build APK chia theo kiến trúc (nhỏ hơn):
```bash
# Chỉ cho ARM64 (hầu hết điện thoại hiện đại)
flutter build apk --release --split-per-abi
```
File sẽ được tạo tại: `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` hoặc `app-arm64-v8a-release.apk`

#### Build AAB (để upload lên Google Play Store):
```bash
flutter build appbundle --release
```
File sẽ được tạo tại: `build/app/outputs/bundle/release/app-release.aab`

### 2. iOS (IPA)

**Lưu ý**: Cần máy Mac và Xcode để build iOS

```bash
flutter build ios --release
```

Sau đó mở Xcode và archive để tạo file IPA:
1. Mở `ios/Runner.xcworkspace` trong Xcode
2. Chọn Product > Archive
3. Distribute App để tạo file IPA

### 3. Windows (EXE)

```bash
flutter build windows --release
```
File sẽ được tạo tại: `build/windows/runner/Release/gym_now.exe`

**Để tạo installer Windows:**
- Có thể sử dụng Inno Setup hoặc NSIS để tạo file cài đặt từ thư mục `build/windows/runner/Release/`

### 4. Linux (AppImage/DEB)

#### Build Linux:
```bash
flutter build linux --release
```
File sẽ được tạo tại: `build/linux/x64/release/bundle/`

**Tạo AppImage hoặc DEB package:**
- Cần cài đặt thêm công cụ như `linuxdeploy` hoặc `dpkg` để tạo package

### 5. macOS (APP/DMG)

**Lưu ý**: Cần máy Mac để build macOS

```bash
flutter build macos --release
```
File sẽ được tạo tại: `build/macos/Build/Products/Release/gym_now.app`

**Tạo DMG installer:**
- Sử dụng `create-dmg` hoặc Disk Utility để tạo file DMG

### 6. Web

```bash
flutter build web --release
```
File sẽ được tạo tại: `build/web/`

Có thể deploy lên:
- Firebase Hosting
- GitHub Pages
- Netlify
- Vercel
- Hoặc bất kỳ web server nào

## Lệnh Build Nhanh

### Build tất cả nền tảng (nếu có môi trường):
```bash
# Android
flutter build apk --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

## Kiểm Tra Platform Đã Enable

```bash
flutter config
```

Để enable platform:
```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
flutter config --enable-web
```

## Lưu Ý Quan Trọng

1. **Android**: Cần cấu hình signing key trong `android/app/build.gradle.kts` để publish lên Play Store
2. **iOS**: Cần Apple Developer Account và cấu hình certificates
3. **Windows/Linux/macOS**: Cần cấu hình code signing nếu muốn phân phối chính thức
4. **Firebase**: Đảm bảo file `google-services.json` (Android) và `GoogleService-Info.plist` (iOS) đã được cấu hình đúng

## Kích Thước File Dự Kiến

- **Android APK**: ~20-50 MB (tùy theo kiến trúc)
- **Android AAB**: ~15-30 MB
- **Windows EXE**: ~30-60 MB
- **iOS IPA**: ~20-50 MB
- **Web**: ~2-5 MB (sau khi nén)

## Troubleshooting

Nếu gặp lỗi khi build:
1. Chạy `flutter clean`
2. Chạy `flutter pub get`
3. Kiểm tra `flutter doctor` để đảm bảo môi trường đã được cấu hình đúng
4. Xem log chi tiết: `flutter build [platform] --release --verbose`

