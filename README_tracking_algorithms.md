## Thuật Toán Theo Dõi Buổi Tập

Tài liệu này tổng hợp các thuật toán và công thức đang được sử dụng trong `lib/screens/tracking_screen.dart` để theo dõi, tính toán và lưu kết quả buổi tập của ứng dụng.

### Chế Độ Tập Luyện & Chỉ Số MET
- `Chạy bộ`: MET cơ bản `7.0`.
- `Đi bộ`: MET cơ bản `3.5`.
- `Đạp xe`: MET cơ bản `8.0`.
- `Leo núi`: MET cơ bản `8.0`, có điều chỉnh theo tốc độ thực tế.

Các giá trị MET được khai báo trong `lib/data/default_workouts.dart`. Khi kết thúc buổi tập, hệ thống có thể điều chỉnh MET dựa trên tốc độ trung bình bằng hàm `_getAdjustedMET`.

### Tính Calo Trong Khi Tập
1. Đồng hồ tập luyện tăng mỗi giây (`_startTimer`).
2. Mỗi phút, lượng calo tiêu hao được ước tính theo công thức chuẩn sử dụng MET:
   ```
   caloriesPerMinute = (MET * 3.5 * cân_nặng_kg) / 200
   caloriesBurned = caloriesPerMinute * (thời_gian_đã_tập_phút)
   ```
3. `MET` sử dụng giá trị mặc định (`activityType.metValue`) trong khi đang tập để cập nhật UI theo thời gian thực.

### Điều Chỉnh MET Khi Kết Thúc
Khi người dùng nhấn dừng, ứng dụng tính lại calo dựa trên tốc độ trung bình:
```
avgSpeedKmh = (tổng_quãng_đường_m / tổng_thời_gian_s) * 3.6
adjustedMET = _getAdjustedMET(avgSpeedKmh)
calo_cuối = (adjustedMET * 3.5 * cân_nặng_kg) / 200 * (thời_gian_đã_tập_phút)
```

#### Quy tắc điều chỉnh MET (`_getAdjustedMET`)
- Tốc độ < 1.5 km/h: MET = `1.0` (hầu như không vận động).
- `Đi bộ` hoặc `Chạy bộ` chậm (< 5 km/h): MET = `3.5`.
- `Đạp xe` chậm (< 15 km/h): MET = `6.0`.
- `Leo núi`:
  - < 3 km/h → MET = `10.0` (leo khó).
  - 3–5 km/h → MET = `8.5` (leo vừa).
  - > 5 km/h → dùng MET gốc `8.0`.
- Trường hợp khác: giữ nguyên MET ban đầu theo loại bài tập.

### Thu Thập & Lọc Dữ Liệu GPS
- GPS được lấy bằng `Geolocator.getPositionStream` với `distanceFilter = 10` mét giúp giảm nhiễu.
- Mỗi điểm mới được xử lý trong `_updateLocationData`:
  - Bỏ qua nếu khoảng cách giữa hai lần cập nhật > `100m` (`_maxDistancePerUpdate`) để giảm lỗi GPS.
  - Bỏ qua nếu quá gần (< `5m`) sau điểm đầu tiên nhằm tối ưu hiệu năng.
  - Quãng đường tích lũy: `tổng_quãng_đường += distanceBetween(điểm_trước, điểm_mới)`.
- Dữ liệu tuyến đường được làm mịn bởi `_filterAndSmoothRoutePoints` (moving average trên từng cụm 3 điểm) trước khi vẽ Polyline.

### Ghi Lại Quãng Đường & Vận Tốc
- Mỗi điểm GPS được lưu kèm `timestamp` trong `_routePointsWithTime`.
- Khi lưu buổi tập, hệ thống tạo `RouteSegment` cho từng cặp điểm liên tiếp:
  ```
  distanceMeters = distanceBetween(point[i-1], point[i])
  durationSeconds = timestamp[i] - timestamp[i-1]
  speedKmh = durationSeconds > 0 ? (distanceMeters / durationSeconds) * 3.6 : 0
  ```
- Các `RouteSegment` (nếu có dữ liệu hợp lệ) được lưu xuống Firestore cùng với danh sách `routePoints`.

### Lưu Kết Quả Buổi Tập
Kết quả cuối cùng (`WorkoutSession`) gồm:
- Loại hoạt động (`activityType`).
- Thời gian bắt đầu, tổng thời lượng.
- Tổng quãng đường (mét) và calo tiêu hao (kcal).
- Lộ trình GPS (`routePoints`) và các đoạn đường kèm vận tốc (`routeSegments`).

Những thông tin trên được xuất hiện trong hộp thoại hoàn thành và được lưu vào Firestore thông qua `DatabaseService.addWorkoutSession`.

