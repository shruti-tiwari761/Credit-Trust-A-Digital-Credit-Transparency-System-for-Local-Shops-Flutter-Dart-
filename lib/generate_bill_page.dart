import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'app_colors.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'mongodb_service.dart';

class GenerateBillPage extends StatefulWidget {
  const GenerateBillPage({super.key});

  @override
  State<GenerateBillPage> createState() => _GenerateBillPageState();
}

class _GenerateBillPageState extends State<GenerateBillPage> {
  String? _selectedCustomerId;
  String? _selectedCustomerPhone;
  String? _selectedCustomerEmail;
  String? _selectedCustomerName;
  
  // New: List of items in the current bill
  final List<Map<String, dynamic>> _items = [];
  
  // Controllers for the "current item" being added
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  
  final _paidController = TextEditingController();
  final _remainingController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  // Document attachments
  final List<String> _attachedFileNames = [];

  final FirebaseService _firebaseService = FirebaseService();

  double get _totalAmount => _items.fold(0, (sum, item) => sum + (item['total'] as double));

  void _addItem() {
    final String product = _productController.text.trim();
    final double qty = double.tryParse(_quantityController.text) ?? 0;
    final double price = double.tryParse(_priceController.text) ?? 0;
    
    if (product.isEmpty || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid product name, quantity, and price')),
      );
      return;
    }
    
    setState(() {
      _items.add({
        'productName': product,
        'quantity': qty,
        'price': price,
        'total': qty * price,
      });
      _productController.clear();
      _quantityController.clear();
      _priceController.clear();
      _calculateRemaining();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    double total = _totalAmount;
    double paid = double.tryParse(_paidController.text) ?? 0;
    _remainingController.text = (total - paid).toStringAsFixed(2);
  }

  Future<void> _generateBill() async {
    if (_selectedCustomerId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer and add at least one item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double totalAmount = _totalAmount;
      final double totalPaid = double.tryParse(_paidController.text) ?? 0.0;
      final double remainingAmount = totalAmount - totalPaid;

      final billData = {
        'customerId': _selectedCustomerId,
        'items': _items,
        'totalAmount': totalAmount,
        'totalPaid': totalPaid,
        'remainingAmount': remainingAmount,
        'note': _noteController.text.trim(),
        'attachments': _attachedFileNames,
      };

      final double totalBalance = await _firebaseService.generateBill(_selectedCustomerId!, billData, totalAmount, remainingAmount);

      // Trigger Notifications
      if (_selectedCustomerPhone != null) {
        await NotificationService.sendBillNotification(
          phone: _selectedCustomerPhone!,
          items: _items,
          totalBill: totalAmount,
          paid: totalPaid, 
          remainingDue: remainingAmount, 
          totalOutstandingBalance: totalBalance,
        );
      }

      if (_selectedCustomerEmail != null) {
        await NotificationService.sendEmailNotification(
          email: _selectedCustomerEmail!,
          customerName: _selectedCustomerName ?? 'Customer',
          items: _items,
          totalAmount: totalAmount,
          paidAmount: totalPaid,
          remainingAmount: remainingAmount,
          totalOutstanding: totalBalance,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Multi-item Bill generated successfully')),
        );
        _clearFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearFields() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerPhone = null;
      _selectedCustomerEmail = null;
      _selectedCustomerName = null;
      _items.clear();
      _attachedFileNames.clear();
    });
    _productController.clear();
    _quantityController.clear();
    _priceController.clear();
    _paidController.clear();
    _remainingController.clear();
    _noteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Customer Selection Card
          _buildCard(
            title: 'Customer Details',
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getCustomers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                var customers = snapshot.data!.docs;
                return DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Select Customer', Icons.person),
                  value: _selectedCustomerId,
                  items: customers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unknown'),
                      onTap: () {
                        _selectedCustomerPhone = data['phone'];
                        _selectedCustomerEmail = data['email'];
                        _selectedCustomerName = data['name'];
                      },
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCustomerId = val),
                );
              }
            ),
          ),
          const SizedBox(height: 16),

          // Item Addition Section
          _buildCard(
            title: 'Add Products',
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (option) => option['productName'],
                    optionsBuilder: (textValue) async {
                      if (textValue.text.isEmpty) return [];
                      return await MongoService.searchProducts(textValue.text);
                    },
                    onSelected: (selection) {
                      _productController.text = selection['productName'];
                      _priceController.text = (selection['price'] ?? 0).toString();
                    },
                    fieldViewBuilder: (ctx, controller, node, onSubmitted) {
                      controller.addListener(() => _productController.text = controller.text);
                      return _buildTextField('Product Name', Icons.shopping_basket, controller: controller, focusNode: node);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Qty', Icons.numbers, controller: _quantityController, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Price', Icons.payments, controller: _priceController, keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add to Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items List List
          if (_items.isNotEmpty)
            _buildCard(
              title: 'Purchase List',
              child: Column(
                children: [
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item['quantity']} x ₹${item['price']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${(item['total'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeItem(index)),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(thickness: 1, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Payment + Note + Attachment Card
          _buildCard(
            title: 'Payment & Documents',
            child: Column(
              children: [
                _buildTextField('Total Paid', Icons.account_balance_wallet, controller: _paidController, keyboardType: TextInputType.number, onChanged: (v) => _calculateRemaining()),
                const SizedBox(height: 12),
                _buildTextField('Remaining Balance', Icons.pending_actions, controller: _remainingController, keyboardType: TextInputType.number, enabled: false),
                const SizedBox(height: 12),
                _buildTextField('Note / Remarks (optional)', Icons.sticky_note_2_outlined, controller: _noteController),
                const SizedBox(height: 16),
                // --- Document Attachment Button ---
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                    if (result != null) {
                      setState(() {
                        _attachedFileNames.addAll(result.files.map((f) => f.name));
                      });
                    }
                  },
                  icon: const Icon(Icons.attach_file, color: AppColors.primary),
                  label: const Text('Attach Documents', style: TextStyle(color: AppColors.primary)),
                ),
                if (_attachedFileNames.isNotEmpty) ...
                  _attachedFileNames.map((name) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                    title: Text(name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onPressed: () => setState(() => _attachedFileNames.remove(name)),
                    ),
                  )).toList(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _generateBill,
                    child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm & Save Bill', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      color: AppColors.containerBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.containerSoft,
      prefixIcon: Icon(icon, color: AppColors.primary),
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, FocusNode? focusNode, TextInputType keyboardType = TextInputType.text, Function(String)? onChanged, bool enabled = true}) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: enabled,
      style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textSecondary),
      decoration: _inputDecoration(label, icon),
      keyboardType: keyboardType,
    );
  }
}
