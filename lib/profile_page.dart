import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  
  String _email = 'Loading...';
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    if (currentUser != null) {
      _email = currentUser!.email ?? 'admin@example.com';
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = data['name'] ?? 'Admin Name';
            _phoneController.text = data['phone'] ?? 'N/A';
            _shopNameController.text = data['shopName'] ?? 'N/A';
            _shopAddressController.text = data['shopAddress'] ?? 'N/A';
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile: \$e");
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    if (currentUser == null) return;
    
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'shopName': _shopNameController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
      });
      
      setState(() {
        _isEditing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: \$e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_nameController.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 24),
                  Card(
                    color: AppColors.containerBg,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildProfileItem(Icons.person, 'Admin Name', _nameController, _isEditing),
                          const Divider(),
                          _buildProfileItem(Icons.email, 'Email', TextEditingController(text: _email), false),
                          const Divider(),
                          _buildProfileItem(Icons.phone, 'Phone', _phoneController, _isEditing),
                          const Divider(),
                          _buildProfileItem(Icons.store, 'Shop Name', _shopNameController, _isEditing),
                          const Divider(),
                          _buildProfileItem(Icons.location_on, 'Shop Address', _shopAddressController, _isEditing),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _isEditing 
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, color: Colors.white),
                              label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: _isSaving ? null : _updateProfile,
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => setState(() => _isEditing = true),
                            ),
                      ),
                      if (_isEditing) const SizedBox(width: 16),
                      if (_isEditing)
                         Expanded(
                           child: OutlinedButton(
                             style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                             onPressed: () => setState(() => _isEditing = false),
                             child: const Text('Cancel'),
                           ),
                         ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
            ),
          );
  }

  Widget _buildProfileItem(IconData icon, String label, TextEditingController controller, bool isEditable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                isEditable 
                  ? TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    )
                  : Text(controller.text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
