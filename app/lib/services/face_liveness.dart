import 'dart:math';

import 'package:flutter/widgets.dart';

import '../core/config.dart';

/// Hành động trong thử thách xác thực khuôn mặt (liveness).
enum FaceAction {
  smile('Cười', 'Hãy cười tươi'),
  turnLeft('Quay đầu sang trái', 'Hãy quay đầu sang bên TRÁI của bạn'),
  turnRight('Quay đầu sang phải', 'Hãy quay đầu sang bên PHẢI của bạn');

  final String label;
  final String instruction;

  const FaceAction(this.label, this.instruction);
}

/// Một lần quan sát từ camera: số khuôn mặt thấy được, góc quay đầu (độ) và xác suất cười.
class FaceObservation {
  final int faceCount;

  /// headEulerAngleY của ML Kit (độ). Với ảnh camera trước (không lật gương), dương = người dùng quay sang TRÁI của họ.
  final double? yaw;
  final double? smile;

  const FaceObservation({required this.faceCount, this.yaw, this.smile});

  static const none = FaceObservation(faceCount: 0);
}

enum LivenessPhase { neutral, challenge, success, failed }

/// Ảnh chụp trạng thái của thử thách, để UI vẽ.
class LivenessState {
  final LivenessPhase phase;

  /// 2 hành động của lần thử thách này (thứ tự ngẫu nhiên).
  final List<FaceAction> challenges;

  /// Số hành động đã xong (0..2). Khi phase = neutral thì là 0.
  final int completed;

  /// Lời nhắc hiện cho người dùng (tiếng Việt).
  final String hint;

  /// Còn bao nhiêu giây cho bước hiện tại (null khi đã xong/thất bại).
  final int? secondsLeft;

  /// Đã thấy mặt ở trạng thái bình thường chưa (bước 1 của thử thách).
  final bool neutralDone;

  final String? failureReason;

  /// Trạng thái khuôn mặt hiện tại có hợp lệ không (đúng 1 mặt) - để tô khung xanh/đỏ.
  final bool faceOk;

  const LivenessState({
    required this.phase,
    required this.challenges,
    required this.completed,
    required this.hint,
    required this.neutralDone,
    required this.faceOk,
    this.secondsLeft,
    this.failureReason,
  });

  FaceAction? get current => (phase == LivenessPhase.challenge && completed < challenges.length) ? challenges[completed] : null;

  /// Tiến trình 0..1 gồm bước "nhìn thẳng" + từng hành động.
  double get progress {
    final total = challenges.length + 1;
    final done = (neutralDone ? 1 : 0) + completed;
    return phase == LivenessPhase.success ? 1 : done / total;
  }
}

/// Máy trạng thái của thử thách khuôn mặt, tách khỏi camera/ML Kit để test được:
/// 1) phải thấy MỘT khuôn mặt ở trạng thái bình thường (nhìn thẳng, không cười) vài khung hình liên tiếp
///    - ảnh tĩnh không thể làm hành động sau đó;
/// 2) rồi lần lượt 2 hành động ngẫu nhiên trong {cười, quay trái, quay phải}, mỗi hành động tối đa [challengeTimeout].
class LivenessEngine {
  final Random _random;
  final Duration neutralTimeout;
  final Duration challengeTimeout;
  final double yawThreshold;
  final double smileThreshold;
  final double neutralYawMax;
  final double neutralSmileMax;
  final int neutralFrames;
  final int holdFrames;
  final bool leftIsPositiveYaw;

  late List<FaceAction> challenges;
  LivenessPhase _phase = LivenessPhase.neutral;
  int _completed = 0;
  int _neutralStreak = 0;
  int _holdStreak = 0;
  bool _neutralDone = false;
  late DateTime _deadline;
  String _hint = 'Đưa khuôn mặt vào khung hình';
  bool _faceOk = false;
  String? _failure;

  LivenessEngine({
    Random? random,
    this.neutralTimeout = const Duration(seconds: 15),
    this.challengeTimeout = const Duration(seconds: 10),
    this.yawThreshold = 20,
    this.smileThreshold = 0.7,
    this.neutralYawMax = 12,
    this.neutralSmileMax = 0.3,
    this.neutralFrames = 4,
    this.holdFrames = 2,
    bool? leftIsPositiveYaw,
  })  : _random = random ?? Random.secure(),
        leftIsPositiveYaw = leftIsPositiveYaw ?? AppConfig.faceLeftIsPositiveYaw;

  /// Chọn 2 trong 3 hành động theo thứ tự ngẫu nhiên và bắt đầu đếm giờ.
  void start(DateTime now) {
    challenges = (List<FaceAction>.of(FaceAction.values)..shuffle(_random)).take(2).toList();
    _phase = LivenessPhase.neutral;
    _completed = 0;
    _neutralStreak = 0;
    _holdStreak = 0;
    _neutralDone = false;
    _faceOk = false;
    _failure = null;
    _hint = 'Đưa khuôn mặt vào khung hình';
    _deadline = now.add(neutralTimeout);
  }

