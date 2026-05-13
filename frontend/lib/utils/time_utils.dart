import 'package:flutter/material.dart';

bool isOpenNow(String? hours) {
  if (hours == null || hours.isEmpty) return false;
  if (hours.contains('24시간')) return true;
  if (hours.contains('휴무')) return false;

  int _toMin(String ampm, int h, int m) {
    if (ampm == '오후' && h != 12) h += 12;
    if (ampm == '오전' && h == 12) h = 0;
    return h * 60 + m;
  }

  bool _check(int openMin, int closeMin) {
    final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
    if (closeMin <= openMin) return nowMin >= openMin || nowMin < closeMin;
    return nowMin >= openMin && nowMin < closeMin;
  }

  // "오전/오후 H:MM ~ 오전/오후 H:MM" (양쪽 모두 오전/오후)
  final full = RegExp(r'(오전|오후)\s*(\d{1,2}):(\d{2})\s*[~–\-]\s*(오전|오후)\s*(\d{1,2}):(\d{2})').firstMatch(hours);
  if (full != null) {
    return _check(
      _toMin(full.group(1)!, int.parse(full.group(2)!), int.parse(full.group(3)!)),
      _toMin(full.group(4)!, int.parse(full.group(5)!), int.parse(full.group(6)!)),
    );
  }

  // "오전/오후 H:MM~H:MM" (닫는 시간에 오전/오후 없음 → 오후로 가정)
  final partial = RegExp(r'(오전|오후)\s*(\d{1,2}):(\d{2})\s*[~–\-]\s*(\d{1,2}):(\d{2})').firstMatch(hours);
  if (partial != null) {
    int closeH = int.parse(partial.group(4)!);
    if (closeH != 12) closeH += 12;
    return _check(
      _toMin(partial.group(1)!, int.parse(partial.group(2)!), int.parse(partial.group(3)!)),
      closeH * 60 + int.parse(partial.group(5)!),
    );
  }

  // 24시간 형식 "HH:MM – HH:MM"
  final h24 = RegExp(r'(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})').firstMatch(hours);
  if (h24 == null) return false;
  return _check(
    int.parse(h24.group(1)!) * 60 + int.parse(h24.group(2)!),
    int.parse(h24.group(3)!) * 60 + int.parse(h24.group(4)!),
  );
}
