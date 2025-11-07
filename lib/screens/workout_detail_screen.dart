import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gym_now/models/workout_model.dart';
import 'package:gym_now/services/database_service.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot session; // Nhận toàn bộ document của buổi tập

  const WorkoutDetailScreen({Key? key, required this.session})
    : super(key: key);

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController; // Không cần 'late'
  final LatLng _defaultLocation = const LatLng(
    10.762622,
    106.660172,
  ); // Vị trí Hà Nội nếu cần
  bool _isPolylineCreated = false;
  LatLngBounds? _routeBounds; // Lưu bounds để zoom
  List<RouteSegment>? _routeSegments; // Lưu thông tin vận tốc các cung đường

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

    // Lấy thông tin vận tốc các cung đường
    final segmentsData = data['routeSegments'] as List<dynamic>? ?? [];
    if (segmentsData.isNotEmpty) {
      _routeSegments = segmentsData
          .map((s) => RouteSegment.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    // Tính toán bounds
    _routeBounds = _createBounds(routeCoordinates);

    // Tạo Polyline với màu sắc dựa trên vận tốc (nếu có dữ liệu vận tốc)
    if (_routeSegments != null && _routeSegments!.isNotEmpty) {
      // Tạo nhiều polyline với màu khác nhau dựa trên vận tốc
      _createColoredPolylines(routeCoordinates);
    } else {
      // Tạo polyline đơn giản nếu không có dữ liệu vận tốc
      final polyline = Polyline(
        polylineId: const PolylineId('workout_route'),
        points: routeCoordinates,
        color: Theme.of(context).colorScheme.primary,
        width: 5,
      );
      setState(() {
        _polylines.add(polyline);
      });
    }
  }

  /// Tạo các polyline với màu sắc khác nhau dựa trên vận tốc
  void _createColoredPolylines(List<LatLng> routeCoordinates) {
    if (_routeSegments == null || _routeSegments!.isEmpty) return;

    // Tìm vận tốc min và max để tính toán màu sắc
    double minSpeed = _routeSegments!
        .map((s) => s.speedKmh)
        .reduce((a, b) => a < b ? a : b);
    double maxSpeed = _routeSegments!
        .map((s) => s.speedKmh)
        .reduce((a, b) => a > b ? a : b);
    double speedRange = maxSpeed - minSpeed;
    if (speedRange == 0) speedRange = 1; // Tránh chia cho 0

    // Tạo polyline cho mỗi cung đường
    for (
      int i = 0;
      i < _routeSegments!.length && i + 1 < routeCoordinates.length;
      i++
    ) {
      final segment = _routeSegments![i];
      final startPoint = routeCoordinates[segment.index];
      final endPoint = routeCoordinates[segment.index + 1];

      // Tính màu dựa trên vận tốc (xanh = chậm, đỏ = nhanh)
      final normalizedSpeed = (segment.speedKmh - minSpeed) / speedRange;
      final color =
          Color.lerp(Colors.blue, Colors.red, normalizedSpeed) ?? Colors.blue;

      final polyline = Polyline(
        polylineId: PolylineId('segment_$i'),
        points: [startPoint, endPoint],
        color: color,
        width: 5,
      );

      setState(() {
        _polylines.add(polyline);
      });
    }
  }

  /// Tính toán vùng hiển thị (bounds) để bản đồ tự zoom
  LatLngBounds _createBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: _defaultLocation,
        northeast: _defaultLocation,
      );
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
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ), // Giảm cỡ chữ tiêu đề
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ), // Giảm cỡ chữ giá trị
            if (unit.isNotEmpty) const SizedBox(width: 3),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ), // Giảm cỡ chữ đơn vị
          ],
        ),
      ],
    );
  }

  /// Hiển thị thông báo iOS style
  void _showIOSNotification(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(isError ? 'Lỗi' : 'Thành công'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị chỉ báo vận tốc bằng màu sắc
  Widget _buildSpeedIndicator(double speedKmh) {
    Color color;
    if (speedKmh < 5) {
      color = Colors.blue; // Chậm
    } else if (speedKmh < 15) {
      color = Colors.green; // Trung bình
    } else if (speedKmh < 25) {
      color = Colors.orange; // Nhanh
    } else {
      color = Colors.red; // Rất nhanh
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          speedKmh.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data =
        widget.session.data() as Map<String, dynamic>? ??
        {}; // Lấy dữ liệu an toàn
    final startTime = (data['startTime'] as Timestamp? ?? Timestamp.now())
        .toDate(); // Xử lý null
    // Lấy và chuyển đổi routePoints an toàn
    final pointsData = data['routePoints'] as List<dynamic>? ?? [];
    final routeCoordinates = pointsData
        .whereType<GeoPoint>()
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Tính toán các giá trị hiển thị một cách an toàn
    final double distanceMeters = (data['distanceInMeters'] as num? ?? 0.0)
        .toDouble();
    final int durationSeconds = (data['durationInSeconds'] as num? ?? 0)
        .toInt();
    final int calories = (data['caloriesBurned'] as num? ?? 0).toInt();

    final double distanceKm = distanceMeters / 1000.0;
    final double durationHours = durationSeconds / 3600.0;
    final double avgSpeedKmh = (durationHours > 0 && distanceKm > 0)
        ? distanceKm / durationHours
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(data['activityType'] ?? 'Chi tiết buổi tập'),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            child: const Icon(
              Icons.delete,
              color: CupertinoColors.destructiveRed,
            ),
            onPressed: () async {
              // Hiển thị dialog xác nhận xóa (iOS style)
              final confirm = await showCupertinoDialog<bool>(
                context: context,
                builder: (BuildContext context) => CupertinoAlertDialog(
                  title: const Text('Xác nhận xóa'),
                  content: const Text(
                    'Bạn có chắc chắn muốn xóa buổi tập luyện này không?',
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('Hủy'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text('Xóa'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final sessionId = widget.session.id;
                    await DatabaseService(
                      uid: user.uid,
                    ).deleteWorkoutSession(sessionId);
                    if (mounted) {
                      Navigator.of(context).pop(); // Quay lại màn hình trước
                      _showIOSNotification(
                        context,
                        'Đã xóa buổi tập luyện thành công',
                        isError: false,
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    _showIOSNotification(
                      context,
                      'Lỗi khi xóa: $e',
                      isError: true,
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Phần bản đồ
          SizedBox(
            height:
                MediaQuery.of(context).size.height *
                0.45, // Tăng chiều cao bản đồ một chút
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: routeCoordinates.isNotEmpty
                    ? routeCoordinates.first
                    : _defaultLocation,
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
            child: Container(
              // Thêm Container để có thể trang trí nền nếu muốn
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                // Sử dụng Column thay vì ListView để dễ căn chỉnh
                children: [
                  Text(
                    DateFormat(
                      'EEEE, dd MMMM yyyy lúc HH:mm',
                      'vi_VN',
                    ).format(startTime),
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const Spacer(flex: 1), // Dùng Spacer để đẩy thông số ra xa
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn(
                          'Tốc độ TB',
                          avgSpeedKmh.toStringAsFixed(1),
                          'km/h',
                        ),
                        _buildStatColumn(
                          'Quãng đường',
                          distanceKm.toStringAsFixed(2),
                          'km',
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn(
                          'Thời gian',
                          _formatDuration(durationSeconds),
                          '',
                        ),
                        _buildStatColumn('Calo', '$calories', 'kcal'),
                      ],
                    ),
                  ),
                  // Hiển thị thông tin vận tốc theo cung đường nếu có
                  if (_routeSegments != null && _routeSegments!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Vận tốc theo cung đường',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _routeSegments!.length,
                        itemBuilder: (context, index) {
                          final segment = _routeSegments![index];
                          return Card(
                            color: const Color(0xFF1B263B),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                'Cung đường ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vận tốc: ${segment.speedKmh.toStringAsFixed(1)} km/h',
                                  ),
                                  Text(
                                    'Khoảng cách: ${(segment.distanceMeters / 1000).toStringAsFixed(2)} km',
                                  ),
                                  Text(
                                    'Thời gian: ${segment.durationSeconds}s',
                                  ),
                                ],
                              ),
                              trailing: _buildSpeedIndicator(segment.speedKmh),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const Spacer(
                      flex: 2,
                    ), // Thêm khoảng trống ở dưới nếu không có dữ liệu vận tốc
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
