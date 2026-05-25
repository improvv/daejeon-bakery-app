import 'dart:async';

import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../models/search_history.dart';
import '../theme/app_colors.dart';
import '../widgets/bakery_list_item.dart';
import 'bakery_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const SearchScreen({Key? key, this.onNavigateToTab}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final BakeryRepository _repository = BakeryRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<SearchHistory> _searchHistory = [];
  List<Bakery> _searchResults = [];
  Set<DistrictFilter> _selectedDistricts = {DistrictFilter.all};
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final response = await _repository.getSearchHistory();
    setState(() {
      _searchHistory = response.isSuccess && response.data != null
          ? response.data!
          : [
              SearchHistory(id: 1, keyword: '성심당',    searchedAt: DateTime.now().subtract(const Duration(hours: 2))),
              SearchHistory(id: 2, keyword: '빵긍정',    searchedAt: DateTime.now().subtract(const Duration(days: 1))),
              SearchHistory(id: 3, keyword: '오븐이야기', searchedAt: DateTime.now().subtract(const Duration(days: 3))),
            ];
    });
  }

  // 실제 검색 실행
  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() { _isLoading = true; _isSearching = true; });

    // 구 필터: 1개만 선택된 경우 백엔드에 전달, 복수 선택 시 전체 조회
    final selectedDistricts = _selectedDistricts.where((d) => d != DistrictFilter.all).toList();
    final districtQuery = selectedDistricts.length == 1 ? selectedDistricts.first.displayName : null;

    final response = await _repository.getBakeries(
      keyword: keyword.trim(),
      district: districtQuery,
      latitude: 36.3504,
      longitude: 127.3845,
      radius: 15,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _searchResults = response.isSuccess && response.data != null ? response.data! : [];
    });
  }

  // 타이핑할 때 400ms 후 자동 검색
  void _onSearchChanged(String value) {
    setState(() {}); // X 버튼 표시 갱신
    _debounceTimer?.cancel();

    if (value.trim().isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }

    setState(() { _isSearching = true; _isLoading = true; });
    _debounceTimer = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  // Enter / 검색 버튼: 즉시 검색
  void _onSearchSubmitted(String value) {
    _debounceTimer?.cancel();
    _search(value);
  }

  Future<void> _deleteSearchHistory(int historyId) async {
    await _repository.deleteSearchHistory(historyId);
    setState(() => _searchHistory.removeWhere((item) => item.id == historyId));
  }

  void _onHistoryTap(String keyword) {
    _searchController.text = keyword;
    _debounceTimer?.cancel();
    _search(keyword);
  }

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => BakeryDetailScreen(bakeryId: bakery.id),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
    );
  }

  void _toggleDistrictSelection(DistrictFilter filter) {
    if (filter == DistrictFilter.all) {
      _selectedDistricts = {DistrictFilter.all};
    } else {
      final next = {..._selectedDistricts}..remove(DistrictFilter.all);
      next.contains(filter) ? next.remove(filter) : next.add(filter);
      _selectedDistricts = next.isEmpty ? {DistrictFilter.all} : next;
    }
    // 검색어가 있으면 필터 변경 시 즉시 재검색
    if (_searchController.text.trim().isNotEmpty) {
      _debounceTimer?.cancel();
      _search(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            _buildDistrictFilters(),
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildRecentSearches(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              if (widget.onNavigateToTab != null) {
                widget.onNavigateToTab!(0);
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '빵집 이름, 메뉴, 주소 검색',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
                  prefixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.crustBrown,
                            ),
                          ),
                        )
                      : const Icon(Icons.search_rounded, color: AppColors.crustBrown, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                          onPressed: () {
                            _debounceTimer?.cancel();
                            _searchController.clear();
                            setState(() { _isSearching = false; _searchResults = []; _isLoading = false; });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: DistrictFilter.values.length,
              itemBuilder: (context, index) {
                final filter = DistrictFilter.values[index];
                final isSelected = filter == DistrictFilter.all
                    ? _selectedDistricts.contains(DistrictFilter.all)
                    : _selectedDistricts.contains(filter);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter.displayName),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _toggleDistrictSelection(filter)),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected ? AppColors.crustBrown : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    selectedColor: AppColors.creamFill,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.crustBrown : AppColors.textSec,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('최근 검색',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        if (_searchHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('최근 검색 내역이 없습니다',
                  style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            ),
          )
        else
          ..._searchHistory.map((history) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, color: AppColors.textHint, size: 20),
                title: Text(history.keyword,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                  onPressed: () => _deleteSearchHistory(history.id),
                ),
                onTap: () => _onHistoryTap(history.keyword),
              )),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              '"${_searchController.text}" 검색 결과가 없어요',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              '다른 키워드로 검색하거나\n필터를 변경해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSec, height: 1.6),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                _debounceTimer?.cancel();
                _searchController.clear();
                setState(() {
                  _isSearching = false;
                  _searchResults = [];
                  _selectedDistricts = {DistrictFilter.all};
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.crustBrown,
                side: const BorderSide(color: AppColors.crustBrown),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('검색 초기화', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '검색 결과 ${_searchResults.length}개',
            style: const TextStyle(fontSize: 13, color: AppColors.textSec),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) => BakeryListItem(
              bakery: _searchResults[index],
              onTap: () => _onBakeryTap(_searchResults[index]),
            ),
          ),
        ),
      ],
    );
  }
}
