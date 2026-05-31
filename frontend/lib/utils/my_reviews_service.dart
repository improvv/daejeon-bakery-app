import 'package:shared_preferences/shared_preferences.dart';

class MyReviewsService {
  static const _key = 'my_review_ids';

  static Future<List<int>> getIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).map(int.parse).toList();
  }

  static Future<void> add(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    if (!ids.contains(id.toString())) {
      ids.add(id.toString());
      await prefs.setStringList(_key, ids);
    }
  }

  static Future<void> remove(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    ids.remove(id.toString());
    await prefs.setStringList(_key, ids);
  }

  static Future<bool> isMine(int id) async {
    final ids = await getIds();
    return ids.contains(id);
  }
}
