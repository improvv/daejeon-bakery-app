import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'main_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'chat_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({Key? key}) : super(key: key);

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<FavoritesScreenState> _favKey = GlobalKey();
  final GlobalKey<SearchScreenState> _searchKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      MainScreen(onNavigateToTab: _onItemTapped),
      SearchScreen(key: _searchKey, onNavigateToTab: _onItemTapped),
      FavoritesScreen(key: _favKey, onNavigateToTab: _onItemTapped),
      const ChatScreen(),
    ];
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == 1 && index != 1) _searchKey.currentState?.reset();
    if (index == 2) _favKey.currentState?.loadFavorites();
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.crustBrown.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.map_rounded, Icons.map_outlined, '지도'),
              _buildNavItem(1, Icons.search_rounded, Icons.search_outlined, '검색'),
              _buildNavItem(2, Icons.bookmark_rounded, Icons.bookmark_border_rounded, '즐겨찾기'),
              _buildNavItem(3, Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, 'AI추천'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  key: ValueKey(isSelected),
                  color: isSelected ? AppColors.crustBrown : AppColors.textHint,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.crustBrown : AppColors.textHint,
                fontFamily: 'Pretendard',
              ),
              duration: const Duration(milliseconds: 200),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
