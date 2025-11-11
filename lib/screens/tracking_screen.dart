import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gym_now/models/workout_goal_model.dart';
import 'package:gym_now/models/workout_model.dart';
import 'package:gym_now/models/workout_type_model.dart';
import 'package:gym_now/screens/goal_setting_screen.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:gym_now/services/notification_service.dart';
import 'package:uuid/uuid.dart';

// Class để lưu thông tin điểm GPS với timestamp
class RoutePointWithTime {
  final LatLng point;
  final DateTime timestamp;

  RoutePointWithTime({required this.point, required this.timestamp});
}

class TrackingScreen extends StatefulWidget {
  final WorkoutType activityType;
  const TrackingScreen({Key? key, required this.activityType})
    : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  // === BIẾN TRẠNG THÁI ===
  bool _isStarted = false;
  WorkoutGoal _workoutGoal = WorkoutGoal();
  bool _isTracking = false; // True khi đang chạy (không bị tạm dừng)
  Timer? _timer;
  int _durationInSeconds = 0;
  double _totalDistance = 0.0;
  double _caloriesBurned = 0.0;
  double _userWeight = 70.0;
  GoogleMapController? _mapController;
  final List<LatLng> _routePoints = [];
  final List<RoutePointWithTime> _routePointsWithTime =
      []; // Lưu điểm với timestamp để tính vận tốc
  final Set<Polyline> _polylines = {};
  // Biến để lọc GPS nhiễu
  static const double _maxDistancePerUpdate =
      100.0; // Tối đa 100m giữa 2 điểm (tránh GPS nhảy)
  static const double _minDistanceForUpdate =
      5.0; // Tối thiểu 5m mới cập nhật (tối ưu hiệu năng)
  StreamSubscription<Position>? _positionStreamSubscription;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(10.762622, 106.660172),
    zoom: 15,
  );
  String _weatherInfo = "Đang tải...";
  IconData _weatherIcon = Icons.cloud_queue;

  @override
  void initState() {
    super.initState();
    _fetchUserWeight();
    _getCurrentLocationAndWeather();
  }

  // --- CÁC HÀM XỬ LÝ LOGIC ---

  /// Điều hướng đến màn hình đặt mục tiêu
  Future<void> _navigateToGoalScreen() async {
    final result = await Navigator.push<WorkoutGoal>(
      context,
      MaterialPageRoute(builder: (context) => const GoalSettingScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _workoutGoal = result;
      });
    }
  }

  /// Lấy vị trí ban đầu và thông tin thời tiết
  Future<void> _getCurrentLocationAndWeather() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Di chuyển camera đến vị trí hiện tại nếu map đã sẵn sàng
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
      await _fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      print("Lỗi khi lấy vị trí và thời tiết: $e");
      if (mounted) {
        setState(() => _weatherInfo = "Không thể lấy vị trí");
      }
    }
  }

  /// Lấy thông tin thời tiết từ API OpenWeatherMap
  Future<void> _fetchWeather(double lat, double lon) async {
    const apiKey =
        'ba3e4e211e1b86198cfd0d785843da62'; // Thay KEY của bạn vào đây
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=vi',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          final temp = data['main']['temp'].round();
          final description = data['weather'][0]['description'];
          _weatherInfo = '$temp°C, $description';
          _weatherIcon = _getWeatherIcon(data['weather'][0]['main']);
        });
      } else if (mounted) {
        setState(() => _weatherInfo = 'Lỗi tải dữ liệu');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _weatherInfo = 'Lỗi kết nối');
      }
    }
  }

  /// Lấy cân nặng của người dùng từ Firestore
  Future<void> _fetchUserWeight() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await DatabaseService(uid: user.uid).getUserData();
      if (userData.exists && mounted) {
        final weight = (userData.data() as Map<String, dynamic>)['weight'];
        if (weight != null && weight > 0) {
          setState(() {
            _userWeight = weight.toDouble();
          });
        } else {
          print(
            "Cảnh báo: Cân nặng người dùng không hợp lệ hoặc bằng 0. Sử dụng giá trị mặc định.",
          );
        }
      }
    }
  }

  /// Bắt đầu toàn bộ buổi tập (sau khi nhấn GO)
  void _beginWorkout() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Đảm bảo cân nặng hợp lệ
    if (_userWeight <= 0) {
      _showIOSNotification(
        context,
        'Lỗi: Cân nặng không hợp lệ. Vui lòng cập nhật hồ sơ.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isStarted = true; // Chuyển sang giao diện đang chạy
      _isTracking = true; // Bắt đầu ở trạng thái đang chạy (không tạm dừng)
      // Reset dữ liệu buổi tập cũ
      _routePoints.clear();
      _routePointsWithTime.clear();
      _polylines.clear();
      _totalDistance = 0.0;
      _durationInSeconds = 0;
      _caloriesBurned = 0.0;
    });
    _startTimer(); // Bắt đầu bộ đếm giờ
    _listenToGPS(); // Bắt đầu nghe GPS
  }

  /// Bắt đầu hoặc khởi động lại bộ đếm giờ (khi bắt đầu hoặc tiếp tục)
  void _startTimer() {
    _timer?.cancel(); // Luôn hủy timer cũ trước khi tạo mới
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isTracking) return; // Không làm gì nếu đang tạm dừng

      _durationInSeconds++;
      // Tính calo dựa trên cân nặng và MET
      final caloriesPerMinute =
          (widget.activityType.metValue * 3.5 * _userWeight) / 200;
      setState(() {
        _caloriesBurned = caloriesPerMinute * (_durationInSeconds / 60);
      });

      // Kiểm tra xem đã đạt mục tiêu chưa
      bool goalReached = false;
      String goalTypeText = '';
      String goalValueText = '';
      Map<String, dynamic> goalDetails = {};

      if (_workoutGoal.type == GoalType.distance &&
          _totalDistance >= _workoutGoal.value) {
        goalReached = true;
        goalTypeText = 'Khoảng cách';
        goalValueText = '${(_totalDistance / 1000).toStringAsFixed(2)} km';
        goalDetails = {
          'Mục tiêu': '${(_workoutGoal.value / 1000).toStringAsFixed(2)} km',
          'Đạt được': goalValueText,
        };
      } else if (_workoutGoal.type == GoalType.time &&
          _durationInSeconds >= _workoutGoal.value) {
        goalReached = true;
        goalTypeText = 'Thời gian';
        goalValueText = _formatDuration(_durationInSeconds);
        goalDetails = {
          'Mục tiêu': _formatDuration(_workoutGoal.value.toInt()),
          'Đạt được': goalValueText,
        };
      } else if (_workoutGoal.type == GoalType.calories &&
          _caloriesBurned >= _workoutGoal.value) {
        goalReached = true;
        goalTypeText = 'Calo';
        goalValueText = '${_caloriesBurned.toStringAsFixed(0)} kcal';
        goalDetails = {
          'Mục tiêu': '${_workoutGoal.value.toInt()} kcal',
          'Đạt được': goalValueText,
        };
      }

      if (goalReached) {
        // Gửi thông báo hoàn thành mục tiêu
        NotificationService().showGoalCompletedNotification(
          title: '🎉 Chúc mừng! Bạn đã hoàn thành mục tiêu!',
          body: 'Mục tiêu $goalTypeText đã được hoàn thành thành công!',
          goalDetails: goalDetails,
        );
        _stopWorkout(); // Tự động dừng nếu đạt mục tiêu
      }
    });
  }

  /// Lọc và làm mịn điểm GPS để loại bỏ nhiễu
  List<LatLng> _filterAndSmoothRoutePoints(List<LatLng> points) {
    if (points.length < 3) return points; // Cần ít nhất 3 điểm để làm mịn

    final List<LatLng> filtered = [points.first]; // Luôn giữ điểm đầu

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1]; // Sử dụng điểm gốc, không phải điểm đã lọc
      final curr = points[i];
      final next = points[i + 1];

      // Tính khoảng cách từ điểm trước (trong danh sách gốc)
      final distanceFromPrev = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      // Bỏ qua điểm nếu quá xa (GPS nhiễu)
      if (distanceFromPrev > _maxDistancePerUpdate) {
        continue;
      }

      // Bỏ qua điểm nếu quá gần (tối ưu hiệu năng) - chỉ áp dụng sau điểm đầu tiên
      if (distanceFromPrev < _minDistanceForUpdate && i > 1) {
        continue;
      }

      // Làm mịn bằng cách lấy trung bình của 3 điểm liên tiếp (moving average)
      final smoothedLat = (prev.latitude + curr.latitude + next.latitude) / 3;
      final smoothedLng =
          (prev.longitude + curr.longitude + next.longitude) / 3;

      filtered.add(LatLng(smoothedLat, smoothedLng));
    }

    // Luôn giữ điểm cuối
    if (points.length > 1) {
      filtered.add(points.last);
    }

    return filtered;
  }

  /// Bắt đầu lắng nghe tín hiệu GPS với bộ lọc cải tiến
  void _listenToGPS() {
    _positionStreamSubscription?.cancel(); // Hủy stream cũ nếu có
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Giảm xuống 5m để có độ chính xác cao hơn
          ),
        ).listen((Position position) {
          if (!_isTracking || !mounted)
            return; // Bỏ qua nếu đang tạm dừng hoặc widget đã bị hủy

          setState(() {
            final newPoint = LatLng(position.latitude, position.longitude);
            final currentTime = DateTime.now();

            if (_routePoints.isNotEmpty) {
              // Tính khoảng cách từ điểm cuối cùng
              final segmentDistance = Geolocator.distanceBetween(
                _routePoints.last.latitude,
                _routePoints.last.longitude,
                newPoint.latitude,
                newPoint.longitude,
              );

              // Bỏ qua điểm nếu quá xa (GPS nhiễu - có thể do tín hiệu yếu)
              if (segmentDistance > _maxDistancePerUpdate) {
                print(
                  '⚠️ Bỏ qua điểm GPS nhiễu: khoảng cách = ${segmentDistance.toStringAsFixed(1)}m',
                );
                return;
              }

              // Chỉ cập nhật nếu di chuyển đủ xa (tối ưu hiệu năng)
              if (segmentDistance < _minDistanceForUpdate &&
                  _routePoints.length > 1) {
                return;
              }

              _totalDistance += segmentDistance;
            }

            _routePoints.add(newPoint); // Thêm điểm mới vào danh sách
            _routePointsWithTime.add(
              RoutePointWithTime(point: newPoint, timestamp: currentTime),
            ); // Lưu với timestamp

            // Làm mịn và cập nhật đường vẽ trên bản đồ
            final smoothedPoints = _filterAndSmoothRoutePoints(_routePoints);

            _polylines.clear();
            if (smoothedPoints.length >= 2) {
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: smoothedPoints,
                  color: Theme.of(context).colorScheme.primary,
                  width: 5,
                  patterns: [], // Đường liền nét
                  jointType: JointType.round, // Làm mượt các góc
                ),
              );
            }

            // Di chuyển camera theo vị trí mới (chỉ khi có đủ điểm)
            if (_routePoints.length > 1) {
              _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
            }
          });
        });
  }

  /// Chuyển đổi trạng thái Tạm dừng / Tiếp tục
  void _togglePauseResume() {
    if (_isTracking) {
      // Đang chạy -> Tạm dừng
      setState(() => _isTracking = false);
      _timer?.cancel(); // Dừng timer
      _positionStreamSubscription?.pause(); // Tạm dừng nghe GPS
    } else {
      // Đang dừng -> Tiếp tục
      setState(() => _isTracking = true);
      _startTimer(); // Khởi động lại timer
      _positionStreamSubscription?.resume(); // Tiếp tục nghe GPS
    }
  }

  /// Kết thúc hoàn toàn buổi tập (nhấn nút Stop)
  void _stopWorkout() {
    // Dừng timer và GPS listener dứt điểm
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null; // Đặt lại để có thể nghe lại lần sau

    setState(() {
      _isStarted =
          false; // Có thể quay lại màn hình PreStart nếu muốn, hoặc đóng màn hình
      _isTracking = false; // Đảm bảo trạng thái là không tracking
    });

    if (_durationInSeconds > 5) {
      // Chỉ lưu nếu tập đủ lâu
      // Tính lại calo dựa trên tốc độ trung bình
      final double avgSpeedKmh = (_durationInSeconds > 0)
          ? (_totalDistance / _durationInSeconds) * 3.6
          : 0.0;
      final double adjustedMET = _getAdjustedMET(avgSpeedKmh);
      final double recalculatedCalories = (_userWeight > 0)
          ? (adjustedMET * 3.5 * _userWeight) / 200 * (_durationInSeconds / 60)
          : 0.0;
      _showSaveDialog(recalculatedCalories.round());
    } else {
      Navigator.of(context).pop(); // Nếu tập quá ngắn, chỉ cần quay về
    }
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
        title: Text(isError ? 'Lỗi' : 'Thông báo'),
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

  /// Hiển thị hộp thoại lưu (iOS style)
  void _showSaveDialog(int finalCalories) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false, // Không cho đóng bằng cách chạm bên ngoài
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Hoàn thành'),
        content: Text(
          'Thời gian: ${_formatDuration(_durationInSeconds)}\n'
          'Quãng đường: ${(_totalDistance / 1000).toStringAsFixed(2)} km\n'
          'Calo ước tính: $finalCalories kcal\n\n'
          'Bạn có muốn lưu lại kết quả không?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Bỏ qua'),
            onPressed: () {
              Navigator.of(context).pop(); // Đóng dialog
              Navigator.of(context).pop(); // Đóng màn hình tracking
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Lưu'),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              var uuid = const Uuid();
              final routeGeoPoints = _routePoints
                  .map((p) => GeoPoint(p.latitude, p.longitude))
                  .toList();

              // Tính toán vận tốc cho mỗi cung đường
              final List<RouteSegment> routeSegments = [];
              for (int i = 1; i < _routePointsWithTime.length; i++) {
                final prevPoint = _routePointsWithTime[i - 1];
                final currPoint = _routePointsWithTime[i];

                // Tính khoảng cách giữa 2 điểm (mét)
                final distanceMeters = Geolocator.distanceBetween(
                  prevPoint.point.latitude,
                  prevPoint.point.longitude,
                  currPoint.point.latitude,
                  currPoint.point.longitude,
                );

                // Tính thời gian di chuyển (giây)
                final durationSeconds = currPoint.timestamp
                    .difference(prevPoint.timestamp)
                    .inSeconds;

                // Tính vận tốc (km/h): nếu durationSeconds = 0 thì vận tốc = 0
                double speedKmh = 0.0;
                if (durationSeconds > 0) {
                  // Vận tốc = (khoảng cách / thời gian) * 3.6 để chuyển từ m/s sang km/h
                  speedKmh = (distanceMeters / durationSeconds) * 3.6;
                }

                routeSegments.add(
                  RouteSegment(
                    index: i - 1, // Index của điểm bắt đầu cung đường
                    speedKmh: speedKmh,
                    distanceMeters: distanceMeters,
                    durationSeconds: durationSeconds,
                  ),
                );
              }

              final session = WorkoutSession(
                id: uuid.v4(),
                activityType: widget.activityType.name,
                startTime: DateTime.now().subtract(
                  Duration(seconds: _durationInSeconds),
                ),
                durationInSeconds: _durationInSeconds,
                distanceInMeters: _totalDistance,
                caloriesBurned: finalCalories,
                routePoints: routeGeoPoints,
                routeSegments: routeSegments.isNotEmpty ? routeSegments : null,
              );
              await DatabaseService(uid: user.uid).addWorkoutSession(session);
              Navigator.of(context).pop(); // Đóng dialog
              Navigator.of(context).pop(); // Đóng màn hình tracking
            },
          ),
        ],
      ),
    );
  }

  // --- CÁC HÀM BUILD GIAO DIỆN ---

  @override
  Widget build(BuildContext context) {
    return _isStarted ? _buildActiveUI() : _buildPreStartUI();
  }

  Widget _buildPreStartUI() {
    return Scaffold(
      appBar: AppBar(title: Text(widget.activityType.name)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              color: const Color(0xFF1B263B).withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_weatherIcon, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(_weatherInfo),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 80, left: 10, child: _buildGoalDisplay()),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'goal_btn',
                  onPressed: _navigateToGoalScreen,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.flag,
                    color: Theme.of(context).primaryColorDark,
                    size: 30,
                  ),
                ),
                FloatingActionButton.large(
                  heroTag: 'go_btn',
                  onPressed: _beginWorkout,
                  backgroundColor: Colors.redAccent,
                  child: const Text(
                    'GO',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FloatingActionButton(
                  heroTag: 'settings_btn',
                  onPressed: () {}, // Nút này hiện chưa có chức năng
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).primaryColorDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUI() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đang ${widget.activityType.name}'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          GoogleMap(
            // Không cần onMapCreated ở đây nữa nếu đã tạo ở PreStart
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: _polylines,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              color: const Color(0xFF1B263B).withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_weatherIcon, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Text(_weatherInfo),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.white24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(
                          'Thời gian',
                          _formatDuration(_durationInSeconds),
                        ),
                        _buildStatColumn(
                          'Quãng đường',
                          '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                        ),
                        _buildStatColumn(
                          'Calo',
                          '${_caloriesBurned.toStringAsFixed(0)} kcal',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.all(25),
                    ),
                    onPressed: _togglePauseResume, // Gọi hàm tạm dừng/tiếp tục
                    child: Icon(
                      _isTracking ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(25),
                    ),
                    onPressed: _stopWorkout, // Gọi hàm kết thúc
                    child: const Icon(
                      Icons.stop,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CÁC WIDGET & HÀM HỖ TRỢ KHÁC ---

  Widget _buildGoalDisplay() {
    if (_workoutGoal.type == GoalType.none) return const SizedBox.shrink();
    String text = '';
    switch (_workoutGoal.type) {
      case GoalType.distance:
        text = 'Mục tiêu: ${(_workoutGoal.value / 1000).toStringAsFixed(1)} km';
        break;
      case GoalType.time:
        text = 'Mục tiêu: ${_formatDuration(_workoutGoal.value.toInt())}';
        break;
      case GoalType.calories:
        text = 'Mục tiêu: ${_workoutGoal.value.toInt()} kcal';
        break;
      default:
        break;
    }
    return Chip(
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.black.withOpacity(0.7),
      avatar: Icon(Icons.flag, color: Theme.of(context).colorScheme.primary),
      padding: const EdgeInsets.all(8.0),
    );
  }

  Widget _buildStatColumn(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = seconds.remainder(60).toString().padLeft(2, '0');
    // Chỉ hiển thị giờ nếu lớn hơn 0
    return hours == '00' ? '$minutes:$secs' : '$hours:$minutes:$secs';
  }

  IconData _getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.umbrella; // Có thể dùng Icons.grain cho mưa nhỏ
      case 'clear':
        return Icons.wb_sunny;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'drizzle':
        return Icons.grain; // Mưa phùn
      case 'mist': // Sương mù
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        return Icons.cloud_queue; // Dùng icon mây cho các loại mù
      default:
        return Icons.cloud_queue;
    }
  }

  double _getAdjustedMET(double avgSpeedKmh) {
    if (avgSpeedKmh < 1.5) return 1.0;

    // Điều chỉnh MET cho Đi bộ
    if (widget.activityType.name == 'Đi bộ' ||
        (widget.activityType.name == 'Chạy bộ' && avgSpeedKmh < 5))
      return 3.5;

    // Điều chỉnh MET cho Đạp xe
    if (widget.activityType.name == 'Đạp xe' && avgSpeedKmh < 15) return 6.0;

    // Điều chỉnh MET cho Leo núi dựa trên tốc độ
    // Leo núi thường chậm hơn đi bộ bình thường do độ dốc
    // Tốc độ chậm (< 3 km/h) = leo núi khó (MET cao hơn)
    // Tốc độ trung bình (3-5 km/h) = leo núi nhẹ (MET trung bình)
    if (widget.activityType.name == 'Leo núi') {
      if (avgSpeedKmh < 3.0) {
        // Leo núi khó, tốc độ rất chậm -> MET cao hơn (10-12)
        return 10.0;
      } else if (avgSpeedKmh < 5.0) {
        // Leo núi trung bình -> MET 8-9
        return 8.5;
      } else {
        // Leo núi nhẹ hoặc đi xuống -> MET cơ bản
        return widget.activityType.metValue;
      }
    }

    // Mặc định trả về MET gốc
    return widget.activityType.metValue;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _timer?.cancel();
    _mapController?.dispose(); // Giải phóng controller của map
    super.dispose();
  }
}
