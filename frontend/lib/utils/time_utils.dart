import 'package:flutter/material.dart';

bool isOpenNow(String? hours) {
  if (hours == null || hours.isEmpty) return false;
  if (hours.contains('24시간')) return true;

  const dayOrder = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
  final today = DateTime.now().weekday; // 1=월 ~ 7=일

  bool checkTime(int openMin, int closeMin) {
    final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
    if (closeMin <= openMin) return nowMin >= openMin || nowMin < closeMin;
    return nowMin >= openMin && nowMin < closeMin;
  }

  bool todayInRange(String dayStr) {
    dayStr = dayStr.trim();
    final rangeMatch = RegExp(r'([월화수목금토일])\s*[-~]\s*([월화수목금토일])').firstMatch(dayStr);
    if (rangeMatch != null) {
      final start = dayOrder[rangeMatch.group(1)!]!;
      final end = dayOrder[rangeMatch.group(2)!]!;
      if (start <= end) return today >= start && today <= end;
      return today >= start || today <= end;
    }
    for (final entry in dayOrder.entries) {
      if (dayStr.contains(entry.key) && entry.value == today) return true;
    }
    return false;
  }

  // CSV 형식: 세그먼트를 " / "로 분리
  final segments = hours.split(RegExp(r'\s*/\s*'));

  for (final segment in segments) {
    final s = segment.trim();

    // 매일
    if (s.startsWith('매일')) {
      if (s.contains('휴무')) return false;
      final m = RegExp(r'(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})').firstMatch(s);
      if (m != null) {
        return checkTime(
          int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!),
          int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!),
        );
      }
      return false;
    }

    // 요일 범위 파싱
    final dayMatch = RegExp(r'^([월화수목금토일][월화수목금토일\-~,·\s]*)').firstMatch(s);
    if (dayMatch == null) continue;

    if (!todayInRange(dayMatch.group(1)!)) continue;

    if (s.contains('휴무')) return false;

    final m = RegExp(r'(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})').firstMatch(s);
    if (m != null) {
      return checkTime(
        int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!),
        int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!),
      );
    }
  }

  // Google Places 오전/오후 형식 fallback
  int toMin(String ampm, int h, int m) {
    if (ampm == '오후' && h != 12) h += 12;
    if (ampm == '오전' && h == 12) h = 0;
    return h * 60 + m;
  }

  final full = RegExp(r'(오전|오후)\s*(\d{1,2}):(\d{2})\s*[~–\-]\s*(오전|오후)\s*(\d{1,2}):(\d{2})').firstMatch(hours);
  if (full != null) {
    return checkTime(
      toMin(full.group(1)!, int.parse(full.group(2)!), int.parse(full.group(3)!)),
      toMin(full.group(4)!, int.parse(full.group(5)!), int.parse(full.group(6)!)),
    );
  }

  // 24시간 형식 단독 fallback
  final h24 = RegExp(r'(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})').firstMatch(hours);
  if (h24 != null) {
    return checkTime(
      int.parse(h24.group(1)!) * 60 + int.parse(h24.group(2)!),
      int.parse(h24.group(3)!) * 60 + int.parse(h24.group(4)!),
    );
  }

  return false;
}
