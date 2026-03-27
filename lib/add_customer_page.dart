import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _notificationsEnabled = true;
  bool _isSaving = false;

  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  Future<void> _saveCustomer() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name, phone number, and email')),
      );
      return;
    }

    if (_phoneController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be at least 6 digits (used as login password)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final customerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'creditLimit': 0.0, // Start with zero credit balance
        'notificationEnabled': _notificationsEnabled,
      };

      // 1. Save customer under admin's Firestore collection
      final docRef = await _firebaseService.addCustomerAndGetRef(customerData);
      final customerId = docRef.id;

      // 2. Fetch admin info
      final adminUser = FirebaseAuth.instance.currentUser;
      String shopName = "Your Shop";
      if (adminUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(adminUser.uid).get();
        if (userDoc.exists) {
          shopName = userDoc.data()?['shopName'] ?? "Your Shop";
        }
      }

      // 3. Create Firebase Auth account for the customer
      //    username = email, password = phone number
      final String? customerUid = await _authService.registerCustomer(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        creditLimit: 0.0,
        adminUid: adminUser?.uid ?? '',
        shopName: shopName,
        customerId: customerId,
      );

      if (customerUid != null) {
        // 4. Update Firestore customer doc with the customer's UID
        await docRef.update({'customerAuthUid': customerUid});
        debugPrint("Customer Firebase account created: $customerUid");
      } else {
        debugPrint("Customer already has an account – skipped creation.");
      }

      // 5. Send notification
      if (_notificationsEnabled) {
        await NotificationService.sendWelcomeNotification(
          customerName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          shopName: shopName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            customerUid != null
              ? 'Customer added! Login: ${_emailController.text.trim()} / ${_phoneController.text.trim()}'
              : 'Customer added (account already existed).',
            style: const TextStyle(color: Colors.white),
          ), backgroundColor: Colors.green),
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
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Customer will use their Email & Phone Number to login.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _buildTextField('Customer Name', Icons.person, controller: _nameController),
              const SizedBox(height: 16),
              _buildTextField('Phone Number (Login Password)', Icons.phone, controller: _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField('Email (Login Username)', Icons.email, controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField('Address', Icons.location_on, controller: _addressController),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Notifications', style: TextStyle(color: AppColors.textPrimary)),
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
                activeColor: AppColors.primary,
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
                  onPressed: _isSaving ? null : _saveCustomer,
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Customer', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
