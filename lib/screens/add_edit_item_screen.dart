import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopping_list/data/database.dart';

class AddEditItemScreen extends StatefulWidget {
  final AppDatabase database;
  final ShoppingItem? item;
  final int? selectedCategoryId;

  const AddEditItemScreen({
    Key? key,
    required this.database,
    this.item,
    this.selectedCategoryId,
  }) : super(key: key);

  @override
  _AddEditItemScreenState createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  int? _selectedCategoryId;
  bool _isPurchased = false;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.item != null;

    // Initialize controllers with existing data if editing
    _nameController = TextEditingController(
      text: _isEditing ? widget.item!.name : '',
    );

    _quantityController = TextEditingController(
      text: _isEditing ? widget.item!.quantity.toString() : '1',
    );

    _selectedCategoryId =
        _isEditing ? widget.item!.category : widget.selectedCategoryId;

    _isPurchased = _isEditing ? widget.item!.isPurchased : false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Item' : 'Add Item')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 1) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              if (_isEditing) ...[
                CheckboxListTile(
                  title: const Text('Purchased'),
                  value: _isPurchased,
                  onChanged: (newValue) {
                    setState(() {
                      _isPurchased = newValue ?? false;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _saveItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: Text(
                  _isEditing ? 'Update Item' : 'Add Item',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<List<Category>>(
      stream: widget.database.watchAllCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!;

        return DropdownButtonFormField<int?>(
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          value: _selectedCategoryId,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('No Category'),
            ),
            ...categories.map((category) {
              return DropdownMenuItem<int?>(
                value: category.id,
                child: Text(category.name),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        );
      },
    );
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final quantity = int.parse(_quantityController.text);

      if (_isEditing) {
        // Update existing item
        final updatedItem = widget.item!.copyWith(
          name: name,
          quantity: quantity,
          category: drift.Value(_selectedCategoryId),
          isPurchased: _isPurchased,
        );

        widget.database.updateItem(updatedItem).then((_) {
          Navigator.pop(context);
        });
      } else {
        // Create a new item
        final item = ShoppingItemsCompanion(
          name: drift.Value(name),
          quantity: drift.Value(quantity),
          category: drift.Value(_selectedCategoryId),
          isPurchased: const drift.Value(false),
        );

        widget.database.addItem(item).then((_) {
          Navigator.pop(context);
        });
      }
    }
  }
}
