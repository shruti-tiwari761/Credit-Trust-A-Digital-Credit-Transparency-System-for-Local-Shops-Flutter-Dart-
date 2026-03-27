import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class JamaCreditPage extends StatefulWidget {
  const JamaCreditPage({super.key});

  @override
  State<JamaCreditPage> createState() => _JamaCreditPageState();
}

class _JamaCreditPageState extends State<JamaCreditPage> {
  String? _selectedCustomerId;
  String? _selectedCustomerPhone;
  double _currentLimit = 0;
  final _amountController = TextEditingController();
  final _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    // Rebuild UI live as the admin types in the payment amount
    _amountController.addListener(() => setState(() {}));
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = picked.toString().split(' ')[0];
      });
    }
  }

  Future<void> _savePayment() async {
    if (_selectedCustomerId == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer and enter amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double amountPaid = double.tryParse(_amountController.text) ?? 0.0;
      
      await _firebaseService.jamaCredit(_selectedCustomerId!, amountPaid, _selectedDate);

      if (_selectedCustomerPhone != null) {
        await NotificationService.sendPaymentNotification(
          phone: _selectedCustomerPhone!,
          amountPaid: amountPaid,
          newRemainingDue: _currentLimit - amountPaid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
        _clearFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e')),
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
      _currentLimit = 0;
    });
    _amountController.clear();
    _dateController.text = DateTime.now().toString().split(' ')[0];
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: AppColors.containerBg,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: _firebaseService.getCustomers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  
                  var customers = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.containerSoft,
                      prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                      labelText: 'Select Customer',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    value: _selectedCustomerId,
                    items: customers.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['name'] ?? 'Unknown'),
                        onTap: () {
                          _selectedCustomerPhone = data['phone'];
                          _currentLimit = (data['creditLimit'] ?? 0).toDouble();
                        },
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCustomerId = val),
                  );
                }
              ),
              const SizedBox(height: 16),

              // --- Current Due Banner (shows only after selecting a customer) ---
              if (_selectedCustomerId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _currentLimit > 0
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.green.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentLimit > 0 ? Colors.redAccent : Colors.greenAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Outstanding Due',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_currentLimit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _currentLimit > 0 ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _currentLimit > 0 ? Icons.account_balance_wallet : Icons.check_circle,
                        color: _currentLimit > 0 ? Colors.redAccent : Colors.greenAccent,
                        size: 40,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              _buildTextField('Amount Paying Now (₹)', Icons.currency_rupee, controller: _amountController, keyboardType: TextInputType.number),

              // --- Shows remaining balance dynamically ---
              if (_selectedCustomerId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Balance after payment: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(
                        '₹${(_currentLimit - (double.tryParse(_amountController.text) ?? 0)).toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: IgnorePointer(
                  child: _buildTextField('Payment Date', Icons.calendar_today, controller: _dateController),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _savePayment,
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Payment', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {TextEditingController? controller, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.containerSoft,
        prefixIcon: Icon(icon, color: AppColors.primary),
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      keyboardType: keyboardType,
    );
  }
}
