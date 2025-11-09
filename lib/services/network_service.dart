import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _connectionChecker =
      InternetConnectionChecker();

  StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetConnectionStatus>? _internetSubscription;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    // Kiểm tra trạng thái ban đầu
    await _checkConnection();

    // Lắng nghe thay đổi kết nối
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _checkConnection();
    });

    // Lắng nghe thay đổi trạng thái internet
    _internetSubscription = _connectionChecker.onStatusChange.listen((
      InternetConnectionStatus status,
    ) {
      _isConnected = status == InternetConnectionStatus.connected;
      _connectionStatusController.add(_isConnected);
    });
  }

  Future<void> _checkConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();

      // Kiểm tra xem có kết nối mạng nào không
      if (connectivityResults.contains(ConnectivityResult.none)) {
        _isConnected = false;
      } else {
        // Kiểm tra xem có thực sự kết nối internet không
        _isConnected = await _connectionChecker.hasConnection;
      }

      _connectionStatusController.add(_isConnected);
    } catch (e) {
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  Future<bool> checkInternetConnection() async {
    try {
      return await _connectionChecker.hasConnection;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _internetSubscription?.cancel();
    _connectionStatusController.close();
  }
}
