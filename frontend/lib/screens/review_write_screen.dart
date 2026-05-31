import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/bakery_repository.dart';
import '../theme/app_colors.dart';
import '../utils/my_reviews_service.dart';

class ReviewWriteScreen extends StatefulWidget {
  final int bakeryId;
  final String bakeryName;

  const ReviewWriteScreen({super.key, required this.bakeryId, required this.bakeryName});

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final BakeryRepository _repository = BakeryRepository();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  double _rating = 0;
  XFile? _pickedImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _contentController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 800);
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<String?> _encodeImage() async {
    if (_pickedImage == null) return null;
    final bytes = await File(_pickedImage!.path).readAsBytes();
    final ext = _pickedImage!.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    final content = _contentController.text.trim();

    if (nickname.isEmpty || _rating == 0 || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임, 별점, 후기를 모두 입력해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final imageData = await _encodeImage();

    final response = await _repository.postReview(
      widget.bakeryId,
      nickname: nickname,
      rating: _rating,
      content: content,
      imageData: imageData,
    );

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (response.isSuccess) {
      if (response.data != null) await MyReviewsService.add(response.data!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: ${response.message}'), backgroundColor: AppColors.closedRed),
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
        title: Text(widget.bakeryName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.crustBrown))
                  : const Text('등록',
                      style: TextStyle(color: AppColors.crustBrown, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 닉네임
          _label('닉네임'),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: _inputDeco('닉네임을 입력하세요'),
          ),
          const SizedBox(height: 24),

          // 별점
          _label('별점'),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star.toDouble()),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    _rating >= star ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.caramel,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 후기
          _label('후기'),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: _inputDeco('빵집에 대한 솔직한 후기를 남겨주세요'),
          ),
          const SizedBox(height: 24),

          // 사진 (선택)
          _label('사진 (선택)'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickImage,
            child: _pickedImage == null
                ? Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.textHint, size: 32),
                        SizedBox(height: 6),
                        Text('사진 추가', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_pickedImage!.path),
                            height: 160, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.crustBrown, width: 1.5)),
        contentPadding: const EdgeInsets.all(14),
      );
}
