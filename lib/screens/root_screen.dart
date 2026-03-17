import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({Key? key}) : super(key: key);

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      MainScreen(onNavigateToTab: _onItemTapped),
      SearchScreen(onNavigateToTab: _onItemTapped),
      FavoritesScreen(onNavigateToTab: _onItemTapped),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 안드로이드 물리 백버튼 처리
  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      // 메인(지도) 탭이 아니면 메인 탭으로 이동하고 앱 종료 방지
      setState(() {
        _selectedIndex = 0;
      });
      return false; // pop 방지
    }
    // 메인 탭이면 앱을 종료하도록 true 반환
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // 지도(GoogleMap)의 렌더링 성능과 재생성 시 발생하는 네이티브 메모리 크래시 방지 및 탭 전환 상태 유지를 위해 IndexedStack 사용
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        // 하단 네비게이션 바는 Root에서만 고정 담당
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 88,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.map, '지도'),
            _buildNavItem(1, Icons.search, '검색'),
            _buildNavItem(2, Icons.star, '즐겨찾기'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFFD97941) : Colors.grey;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        color: Colors.transparent, // 여백 터치 시에도 탭 이동 가능하도록 추가
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
