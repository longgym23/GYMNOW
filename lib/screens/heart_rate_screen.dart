import 'dart:async';
import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart';

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({Key? key}) : super(key: key);

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  // List to store measured heart rate values
  List<SensorValue> data = [];
  // Current heart rate value to display
  int bpmValue = 0;
  // Timer for the countdown
  Timer? _timer;
  // Countdown duration in seconds
  int _countdown = 45;
  // Flag to indicate if the measurement is active
  bool _isMeasuring = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Starts a 45-second countdown timer.
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        if (mounted) {
          setState(() {
            _countdown--;
          });
        }
      } else {
        // Stop the timer and measurement when countdown finishes
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _isMeasuring = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is removed
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đo Nhịp tim'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display BPM or measurement status
            Text(
              _isMeasuring
                  ? (bpmValue > 0 ? '$bpmValue BPM' : 'Đang đo...')
                  : (bpmValue > 0 ? 'Kết quả: $bpmValue BPM' : 'Không thể đo'),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Display the countdown timer
            Text(
              'Thời gian còn lại: $_countdown giây',
              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),

            // Conditionally display the camera widget
            _isMeasuring
                ? HeartBPMDialog(
                    context: context,
                    showTextValues: true,
                    cameraWidgetWidth: 200,
                    cameraWidgetHeight: 200,
                    onRawData: (value) {
                      // Raw data received (not used here)
                    },
                    onBPM: (value) {
                      // Update BPM value when a result is available
                      if (mounted) {
                        setState(() {
                          bpmValue = value;
                        });
                      }
                    },
                  )
                : Container( // Placeholder for when measurement is finished
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 80,
                      ),
                    ),
                  ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _isMeasuring
                    ? 'Vui lòng đặt nhẹ đầu ngón trỏ của bạn lên camera sau và đèn flash.'
                    : 'Đã hoàn tất quá trình đo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}