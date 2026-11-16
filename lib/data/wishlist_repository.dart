import 'package:drift/drift.dart';
import 'savings_database.dart';

class WishlistItem {
  const WishlistItem({required this.id, required this.name, required this.price, required this.note, required this.purchased});
  final int id, price;
  final String name, note;
  final bool purchased;
}

class WishlistRepository {
  WishlistRepository(this.database);
  final SavingsDatabase database;
  Future<List<WishlistItem>> list() async {
    final rows = await database.customSelect('SELECT * FROM wishlist_items ORDER BY purchased ASC, created_at DESC, id DESC').get();
    return rows.map((r) => WishlistItem(id: r.read<int>('id'), name: r.read<String>('name'), price: r.read<int>('price'), note: r.read<String>('note'), purchased: r.read<int>('purchased') == 1)).toList();
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
  Future<void> delete(int id) async {
    final count = await database.customUpdate('DELETE FROM wishlist_items WHERE id=?', variables: [Variable.withInt(id)]);
    if (count == 0) throw StateError('Wishlist tidak ditemukan.');
  }
}
