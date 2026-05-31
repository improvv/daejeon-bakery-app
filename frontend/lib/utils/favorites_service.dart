import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorite_bakery_ids';

  static Future<List<int>> getIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).map(int.parse).toList();
  }

  static Future<bool> isFavorite(int id) async {
    final ids = await getIds();
    return ids.contains(id);
  }

  static Future<bool> toggle(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_key) ?? []);
    if (ids.contains(id.toString())) {
      ids.remove(id.toString());
    } else {
      ids.add(id.toString());
    }
    await prefs.setStringList(_key, ids);
    return ids.contains(id.toString());
  }
}
