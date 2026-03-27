import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';
import 'login_page.dart';

class CustomerDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String customerName;
  final String shopName;

  const CustomerDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.customerName,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppColors.creamBg,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              accountName: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(shopName),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                  style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(context, 'Home', Icons.home, 0),
                  _buildDrawerItem(context, 'Bill History', Icons.receipt_long, 1),
                  _buildDrawerItem(context, 'Credit Record', Icons.account_balance, 2),
                  _buildDrawerItem(context, 'Raise Dispute', Icons.gavel, 3),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, int index) {
    final isSelected = selectedIndex == index;
    return Container(
      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
        title: Text(title, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        onTap: () {
          Navigator.pop(context); // Close drawer
          onItemSelected(index);
        },
      ),
    );
  }
}
