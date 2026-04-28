import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/review.dart';
import '../theme/app_colors.dart';

class ReviewItem extends StatelessWidget {
  final Review review;
  const ReviewItem({Key? key, required this.review}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 유저 정보 + 평점
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.creamFill,
                backgroundImage: review.userProfileImage != null
                    ? NetworkImage(review.userProfileImage!)
                    : null,
                child: review.userProfileImage == null
                    ? Text(
                        review.userName[0],
                        style: const TextStyle(
                          color: AppColors.crustBrown,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < review.rating.floor()
                              ? Icons.star_rounded
                              : (i < review.rating ? Icons.star_half_rounded : Icons.star_border_rounded),
                          size: 14,
                          color: AppColors.caramel,
                        )),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 리뷰 내용
          Text(
            review.content,
            style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
          ),

          // 리뷰 이미지
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                itemBuilder: (context, index) => Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider, width: 1),
                    image: DecorationImage(
                      image: NetworkImage(review.imageUrls[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7)  return '${diff.inDays}일 전';
    return DateFormat('yyyy.MM.dd').format(date);
  }
}
