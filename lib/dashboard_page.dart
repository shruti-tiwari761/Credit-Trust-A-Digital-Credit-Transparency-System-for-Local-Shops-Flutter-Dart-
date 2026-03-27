import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'drawer_menu.dart';
import 'home_page.dart';
import 'add_customer_page.dart';
import 'add_stock_page.dart';
import 'generate_bill_page.dart';
import 'jama_credit_page.dart';
import 'remaining_due_page.dart';
import 'profile_page.dart';
import 'change_password_page.dart';
import 'analytics_page.dart';
import 'reminder_page.dart';
import 'dispute_page.dart';
import 'document_library_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _username = 'Admin';
  bool _isLoading = true;
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),           // 0
    const AddCustomerPage(),    // 1
    const AddStockPage(),       // 2
    const GenerateBillPage(),   // 3
    const JamaCreditPage(),     // 4
    const RemainingDuePage(),   // 5
    const AnalyticsPage(),      // 6
    const ReminderPage(),       // 7
    const ProfilePage(),        // 8
    const ChangePasswordPage(), // 9
    const DisputePage(),        // 10
    const DocumentLibraryPage(), // 11
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _username = data['name'] ?? currentUser!.email?.split('@')[0] ?? 'Admin';
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: \$e");
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _onMenuItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        title: Text(
          [
            'Dashboard', 'Add Customer', 'Add Stock', 'Generate Bill',
            'Jama Credit', 'Remaining Dues', 'Analytics', 'Daily Reminder',
            'Admin Profile', 'Change Password', 'Dispute Management', 'Document Library',
          ][_selectedIndex],
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      drawer: DrawerMenu(
        selectedIndex: _selectedIndex,
        onItemSelected: _onMenuItemSelected,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/loginbg.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Only show welcome header on the Home Tab
                  if (_selectedIndex == 0)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.containerBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(_username.isNotEmpty ? _username[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, $_username!',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Text(
                                    'Manage your shop efficiently',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: _pages[_selectedIndex],
                  ),
                ],
              ),
      ),
    );
  }
}
