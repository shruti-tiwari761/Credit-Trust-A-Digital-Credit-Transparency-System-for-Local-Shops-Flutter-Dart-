import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'auth_service.dart';

class DrawerMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const DrawerMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    String username = currentUser?.email?.split('@')[0] ?? 'Admin';
    String email = currentUser?.email ?? 'admin@example.com';

    return Drawer(
      child: Container(
        color: AppColors.creamBg,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              accountName: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.containerBg,
                child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(context, 'Home', Icons.home, 0),
                  _buildDrawerItem(context, 'Add New Customer', Icons.person_add, 1),
                  _buildDrawerItem(context, 'Add Stock', Icons.inventory, 2),
                  _buildDrawerItem(context, 'Generate Bill', Icons.receipt, 3),
                  _buildDrawerItem(context, 'Jama Credit', Icons.account_balance_wallet, 4),
                  _buildDrawerItem(context, 'Remaining Money & Due Date', Icons.money_off, 5),
                  _buildDrawerItem(context, 'Analytics', Icons.analytics, 6),
                  _buildDrawerItem(context, 'Daily Reminder', Icons.notifications_active, 7),
                  const Divider(),
                  _buildDrawerItem(context, 'Dispute Management', Icons.gavel, 10),
                  _buildDrawerItem(context, 'Document Library', Icons.folder_special, 11),
                  const Divider(),
                  _buildDrawerItem(context, 'Admin Profile', Icons.person, 8),
                  _buildDrawerItem(context, 'Change Password', Icons.lock_reset, 9),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await AuthService().signOut();
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
