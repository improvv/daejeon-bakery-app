import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── 배경 / 서피스 ──────────────────────────────────
  static const background  = Color(0xFFFDFAF5); // 따뜻한 아이보리 화이트
  static const surface     = Color(0xFFFFFFFF); // 카드, 모달, 시트
  static const surfaceAlt  = Color(0xFFF7F1E8); // 검색·즐겨찾기 화면 배경

  // ── 브랜드 컬러 ────────────────────────────────────
  static const crustBrown  = Color(0xFFC8622A); // 메인 — 구운 빵 껍질
  static const caramel     = Color(0xFFE8973A); // 서브 — 카라멜 소스
  static const butter      = Color(0xFFF5D990); // 액센트 — 버터
  static const creamFill   = Color(0xFFFDF0DC); // 아이콘 배경·칩 선택 배경

  // ── 텍스트 ─────────────────────────────────────────
  static const textPrimary = Color(0xFF1C1410); // 따뜻한 거의-검정
  static const textSec     = Color(0xFF7A5C4A); // 따뜻한 중간 갈색
  static const textHint    = Color(0xFFB89880); // 연한 따뜻한 갈색

  // ── UI 요소 ────────────────────────────────────────
  static const divider     = Color(0xFFEDE4D8); // 따뜻한 베이지 구분선
  static const border      = Color(0xFFE8D9C8); // 테두리

  // ── 상태 컬러 ──────────────────────────────────────
  static const openGreen   = Color(0xFF2D9E6B); // 영업 중
  static const closedRed   = Color(0xFFD94F3D); // 영업 종료

  // ── 지도 전용 ──────────────────────────────────────
  static const myLocation  = Color(0xFF3B82F6); // 현재 위치 (빵집 마커와 완전히 다른 온도)
}
