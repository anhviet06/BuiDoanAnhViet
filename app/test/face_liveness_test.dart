import 'dart:math';

import 'package:buidoananhviet/services/face_liveness.dart';
import 'package:flutter_test/flutter_test.dart';

/// Giả lập luồng khung hình để kiểm tra máy trạng thái thử thách khuôn mặt (không cần camera).
class Sim {
  final LivenessEngine engine;
  DateTime now = DateTime(2026, 10, 29, 10);

  Sim(this.engine) {
    engine.start(now);
  }

  LivenessState frame(FaceObservation obs, {int times = 1, Duration step = const Duration(milliseconds: 100)}) {
    late LivenessState s;
    for (var i = 0; i < times; i++) {
      now = now.add(step);
      s = engine.update(obs, now);
    }
    return s;
  }

  LivenessState wait(Duration d) {
    now = now.add(d);
    return engine.tick(now);
  }

  static const neutral = FaceObservation(faceCount: 1, yaw: 0, smile: 0.05);
  static const smiling = FaceObservation(faceCount: 1, yaw: 0, smile: 0.95);
  static const left = FaceObservation(faceCount: 1, yaw: 30, smile: 0.05);
  static const right = FaceObservation(faceCount: 1, yaw: -30, smile: 0.05);

  /// Thực hiện đúng một hành động.
  LivenessState doAction(FaceAction a) => switch (a) {
        FaceAction.smile => frame(smiling, times: 3),
        FaceAction.turnLeft => frame(left, times: 3),
        FaceAction.turnRight => frame(right, times: 3),
      };
}

LivenessEngine engine({int seed = 1, bool leftPositive = true}) => LivenessEngine(random: Random(seed), leftIsPositiveYaw: leftPositive);

