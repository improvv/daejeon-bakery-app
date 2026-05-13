import 'package:flutter/material.dart';

/// '매일 08:00 - 20:00' 또는 '화-일 10:00 - 21:00' 형식 파싱
bool isOpenNow(String? hours) {
  if (hours == null || hours.isEmpty) return false;
  final match = RegExp(r'(\d{2}):(\d{2})\s*-\s*(\d{2}):(\d{2})').firstMatch(hours);
  if (match == null) return false;
  final now = TimeOfDay.now();
  final nowMin  = now.hour * 60 + now.minute;
  final openMin = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  final closeMin = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
  return nowMin >= openMin && nowMin < closeMin;
}
