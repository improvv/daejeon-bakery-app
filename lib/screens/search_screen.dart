import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../models/search_history.dart';
import '../widgets/bakery_list_item.dart';
import 'bakery_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final BakeryRepository _repository = BakeryRepository();
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final response = await _repository.getSearchHistory();

    if (response.isSuccess && response.data != null) {
      setState(() {
        _searchHistory = response.data!;
      });
    } else {
      // Mock 데이터
      setState(() {
        _searchHistory = [
          SearchHistory(
            id: 1,
            keyword: '성심당',
            searchedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          SearchHistory(
            id: 2,
            keyword: '빵긍정',
            searchedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          SearchHistory(
            id: 3,
            keyword: '오븐이야기',
            searchedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ];
      });
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    final selectedDistrictNames = _selectedDistricts
        .where((district) => district != DistrictFilter.all)
        .map((district) => district.displayName)
        .toList();

    final districtQuery =
        selectedDistrictNames.length == 1 ? selectedDistrictNames.first : null;

    final response = await _repository.getBakeries(
      keyword: keyword,
      district: districtQuery,
    );

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _searchResults = response.data!;
      } else {
        // Mock 검색 결과
        _searchResults = [
          Bakery(
            id: 1,
            name: '성심당 본점',
            address: '대전광역시 중구 은행동 145',
            latitude: 36.3271,
            longitude: 127.4275,
            rating: 4.8,
            reviewCount: 1523,
            distance: 0.35,
          ),
        ];
      }
    });
  }

  Future<void> _deleteSearchHistory(int historyId) async {
    await _repository.deleteSearchHistory(historyId);
    setState(() {
      _searchHistory.removeWhere((item) => item.id == historyId);
    });
  }

  void _onHistoryTap(String keyword) {
    _searchController.text = keyword;
    _search(keyword);
  }

  void _onBakeryTap(Bakery bakery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BakeryDetailScreen(bakeryId: bakery.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 검색 헤더
            _buildSearchHeader(),

            // 위치 필터
            _buildDistrictFilters(),

            // 콘텐츠 영역
            Expanded(
              child:
                  _isSearching ? _buildSearchResults() : _buildRecentSearches(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '빵집 이름 검색',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: _search,
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '위치 필터',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: DistrictFilter.values.length,
              itemBuilder: (context, index) {
                final filter = DistrictFilter.values[index];
                final isSelected = filter == DistrictFilter.all
                    ? _selectedDistricts.contains(DistrictFilter.all)
                    : _selectedDistricts.contains(filter);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter.displayName,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _toggleDistrictSelection(filter);
                      });
                      if (_searchController.text.isNotEmpty) {
                        _search(_searchController.text);
                      }
                    },
                    backgroundColor: const Color(0xFFF8F8F8),
                    selectedColor: const Color(0xFFD97941),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleDistrictSelection(DistrictFilter filter) {
    if (filter == DistrictFilter.all) {
      _selectedDistricts = {DistrictFilter.all};
      return;
    }

    final nextSelection = {..._selectedDistricts}..remove(DistrictFilter.all);

    if (nextSelection.contains(filter)) {
      nextSelection.remove(filter);
    } else {
      nextSelection.add(filter);
    }

    if (nextSelection.isEmpty) {
      _selectedDistricts = {DistrictFilter.all};
      return;
    }

    _selectedDistricts = nextSelection;
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 검색',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _searchHistory.isEmpty
                ? const Center(
                    child: Text(
                      '최근 검색 내역이 없습니다',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchHistory.length,
                    itemBuilder: (context, index) {
                      final history = _searchHistory[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.history,
                          color: Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          history.keyword,
                          style: const TextStyle(fontSize: 15),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.grey,
                          onPressed: () => _deleteSearchHistory(history.id),
                        ),
                        onTap: () => _onHistoryTap(history.keyword),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return BakeryListItem(
          bakery: _searchResults[index],
          onTap: () => _onBakeryTap(_searchResults[index]),
        );
      },
    );
  }
}