void main() {
  group('Chọn thử thách ngẫu nhiên', () {
    test('luôn 2 hành động khác nhau, lấy từ {cười, quay trái, quay phải}', () {
      for (var seed = 0; seed < 40; seed++) {
        final e = engine(seed: seed)..start(DateTime(2026));
        expect(e.challenges.length, 2);
        expect(e.challenges[0], isNot(e.challenges[1]));
        expect(FaceAction.values, containsAll(e.challenges));
      }
    });

    test('thứ tự thay đổi giữa các lần (đủ 6 tổ hợp có thứ tự xuất hiện)', () {
      final seen = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final e = engine(seed: seed)..start(DateTime(2026));
        seen.add(e.challenges.map((c) => c.name).join('>'));
      }
      expect(seen.length, 6);
    });

    test('mỗi lần start() chọn lại', () {
      final e = LivenessEngine(random: Random(7));
      final results = <String>{};
      for (var i = 0; i < 30; i++) {
        e.start(DateTime(2026));
        results.add(e.challenges.map((c) => c.name).join());
      }
      expect(results.length, greaterThan(1));
    });
  });

  group('Bước "mặt bình thường" (chống ảnh tĩnh)', () {
    test('chưa thấy mặt bình thường thì chưa có hành động nào được tính, dù làm hành động trước', () {
      final s = Sim(engine());
      // làm ngay một cú cười khi chưa qua bước bình thường: không tính
      var st = s.frame(Sim.smiling, times: 6);
      expect(st.phase, LivenessPhase.neutral);
      expect(st.completed, 0);
      expect(st.neutralDone, false);
      expect(st.hint, contains('bình thường'));
    });

    test('nhìn thẳng + không cười đủ số khung -> sang thử thách, nhắc hành động đầu tiên', () {
      final s = Sim(engine());
      var st = s.frame(Sim.neutral, times: 3);
      expect(st.phase, LivenessPhase.neutral);
      st = s.frame(Sim.neutral);
      expect(st.phase, LivenessPhase.challenge);
      expect(st.neutralDone, true);
      expect(st.hint, st.challenges.first.instruction);
      expect(st.progress, closeTo(1 / 3, 0.001));
    });

    test('đầu lệch (nhìn nghiêng) hoặc đang cười thì chuỗi "bình thường" bị đứt', () {
      final s = Sim(engine());
      s.frame(Sim.neutral, times: 3);
      var st = s.frame(const FaceObservation(faceCount: 1, yaw: 25, smile: 0.0));
      expect(st.hint, contains('nhìn thẳng'));
      st = s.frame(Sim.neutral, times: 3);
      expect(st.phase, LivenessPhase.neutral, reason: 'đếm lại từ đầu');
      st = s.frame(Sim.neutral);
      expect(st.phase, LivenessPhase.challenge);
    });
  });

  group('Số khuôn mặt', () {
    test('không có mặt -> nhắc đưa mặt vào, khung không xanh; nhiều mặt -> nhắc chỉ một người', () {
      final s = Sim(engine());
      var st = s.frame(FaceObservation.none);
      expect(st.hint, contains('Không thấy khuôn mặt'));
      expect(st.faceOk, false);
      st = s.frame(const FaceObservation(faceCount: 2, yaw: 0, smile: 0));
      expect(st.hint, contains('nhiều hơn một khuôn mặt'));
      expect(st.faceOk, false);
      st = s.frame(Sim.neutral);
      expect(st.faceOk, true);
    });

    test('nhiều mặt giữa thử thách thì không tính hành động và ngắt chuỗi giữ', () {
      final e = engine();
      final s = Sim(e);
      s.frame(Sim.neutral, times: 4);
      final first = e.challenges.first;
      s.frame(first == FaceAction.smile ? Sim.smiling : (first == FaceAction.turnLeft ? Sim.left : Sim.right));
      final st = s.frame(const FaceObservation(faceCount: 2, yaw: 40, smile: 1));
      expect(st.completed, 0);
      // 1 khung đúng rồi bị ngắt: vẫn cần 2 khung liên tiếp
      expect(s.frame(first == FaceAction.smile ? Sim.smiling : (first == FaceAction.turnLeft ? Sim.left : Sim.right)).completed, 0);
    });
  });

  group('Hành động', () {
    test('làm đúng 2 hành động theo thứ tự -> thành công, tiến trình 100%, mỗi hành động cần giữ nhiều khung', () {
      for (var seed = 0; seed < 12; seed++) {
        final e = engine(seed: seed);
        final s = Sim(e);
        s.frame(Sim.neutral, times: 4);
        final order = List<FaceAction>.of(e.challenges);
        // 1 khung đúng chưa đủ
        var st = s.frame(order[0] == FaceAction.smile ? Sim.smiling : (order[0] == FaceAction.turnLeft ? Sim.left : Sim.right));
        expect(st.completed, 0);
        st = s.doAction(order[0]);
        expect(st.completed, 1, reason: 'seed $seed');
        expect(st.hint, contains(order[1].instruction));
        s.frame(Sim.neutral); // trở về bình thường giữa 2 hành động
        st = s.doAction(order[1]);
        expect(st.phase, LivenessPhase.success, reason: 'seed $seed ${order.map((e) => e.name)}');
        expect(st.progress, 1);
      }
    });

    test('làm sai hành động (cần quay trái mà quay phải) thì không tính', () {
      final e = engine();
      final s = Sim(e);
      // ép thử thách: tìm seed mà hành động đầu là quay trái
      var seed = 0;
      var le = engine(seed: seed)..start(DateTime(2026));
      while (le.challenges.first != FaceAction.turnLeft) {
        le = engine(seed: ++seed)..start(DateTime(2026));
      }
      final s2 = Sim(engine(seed: seed));
      s2.frame(Sim.neutral, times: 4);
      var st = s2.frame(Sim.right, times: 5);
      expect(st.completed, 0);
      expect(st.hint, FaceAction.turnLeft.instruction);
      st = s2.frame(Sim.smiling, times: 5);
      expect(st.completed, 0);
      st = s2.frame(Sim.left, times: 2);
      expect(st.completed, 1);
      expect(s.engine, isNotNull);
    });

    test('ngưỡng: quay đầu 15° chưa đủ (cần >= 20°), cười 0.6 chưa đủ (cần >= 0.7)', () {
      var seed = 0;
      var le = engine(seed: seed)..start(DateTime(2026));
      while (le.challenges.first != FaceAction.turnLeft) {
        le = engine(seed: ++seed)..start(DateTime(2026));
      }
      final s = Sim(engine(seed: seed));
      s.frame(Sim.neutral, times: 4);
      expect(s.frame(const FaceObservation(faceCount: 1, yaw: 15, smile: 0), times: 4).completed, 0);
      expect(s.frame(const FaceObservation(faceCount: 1, yaw: 21, smile: 0), times: 2).completed, 1);

      var seed2 = 0;
      var se = engine(seed: seed2)..start(DateTime(2026));
      while (se.challenges.first != FaceAction.smile) {
        se = engine(seed: ++seed2)..start(DateTime(2026));
      }
      final s2 = Sim(engine(seed: seed2));
      s2.frame(Sim.neutral, times: 4);
      expect(s2.frame(const FaceObservation(faceCount: 1, yaw: 0, smile: 0.6), times: 4).completed, 0);
      expect(s2.frame(const FaceObservation(faceCount: 1, yaw: 0, smile: 0.72), times: 2).completed, 1);
    });

    test('hướng quay: dấu góc đảo được bằng cấu hình leftIsPositiveYaw', () {
      for (final leftPositive in [true, false]) {
        var seed = 0;
        var le = engine(seed: seed, leftPositive: leftPositive)..start(DateTime(2026));
        while (le.challenges.first != FaceAction.turnLeft) {
          le = engine(seed: ++seed, leftPositive: leftPositive)..start(DateTime(2026));
        }
        final s = Sim(engine(seed: seed, leftPositive: leftPositive));
        s.frame(Sim.neutral, times: 4);
        // yaw dương
        final st = s.frame(const FaceObservation(faceCount: 1, yaw: 30, smile: 0), times: 3);
        expect(st.completed, leftPositive ? 1 : 0);
      }
    });
  });

  group('Hết giờ', () {
    test('không thấy mặt bình thường trong 15 giây -> thất bại, nói rõ lý do', () {
      final s = Sim(engine());
      var st = s.frame(FaceObservation.none, times: 3);
      expect(st.phase, LivenessPhase.neutral);
      st = s.wait(const Duration(seconds: 15));
      expect(st.phase, LivenessPhase.failed);
      expect(st.failureReason, contains('khuôn mặt bình thường'));
      expect(st.secondsLeft, isNull);
    });

    test('hết 10 giây cho một hành động -> thất bại kèm tên hành động; sau đó không còn tiến triển', () {
      final e = engine();
      final s = Sim(e);
      s.frame(Sim.neutral, times: 4);
      var st = s.wait(const Duration(seconds: 9));
      expect(st.phase, LivenessPhase.challenge);
      expect(st.secondsLeft, inInclusiveRange(1, 2));
      st = s.wait(const Duration(seconds: 2));
      expect(st.phase, LivenessPhase.failed);
      expect(st.failureReason, contains(e.challenges.first.label));
      // đã thất bại thì khung hình sau không cứu được
      st = s.doAction(e.challenges.first);
      expect(st.phase, LivenessPhase.failed);
    });

    test('mỗi hành động có 10 giây riêng (làm xong hành động 1 thì giờ được đặt lại)', () {
      final e = engine();
      final s = Sim(e);
      s.frame(Sim.neutral, times: 4);
      s.wait(const Duration(seconds: 8));
      var st = s.doAction(e.challenges.first);
      expect(st.completed, 1);
      s.frame(Sim.neutral);
      st = s.wait(const Duration(seconds: 8)); // tổng > 10s từ đầu nhưng < 10s cho hành động 2
      expect(st.phase, LivenessPhase.challenge);
    });

    test('start() lại sau thất bại -> làm lại từ đầu với thử thách mới', () {
      final e = engine();
      final s = Sim(e);
      s.wait(const Duration(seconds: 16));
      expect(e.state.phase, LivenessPhase.failed);
      e.start(s.now);
      expect(e.state.phase, LivenessPhase.neutral);
      expect(e.state.completed, 0);
      expect(e.state.failureReason, isNull);
    });
  });
}
