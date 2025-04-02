import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:shopping_list/data/database.dart';
import 'package:shopping_list/screens/add_edit_item_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase database;

  const HomeScreen({Key? key, required this.database}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedCategoryId;
  bool _showPurchasedItems = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          IconButton(
            icon: Icon(
              _showPurchasedItems
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: () {
              setState(() {
                _showPurchasedItems = !_showPurchasedItems;
              });
            },
            tooltip:
                _showPurchasedItems
                    ? 'Hide purchased items'
                    : 'Show purchased items',
          ),
        ],
      ),
      drawer: _buildCategoryDrawer(),
      body: Column(
        children: [
          if (_selectedCategoryId != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCategoryHeader(),
            ),
          Expanded(child: _buildShoppingList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddItemScreen(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return FutureBuilder<Category?>(
   future: (widget.database
        .select(widget.database.categories)
        ..where((tbl) => tbl.id.equals(_selectedCategoryId!)))
        .getSingleOrNull(), 
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Row(
            children: [
              Expanded(
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category: ${snapshot.data!.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedCategoryId = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildCategoryDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Center(
              child: Text(
                'Categories',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: widget.database.watchAllCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No categories available'));
                }

                return ListView(
                  children: [
                    ListTile(
                      title: const Text('All Items'),
                      selected: _selectedCategoryId == null,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                    ...snapshot.data!.map((category) {
                      return ListTile(
                        title: Text(category.name),
                        selected: _selectedCategoryId == category.id,
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = category.id;
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingList() {
    return StreamBuilder<List<ShoppingItemWithCategory>>(
      stream: widget.database.watchItemsWithCategory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No items in your shopping list'));
        }

        final items =
            snapshot.data!.where((itemWithCategory) {
              // Filter by category if selected
              if (_selectedCategoryId != null) {
                if (itemWithCategory.item.category != _selectedCategoryId) {
                  return false;
                }
              }

              // Filter out purchased items if needed
              if (!_showPurchasedItems && itemWithCategory.item.isPurchased) {
                return false;
              }

              return true;
            }).toList();

        if (items.isEmpty) {
          return Center(
            child: Text(
              _selectedCategoryId != null
                  ? 'No items in this category'
                  : 'No items match your filters',
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final itemWithCategory = items[index];
            return _buildShoppingListItem(itemWithCategory);
          },
        );
      },
    );
  }

  Widget _buildShoppingListItem(ShoppingItemWithCategory itemWithCategory) {
    final item = itemWithCategory.item;
    final category = itemWithCategory.category;

    return Dismissible(
      key: Key('item-${item.id}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        widget.database.deleteItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} removed'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                // Create a copy of the deleted item with a new ID
                widget.database.addItem(
                  ShoppingItemsCompanion(
                    name: drift.Value(item.name),
                    quantity: drift.Value(item.quantity),
                    category: drift.Value(item.category),
                    isPurchased: drift.Value(item.isPurchased),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: Checkbox(
            value: item.isPurchased,
            onChanged: (bool? newValue) {
              widget.database.toggleItemPurchased(item.id);
            },
          ),
          title: Text(
            item.name,
            style: TextStyle(
              decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            '${item.quantity} ${item.quantity > 1 ? 'items' : 'item'}${category != null ? ' • ${category.name}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _navigateToEditItemScreen(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddItemScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddEditItemScreen(
              database: widget.database,
              selectedCategoryId: _selectedCategoryId,
            ),
      ),
    );
  }

  void _navigateToEditItemScreen(ShoppingItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                AddEditItemScreen(database: widget.database, item: item),
      ),
    );
  }
}
