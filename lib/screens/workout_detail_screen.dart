import 'dart:ui' as ui;
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
  final Set<Marker> _markers = {};
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
      // Tạo markers cho mỗi cung đường
      _createSegmentMarkers(routeCoordinates);
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

  /// Tạo markers cho mỗi cung đường với số thứ tự và vận tốc
  Future<void> _createSegmentMarkers(List<LatLng> routeCoordinates) async {
    if (_routeSegments == null || _routeSegments!.isEmpty) return;

    final Set<Marker> markers = {};

    for (
      int i = 0;
      i < _routeSegments!.length && i + 1 < routeCoordinates.length;
      i++
    ) {
      final segment = _routeSegments![i];
      final startPoint = routeCoordinates[segment.index];
      final endPoint = routeCoordinates[segment.index + 1];

      // Tính điểm giữa của cung đường
      final midPoint = LatLng(
        (startPoint.latitude + endPoint.latitude) / 2,
        (startPoint.longitude + endPoint.longitude) / 2,
      );

      // Xác định màu dựa trên vận tốc
      Color markerColor;
      if (segment.speedKmh < 5) {
        markerColor = Colors.blue;
      } else if (segment.speedKmh < 15) {
        markerColor = Colors.green;
      } else if (segment.speedKmh < 25) {
        markerColor = Colors.orange;
      } else {
        markerColor = Colors.red;
      }

      // Tạo custom icon
      final icon = await _createCustomMarkerIcon(
        segmentNumber: i + 1,
        speed: segment.speedKmh,
        color: markerColor,
      );

      final marker = Marker(
        markerId: MarkerId('segment_marker_$i'),
        position: midPoint,
        icon: icon,
        infoWindow: InfoWindow(
          title: 'Cung đường ${i + 1}',
          snippet: 'Vận tốc: ${segment.speedKmh.toStringAsFixed(1)} km/h',
        ),
      );

      markers.add(marker);
    }

    setState(() {
      _markers.addAll(markers);
    });
  }

  /// Tạo custom marker icon với số và vận tốc
  Future<BitmapDescriptor> _createCustomMarkerIcon({
    required int segmentNumber,
    required double speed,
    required Color color,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 60.0;

    // Vẽ nền tròn với gradient
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size / 2),
        size / 2,
        [color, color.withOpacity(0.7)],
      );

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, paint);

    // Vẽ viền trắng
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Vẽ số thứ tự
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$segmentNumber',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2 - 8,
      ),
    );

    // Vẽ vận tốc (nhỏ hơn)
    final speedTextPainter = TextPainter(
      text: TextSpan(
        text: '${speed.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    speedTextPainter.layout();
    speedTextPainter.paint(
      canvas,
      Offset(
        (size - speedTextPainter.width) / 2,
        (size - speedTextPainter.height) / 2 + 8,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
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

  /// Widget xây dựng card thống kê hiện đại
  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.7)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          speedKmh.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            // Phần bản đồ
            Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: routeCoordinates.isNotEmpty
                        ? routeCoordinates.first
                        : _defaultLocation,
                    zoom: 14,
                  ),
                  polylines: _polylines,
                  markers: _markers,
                  onMapCreated: _onMapCreated,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
            // Phần thông tin chi tiết
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Phần thông tin tổng quan
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Ngày giờ
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B263B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.orange.shade400,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'EEEE, dd MMMM yyyy lúc HH:mm',
                                    'vi_VN',
                                  ).format(startTime),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Thống kê chính - Hàng 1
                          Row(
                            children: [
                              _buildStatCard(
                                title: 'Tốc độ TB',
                                value: avgSpeedKmh.toStringAsFixed(1),
                                unit: 'km/h',
                                icon: Icons.speed,
                                color: Colors.blue,
                              ),
                              _buildStatCard(
                                title: 'Quãng đường',
                                value: distanceKm.toStringAsFixed(2),
                                unit: 'km',
                                icon: Icons.route,
                                color: Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Thống kê chính - Hàng 2
                          Row(
                            children: [
                              _buildStatCard(
                                title: 'Thời gian',
                                value: _formatDuration(durationSeconds),
                                unit: '',
                                icon: Icons.timer,
                                color: Colors.purple,
                              ),
                              _buildStatCard(
                                title: 'Calo',
                                value: '$calories',
                                unit: 'kcal',
                                icon: Icons.local_fire_department,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Phần vận tốc theo cung đường
                    if (_routeSegments != null &&
                        _routeSegments!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.orange.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.timeline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Vận tốc theo cung đường',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ListView.builder trong Column - không dùng Expanded
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        itemCount: _routeSegments!.length,
                        itemBuilder: (context, index) {
                          final segment = _routeSegments![index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1B263B),
                                  const Color(0xFF1B263B).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Số thứ tự
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange.shade400,
                                          Colors.orange.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Thông tin chi tiết
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.speed,
                                              size: 16,
                                              color: Colors.blue.shade300,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${segment.speedKmh.toStringAsFixed(1)} km/h',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.straighten,
                                                    size: 14,
                                                    color: Colors.white
                                                        .withOpacity(0.6),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${(segment.distanceMeters / 1000).toStringAsFixed(2)} km',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.white
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.timer_outlined,
                                                  size: 14,
                                                  color: Colors.white
                                                      .withOpacity(0.6),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${segment.durationSeconds}s',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white
                                                        .withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Chỉ báo vận tốc
                                  _buildSpeedIndicator(segment.speedKmh),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20), // Padding cuối cùng
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
