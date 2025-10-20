import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot session; // Nhận toàn bộ document của buổi tập

  const WorkoutDetailScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController; // Không cần 'late'
  final LatLng _defaultLocation = const LatLng(10.762622, 106.660172); // Vị trí Hà Nội nếu cần
  bool _isPolylineCreated = false;
  LatLngBounds? _routeBounds; // Lưu bounds để zoom

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tạo polyline và tính bounds trong didChangeDependencies
    if (!_isPolylineCreated) {
      _createPolylineAndBounds();
      _isPolylineCreated = true;
    }
  }

  /// Tạo đường Polyline từ dữ liệu routePoints và tính toán bounds
  void _createPolylineAndBounds() {
    final data = widget.session.data() as Map<String, dynamic>;
    // Lấy danh sách điểm GeoPoint một cách an toàn
    final pointsData = data['routePoints'] as List<dynamic>? ?? [];

    if (pointsData.isEmpty) return;

    final routeCoordinates = pointsData
        .whereType<GeoPoint>() // Chỉ lấy các phần tử là GeoPoint
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (routeCoordinates.isEmpty) return; // Không có điểm hợp lệ

    // Tính toán bounds
    _routeBounds = _createBounds(routeCoordinates);

    // Tạo Polyline
    final polyline = Polyline(
      polylineId: const PolylineId('workout_route'),
      points: routeCoordinates,
      color: Theme.of(context).colorScheme.primary, // Lấy màu từ theme
      width: 5,
    );

    setState(() {
      _polylines.add(polyline);
    });
  }

  /// Tính toán vùng hiển thị (bounds) để bản đồ tự zoom
  LatLngBounds _createBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(southwest: _defaultLocation, northeast: _defaultLocation);
    }
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;

    for (var point in points) {
      minLat = (point.latitude < minLat) ? point.latitude : minLat;
      maxLat = (point.latitude > maxLat) ? point.latitude : maxLat;
      minLng = (point.longitude < minLng) ? point.longitude : minLng;
      maxLng = (point.longitude > maxLng) ? point.longitude : maxLng;
    }

    // Xử lý trường hợp chỉ có 1 điểm
    if (points.length == 1) {
      const offset = 0.001; // Tạo vùng nhỏ xung quanh
      return LatLngBounds(
        southwest: LatLng(minLat - offset, minLng - offset),
        northeast: LatLng(maxLat + offset, maxLng + offset),
      );
    }

    // Thêm một khoảng đệm nhỏ để đường không bị sát viền
    double latPadding = (maxLat - minLat) * 0.1;
    double lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// Hàm được gọi sau khi bản đồ được tạo để zoom camera
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Đảm bảo bounds đã được tính toán trước khi zoom
    if (_routeBounds != null) {
      // Đợi một chút để map render ổn định rồi mới zoom
      Future.delayed(const Duration(milliseconds: 100), () {
         _mapController?.animateCamera(
           CameraUpdate.newLatLngBounds(_routeBounds!, 60.0), // Padding 60
         );
      });
    }
  }

  /// Hàm định dạng thời gian thành HH:MM:SS
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Widget xây dựng cột thông số
  Widget _buildStatColumn(String title, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Giúp cột co lại vừa đủ
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)), // Giảm cỡ chữ tiêu đề
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), // Giảm cỡ chữ giá trị
            if (unit.isNotEmpty) const SizedBox(width: 3),
            if (unit.isNotEmpty) Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 12)), // Giảm cỡ chữ đơn vị
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.session.data() as Map<String, dynamic>? ?? {}; // Lấy dữ liệu an toàn
    final startTime = (data['startTime'] as Timestamp? ?? Timestamp.now()).toDate(); // Xử lý null
    // Lấy và chuyển đổi routePoints an toàn
    final pointsData = data['routePoints'] as List<dynamic>? ?? [];
    final routeCoordinates = pointsData
        .whereType<GeoPoint>()
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Tính toán các giá trị hiển thị một cách an toàn
    final double distanceMeters = (data['distanceInMeters'] as num? ?? 0.0).toDouble();
    final int durationSeconds = (data['durationInSeconds'] as num? ?? 0).toInt();
    final int calories = (data['caloriesBurned'] as num? ?? 0).toInt();

    final double distanceKm = distanceMeters / 1000.0;
    final double durationHours = durationSeconds / 3600.0;
    final double avgSpeedKmh = (durationHours > 0 && distanceKm > 0) ? distanceKm / durationHours : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(data['activityType'] ?? 'Chi tiết buổi tập'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // TODO: Thêm logic xác nhận và xóa buổi tập khỏi Firestore
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng xóa sẽ được thêm sau!')),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Phần bản đồ
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45, // Tăng chiều cao bản đồ một chút
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: routeCoordinates.isNotEmpty ? routeCoordinates.first : _defaultLocation,
                zoom: 14, // Giảm zoom ban đầu để thấy rộng hơn
              ),
              polylines: _polylines,
              onMapCreated: _onMapCreated, // Gọi hàm zoom khi map tạo xong
              myLocationButtonEnabled: false, // Tắt các nút mặc định
              zoomControlsEnabled: false,
            ),
          ),
          // Phần thông tin chi tiết
          Expanded(
            child: Container( // Thêm Container để có thể trang trí nền nếu muốn
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column( // Sử dụng Column thay vì ListView để dễ căn chỉnh
                children: [
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy lúc HH:mm', 'vi_VN').format(startTime),
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const Spacer(flex: 1), // Dùng Spacer để đẩy thông số ra xa
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('Tốc độ TB', avgSpeedKmh.toStringAsFixed(1), 'km/h'),
                        _buildStatColumn('Quãng đường', distanceKm.toStringAsFixed(2), 'km'),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         _buildStatColumn('Thời gian', _formatDuration(durationSeconds), ''),
                         _buildStatColumn('Calo', '$calories', 'kcal'),
                      ],
                    ),
                  ),
                   const Spacer(flex: 2), // Thêm khoảng trống ở dưới
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}