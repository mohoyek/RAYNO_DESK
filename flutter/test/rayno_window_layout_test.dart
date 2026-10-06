import 'dart:ui';

import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/widgets/rayno_window_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raynoWindowSize clamps the width to the 320..420 range', () {
    // Small screen: 1000/6 = 166, clamped up to the minimum.
    expect(raynoWindowSize(const Size(1000, 800)).width, 320.0);
    // Typical 1080p: 1920/6 = 320.
    expect(raynoWindowSize(const Size(1920, 1080)).width, 320.0);
    // Large screen: 3840/6 = 640, clamped down to the maximum.
    expect(raynoWindowSize(const Size(3840, 2160)).width, 420.0);
  });

  test('raynoWindowSize derives the height from the clamped width', () {
    // 320 * 1.25 = 400.
    expect(raynoWindowSize(const Size(1000, 800)).height, 400.0);
    // 420 * 1.25 = 525, clamped down to the maximum height.
    expect(raynoWindowSize(const Size(3840, 2160)).height, 520.0);
  });

  test('raynoWindowSize always stays inside the documented bounds', () {
    for (final screen in const [
      Size(640, 480),
      Size(1280, 720),
      Size(1920, 1080),
      Size(2560, 1440),
      Size(3840, 2160),
      Size(7680, 4320),
    ]) {
      final size = raynoWindowSize(screen);
      expect(size.width, inInclusiveRange(kRaynoMinWidth, kRaynoMaxWidth));
      expect(size.height, inInclusiveRange(kRaynoMinHeight, kRaynoMaxHeight));
    }
  });

  test('formatID groups the id in threes, like the password row', () {
    expect(formatID('123456789'), '123 456 789');
    expect(formatID('123'), '123');
    expect(formatID('1234'), '1 234');
    expect(formatID(''), '');
    expect(formatID('not-an-id'), 'not-an-id');
  });
}