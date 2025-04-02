import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

// This will be the data class for the shopping list items
part 'database.g.dart';

// Table definition for shopping categories
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
}

// Table definition for shopping list items
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get category => integer().nullable().references(Categories, #id)();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Database class that puts it all together
@DriftDatabase(tables: [ShoppingItems, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  // Helper methods for ShoppingItems
  Future<List<ShoppingItem>> getAllItems() => select(shoppingItems).get();
  
  Stream<List<ShoppingItem>> watchAllItems() => select(shoppingItems).watch();
  
  Stream<List<ShoppingItem>> watchItemsByCategory(int categoryId) {
    return (select(shoppingItems)..where((item) => item.category.equals(categoryId))).watch();
  }

  Future<int> addItem(ShoppingItemsCompanion item) {
    return into(shoppingItems).insert(item);
  }

  Future<bool> updateItem(ShoppingItem item) {
    return update(shoppingItems).replace(item);
  }

  Future<int> deleteItem(int id) {
    return (delete(shoppingItems)..where((item) => item.id.equals(id))).go();
  }

  Future<void> toggleItemPurchased(int id) async {
    final item = await (select(shoppingItems)..where((item) => item.id.equals(id))).getSingle();
    await updateItem(item.copyWith(isPurchased: !item.isPurchased));
  }

  // Helper methods for Categories
  Future<List<Category>> getAllCategories() => select(categories).get();
  
  Stream<List<Category>> watchAllCategories() => select(categories).watch();
  
  Future<int> addCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  Future<bool> updateCategory(Category category) {
    return update(categories).replace(category);
  }

  Future<int> deleteCategory(int id) {
    return (delete(categories)..where((category) => category.id.equals(id))).go();
  }

  // Method to seed initial categories if none exist
  Future<void> seedInitialCategories() async {
    final categoryCount = await select(categories).get();
    if (categoryCount.isEmpty) {
      await batch((batch) {
        batch.insertAll(categories, [
          CategoriesCompanion.insert(name: 'Produce'),
          CategoriesCompanion.insert(name: 'Dairy'),
          CategoriesCompanion.insert(name: 'Meat'),
          CategoriesCompanion.insert(name: 'Bakery'),
          CategoriesCompanion.insert(name: 'Pantry'),
          CategoriesCompanion.insert(name: 'Frozen'),
          CategoriesCompanion.insert(name: 'Beverages'),
          CategoriesCompanion.insert(name: 'Household'),
        ]);
      });
    }
  }
  
  // Method for joining ShoppingItems with Categories
  Future<List<ShoppingItemWithCategory>> getItemsWithCategory() async {
    final query = select(shoppingItems).join([
      leftOuterJoin(categories, categories.id.equalsExp(shoppingItems.category)),
    ]);
    
    final rows = await query.get();
    
    return rows.map((row) {
      return ShoppingItemWithCategory(
        item: row.readTable(shoppingItems),
        category: row.readTableOrNull(categories),
      );
    }).toList();
  }
  
  Stream<List<ShoppingItemWithCategory>> watchItemsWithCategory() {
    final query = select(shoppingItems).join([
      leftOuterJoin(categories, categories.id.equalsExp(shoppingItems.category)),
    ]);
    
    return query.watch().map((rows) {
      return rows.map((row) {
        return ShoppingItemWithCategory(
          item: row.readTable(shoppingItems),
          category: row.readTableOrNull(categories),
        );
      }).toList();
    });
  }

  // Database connection setup
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'shopping_list.db',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}

// Class to represent a shopping item with its optional category
class ShoppingItemWithCategory {
  final ShoppingItem item;
  final Category? category;

  ShoppingItemWithCategory({required this.item, this.category});
}