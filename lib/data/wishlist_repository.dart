import 'package:drift/drift.dart';
import 'savings_database.dart';
import '../services/goal_photo_storage.dart';

class WishlistItem {
  const WishlistItem({required this.id, required this.name, required this.price, required this.note, required this.purchased, this.coverPhotoPath});
  final int id, price;
  final String name, note;
  final String? coverPhotoPath;
  final bool purchased;
}

class WishlistRepository {
  WishlistRepository(this.database);
  final SavingsDatabase database;
  Future<List<WishlistItem>> list() async {
    final rows = await database.customSelect('SELECT * FROM wishlist_items ORDER BY purchased ASC, created_at DESC, id DESC').get();
    return rows.map((r) => WishlistItem(id: r.read<int>('id'), name: r.read<String>('name'), price: r.read<int>('price'), note: r.read<String>('note'), purchased: r.read<int>('purchased') == 1, coverPhotoPath: r.read<String?>('cover_photo_path'))).toList();
  }
  Future<void> save({int? id, required String name, required int price, required String note}) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 100 || price < 0 || price > 1000000000000 || note.length > 500) {
      throw ArgumentError('Nama wajib diisi, harga harus valid, dan catatan maksimal 500 karakter.');
    }
    if (id == null) {
      await database.customInsert('INSERT INTO wishlist_items (name, price, note, created_at) VALUES (?, ?, ?, ?)', variables: [Variable.withString(clean), Variable.withInt(price), Variable.withString(note.trim()), Variable.withInt(DateTime.now().millisecondsSinceEpoch)]);
    } else {
      final count = await database.customUpdate('UPDATE wishlist_items SET name=?, price=?, note=? WHERE id=?', variables: [Variable.withString(clean), Variable.withInt(price), Variable.withString(note.trim()), Variable.withInt(id)]);
      if (count == 0) throw StateError('Wishlist tidak ditemukan.');
    }
  }
  Future<void> setPurchased(int id, bool purchased) async {
    final count = await database.customUpdate('UPDATE wishlist_items SET purchased=? WHERE id=?', variables: [Variable.withInt(purchased ? 1 : 0), Variable.withInt(id)]);
    if (count == 0) throw StateError('Wishlist tidak ditemukan.');
  }
  Future<String?> setPhoto(int id, String? path) async {
    if (path != null && !GoalPhotoStorage.isManagedRelativePath(path)) {
      throw ArgumentError('Path foto tidak aman.');
    }
    return database.transaction(() async {
      final row = await database.customSelect('SELECT cover_photo_path FROM wishlist_items WHERE id=?', variables: [Variable.withInt(id)]).getSingleOrNull();
      if (row == null) throw StateError('Wishlist tidak ditemukan.');
      await database.customUpdate('UPDATE wishlist_items SET cover_photo_path=? WHERE id=?', variables: [Variable<String>(path), Variable.withInt(id)]);
      return row.read<String?>('cover_photo_path');
    });
  }
  Future<String?> delete(int id) => database.transaction(() async {
    final row = await database.customSelect('SELECT cover_photo_path FROM wishlist_items WHERE id=?', variables: [Variable.withInt(id)]).getSingleOrNull();
    if (row == null) throw StateError('Wishlist tidak ditemukan.');
    await database.customUpdate('DELETE FROM wishlist_items WHERE id=?', variables: [Variable.withInt(id)]);
    return row.read<String?>('cover_photo_path');
  });
}