  LivenessState get state => _snapshot(_lastNow);
  DateTime _lastNow = DateTime.now();

  /// Gọi định kỳ (kể cả khi không có khung hình) để phát hiện hết giờ.
  LivenessState tick(DateTime now) {
    _lastNow = now;
    _checkTimeout(now);
    return _snapshot(now);
  }

  LivenessState update(FaceObservation obs, DateTime now) {
    _lastNow = now;
    if (_phase == LivenessPhase.success || _phase == LivenessPhase.failed) return _snapshot(now);
    if (_checkTimeout(now)) return _snapshot(now);

    // Phải đúng 1 khuôn mặt
    if (obs.faceCount == 0) {
      _faceOk = false;
      _neutralStreak = 0;
      _holdStreak = 0;
      _hint = 'Không thấy khuôn mặt. Hãy đưa mặt vào khung hình';
      return _snapshot(now);
    }
    if (obs.faceCount > 1) {
      _faceOk = false;
      _neutralStreak = 0;
      _holdStreak = 0;
      _hint = 'Có nhiều hơn một khuôn mặt. Chỉ một người trong khung hình';
      return _snapshot(now);
    }
    _faceOk = true;
    final yaw = obs.yaw ?? 0;
    final smile = obs.smile ?? 0;

    if (_phase == LivenessPhase.neutral) {
      if (yaw.abs() > neutralYawMax) {
        _neutralStreak = 0;
        _hint = 'Hãy nhìn thẳng vào camera';
      } else if (smile >= neutralSmileMax) {
        _neutralStreak = 0;
        _hint = 'Giữ mặt bình thường, chưa cần cười';
      } else {
        _neutralStreak++;
        _hint = 'Giữ yên, nhìn thẳng...';
        if (_neutralStreak >= neutralFrames) {
          _neutralDone = true;
          _phase = LivenessPhase.challenge;
          _holdStreak = 0;
          _deadline = now.add(challengeTimeout);
          _hint = challenges[0].instruction;
        }
      }
      return _snapshot(now);
    }

    // Thử thách
    final action = challenges[_completed];
    if (_satisfied(action, yaw, smile)) {
      _holdStreak++;
      if (_holdStreak >= holdFrames) {
        _completed++;
        _holdStreak = 0;
        if (_completed >= challenges.length) {
          _phase = LivenessPhase.success;
          _hint = 'Xác thực khuôn mặt thành công';
        } else {
          _deadline = now.add(challengeTimeout);
          _hint = 'Tốt! ${challenges[_completed].instruction}';
        }
      }
    } else {
      _holdStreak = 0;
      _hint = action.instruction;
    }
    return _snapshot(now);
  }

  bool _satisfied(FaceAction action, double yaw, double smile) {
    switch (action) {
      case FaceAction.smile:
        return smile >= smileThreshold;
      case FaceAction.turnLeft:
        return (leftIsPositiveYaw ? yaw : -yaw) >= yawThreshold;
      case FaceAction.turnRight:
        return (leftIsPositiveYaw ? -yaw : yaw) >= yawThreshold;
    }
  }

  bool _checkTimeout(DateTime now) {
    if (_phase == LivenessPhase.success || _phase == LivenessPhase.failed) return false;
    if (now.isBefore(_deadline)) return false;
    _phase = LivenessPhase.failed;
    _failure = !_neutralDone
        ? 'Không nhận diện được khuôn mặt bình thường trong thời gian cho phép.'
        : 'Hết thời gian: chưa thực hiện đúng "${challenges[_completed].label}".';
    _hint = _failure!;
    return true;
  }

  LivenessState _snapshot(DateTime now) {
    final running = _phase == LivenessPhase.neutral || _phase == LivenessPhase.challenge;
    return LivenessState(
      phase: _phase,
      challenges: challenges,
      completed: _completed,
      hint: _hint,
      neutralDone: _neutralDone,
      faceOk: _faceOk,
      secondsLeft: running ? max(0, _deadline.difference(now).inSeconds + 1) : null,
      failureReason: _failure,
    );
  }
}

/// Hàm dựng khung xác thực khuôn mặt (camera trước + ML Kit). Tách ra để test thay bằng khung giả
/// (camera/ML Kit chỉ chạy trên thiết bị). [onVerified] được gọi khi qua thử thách. Lỗi camera,
/// hết giờ... do chính khung này hiển thị kèm nút Thử lại.
typedef FaceLivenessBuilder = Widget Function(BuildContext context, {required VoidCallback onVerified});
