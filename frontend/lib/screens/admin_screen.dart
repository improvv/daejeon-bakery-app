import 'package:flutter/material.dart';
import '../api/bakery_repository.dart';
import '../models/bakery.dart';
import '../theme/app_colors.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final BakeryRepository _repository = BakeryRepository();
  List<Bakery> _bakeries = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBakeries();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadBakeries() async {
    setState(() => _isLoading = true);
    final response = await _repository.getAdminBakeries();
    setState(() {
      _isLoading = false;
      _bakeries = response.isSuccess && response.data != null ? response.data! : [];
    });
  }

  List<Bakery> get _filtered {
    if (_searchQuery.isEmpty) return _bakeries;
    return _bakeries.where((b) => b.name.contains(_searchQuery) || b.address.contains(_searchQuery)).toList();
  }

  void _onEdit(Bakery bakery) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminEditScreen(bakery: bakery)),
    );
    if (updated == true) _loadBakeries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('관리자', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '빵집 이름 또는 주소 검색',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.crustBrown, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.crustBrown)))
          else if (_filtered.isEmpty)
            const Expanded(child: Center(child: Text('빵집이 없습니다', style: TextStyle(color: AppColors.textHint))))
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.crustBrown,
                onRefresh: _loadBakeries,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final b = _filtered[i];
                    final hasDesc = b.description?.isNotEmpty == true;
                    final hasMenu = b.specialMenu?.isNotEmpty == true;
                    final hasAmenities = b.amenities.isNotEmpty;
                    final isComplete = hasDesc && hasMenu && hasAmenities;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(b.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isComplete ? AppColors.openGreen : AppColors.caramel,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(b.address,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSec),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _badge('소개글', hasDesc),
                                const SizedBox(width: 4),
                                _badge('대표메뉴', hasMenu),
                                const SizedBox(width: 4),
                                _badge('편의시설', hasAmenities),
                              ],
                            ),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () => _onEdit(b),
                          style: TextButton.styleFrom(foregroundColor: AppColors.crustBrown),
                          child: const Text('편집', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String label, bool filled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? AppColors.creamFill : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: filled ? AppColors.crustBrown : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: filled ? AppColors.crustBrown : AppColors.textHint,
          fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class AdminEditScreen extends StatefulWidget {
  final Bakery bakery;
  const AdminEditScreen({super.key, required this.bakery});

  @override
  State<AdminEditScreen> createState() => _AdminEditScreenState();
}

class _AdminEditScreenState extends State<AdminEditScreen> {
  final BakeryRepository _repository = BakeryRepository();
  late TextEditingController _descController;
  late TextEditingController _menuController;
  late Set<String> _selectedAmenities;
  bool _isSaving = false;

  static const _amenityOptions = ['PARKING', 'PACKING', 'DELIVERY', 'WIFI', 'RESTROOM'];
  static const _amenityLabels = {
    'PARKING': '주차',
    'PACKING': '포장',
    'DELIVERY': '배달',
    'WIFI': 'WiFi',
    'RESTROOM': '화장실',
  };

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.bakery.description ?? '');
    _menuController = TextEditingController(text: widget.bakery.specialMenu ?? '');
    _selectedAmenities = Set.from(widget.bakery.amenities);
  }

  @override
  void dispose() {
    _descController.dispose();
    _menuController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final response = await _repository.updateBakeryInfo(
      widget.bakery.id,
      description: _descController.text.trim(),
      specialMenu: _menuController.text.trim(),
      amenities: _selectedAmenities.toList(),
    );
    setState(() => _isSaving = false);
    if (!mounted) return;
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('저장되었습니다'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: ${response.message}'),
          backgroundColor: AppColors.closedRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.bakery.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.crustBrown))
                  : const Text('저장',
                      style: TextStyle(color: AppColors.crustBrown, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('소개글'),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '빵집 소개글을 입력하세요',
              hintStyle: const TextStyle(color: AppColors.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.crustBrown, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('대표 메뉴'),
          const SizedBox(height: 4),
          const Text('쉼표(,)로 구분해서 입력하세요',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 8),
          TextField(
            controller: _menuController,
            decoration: InputDecoration(
              hintText: '예: 크루아상, 소금빵, 바게트',
              hintStyle: const TextStyle(color: AppColors.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.crustBrown, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('편의시설'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenityOptions.map((a) {
              final selected = _selectedAmenities.contains(a);
              return FilterChip(
                label: Text(_amenityLabels[a]!),
                selected: selected,
                showCheckmark: false,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedAmenities.add(a);
                  } else {
                    _selectedAmenities.remove(a);
                  }
                }),
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.creamFill,
                side: BorderSide(
                  color: selected ? AppColors.crustBrown : AppColors.border,
                  width: selected ? 1.5 : 1.0,
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: selected ? AppColors.crustBrown : AppColors.textSec,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }
}
