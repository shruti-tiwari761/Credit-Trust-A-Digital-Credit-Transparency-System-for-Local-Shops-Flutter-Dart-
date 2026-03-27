import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'app_colors.dart';
import 'login_page.dart';
import 'customer_drawer.dart';
import 'local_notification_service.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _customerName = 'Customer';
  String _shopName = 'Your Shop';
  String _adminUid = '';
  bool _isLoading = true;
  int _selectedIndex = 0;
  StreamSubscription? _billSubscription;
  int _lastBillCount = -1; // -1 means not yet initialized

  @override
  void initState() {
    super.initState();
    _fetchCustomerProfile();
    // Request notification permission as soon as the customer opens the app
    LocalNotificationService.initialize();
  }

  Future<void> _fetchCustomerProfile() async {
    if (currentUser == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('customer_accounts')
          .doc(currentUser!.uid);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _customerName = data['name'] ?? 'Customer';
          _shopName = data['shopName'] ?? 'Your Shop';
          _adminUid = data['adminUid'] ?? '';
        });
        _startBillListener(); // Start listening for new bills
      }
    } catch (e) {
      debugPrint("Error fetching customer profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startBillListener() {
    if (currentUser == null) return;
    _billSubscription?.cancel();
    _billSubscription = FirebaseFirestore.instance
        .collection('customer_accounts')
        .doc(currentUser!.uid)
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.length;
      // Only notify if there are MORE bills than before (new bill arrived)
      if (_lastBillCount >= 0 && count > _lastBillCount && snapshot.docs.isNotEmpty) {
        final latestData = snapshot.docs.first.data();
        final totalAmount = (latestData['totalAmount'] ?? 0).toDouble();
        final remaining = (latestData['remainingAmount'] ?? 0).toDouble();
        final totalDue = (latestData['totalAmount'] ?? 0).toDouble(); // Updated in profile
        LocalNotificationService.showBillNotification(
          customerName: _shopName,
          totalAmount: totalAmount,
          remaining: remaining,
          totalDue: totalDue,
        );
      }
      _lastBillCount = count;
    });
  }

  @override
  void dispose() {
    _billSubscription?.cancel();
    super.dispose();
  }

  Stream<QuerySnapshot> _getBillHistory() {
    if (_adminUid.isEmpty) return const Stream.empty();
    final customerAccountDoc = FirebaseFirestore.instance
        .collection('customer_accounts')
        .doc(currentUser!.uid);
    return customerAccountDoc.collection('bills').orderBy('createdAt', descending: true).snapshots();
  }

  Stream<DocumentSnapshot> _getStatsStream() {
    if (currentUser == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('customer_accounts')
        .doc(currentUser!.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        title: Text(
          ['Customer Dashboard', 'Bill History', 'Credit Record', 'Raise Dispute'][_selectedIndex],
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
            tooltip: 'Notifications',
            onPressed: () => _showNotificationsPanel(context),
          ),
        ],
      ),
      drawer: CustomerDrawer(
        selectedIndex: _selectedIndex,
        customerName: _customerName,
        shopName: _shopName,
        onItemSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeFragment(),
          _buildBillHistoryFragment(),
          _buildCreditRecordFragment(),
          _buildRaiseDisputeFragment(),
        ],
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.containerBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.4), borderRadius: BorderRadius.circular(4)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Bills stream
              Expanded(
                child: currentUser == null
                    ? const Center(child: Text('Not logged in'))
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('customer_accounts')
                            .doc(currentUser!.uid)
                            .collection('bills')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none, size: 60, color: AppColors.primary.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  const Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final data = docs[i].data() as Map<String, dynamic>;
                              final total = (data['totalAmount'] is num ? data['totalAmount'] : double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0) as double;
                              final paid = (data['totalPaid'] is num ? data['totalPaid'] : double.tryParse(data['totalPaid']?.toString() ?? '0') ?? 0.0) as double;
                              final remaining = (data['remainingAmount'] is num ? data['remainingAmount'] : double.tryParse(data['remainingAmount']?.toString() ?? '0') ?? 0.0) as double;
                              final date = data['createdAt'] != null
                                  ? (data['createdAt'] as dynamic).toDate().toString().split(' ')[0]
                                  : 'Unknown date';
                              final isSettled = remaining <= 0;

                              return Card(
                                color: AppColors.screenBg,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSettled ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSettled ? Icons.check_circle_outline : Icons.receipt_long,
                                      color: isSettled ? Colors.greenAccent : Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    'Bill of ₹${total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    'Paid: ₹${paid.toStringAsFixed(2)}  •  Due: ₹${remaining.toStringAsFixed(2)}\n$date',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSettled ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isSettled ? 'Settled' : 'Pending',
                                      style: TextStyle(
                                        color: isSettled ? Colors.greenAccent : Colors.orange,
                                        fontWeight: FontWeight.bold, fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeFragment() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Text(
                    _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Welcome, $_customerName!',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_shopName,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _getStatsStream(),
              builder: (context, snapshot) {
                double creditLimit = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  creditLimit = (data['creditLimit'] ?? 0).toDouble();
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Outstanding Credit',
                        '₹${creditLimit.toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                        creditLimit > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Shop Name',
                        _shopName,
                        Icons.store,
                        AppColors.primary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildBillList(limit: 5),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBillHistoryFragment() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(child: _buildBillList()),
      ],
    );
  }

  Widget _buildBillList({int? limit}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getBillHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 60, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No bills found', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            ),
          );
        }
        
        var docs = snapshot.data!.docs;
        if (limit != null && docs.length > limit) {
          docs = docs.sublist(0, limit);
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: limit != null ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final date = data['createdAt'] != null
                ? (data['createdAt'] as dynamic).toDate().toString().split(' ')[0]
                : 'Unknown date';
            return Card(
              color: AppColors.containerBg,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _showBillDetails(data),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.receipt, color: Colors.white),
                ),
                title: Text(
                    // Show items summary if available, else fallback to 'product'
                    () {
                      final items = data['items'] as List?;
                      if (items != null && items.isNotEmpty) {
                        return items.map((i) => i['productName']).join(', ');
                      }
                      return data['product'] ?? 'Bill';
                    }(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                subtitle: Text(date, style: const TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ),
            );
          },
        );
      },
    );
  }

  void _showBillDetails(Map<String, dynamic> data) {
    final date = data['createdAt'] != null
        ? (data['createdAt'] as dynamic).toDate().toString()
        : 'Unknown';
    
    final List<dynamic> items = data['items'] ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bill Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const Divider(),
                if (items.isEmpty && data['product'] != null) // Fallback for old bills
                   _buildDetailRow(data['product'], '₹${(data['totalAmount'] ?? 0).toStringAsFixed(2)}'),
                
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("${item['productName']} x ${item['quantity']}", style: const TextStyle(fontSize: 13))),
                      Text("₹${(item['total'] as double).toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
                const Divider(thickness: 1, height: 24),
                _buildDetailRow('Grand Total', '₹${(data['totalAmount'] ?? 0).toStringAsFixed(2)}', isBold: true),
                _buildDetailRow('Paid', '₹${(data['totalPaid'] ?? 0).toStringAsFixed(2)}', color: Colors.green),
                _buildDetailRow('Remaining', '₹${(data['remainingAmount'] ?? 0).toStringAsFixed(2)}', color: Colors.red, isBold: true),
                const Divider(),
                _buildDetailRow('Date', date, isSmall: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isSmall = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: isSmall ? 12 : 14)),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isSmall ? 12 : 14,
            color: color ?? AppColors.textPrimary,
          )),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: AppColors.containerBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Credit Record Fragment ──────────────────────────────────
  Widget _buildCreditRecordFragment() {
    if (currentUser == null) return const Center(child: Text('Not logged in.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customer_accounts')
          .doc(currentUser!.uid)
          .collection('bills')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 70, color: AppColors.primary.withOpacity(0.3)),
                const SizedBox(height: 12),
                const Text('No Credit Records Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Text('Your transaction history will appear here.', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        // Running total
        double totalDue = 0;
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final rem = data['remainingAmount'];
          totalDue += rem is num ? rem.toDouble() : double.tryParse(rem?.toString() ?? '0') ?? 0.0;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 36),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Outstanding', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('₹${totalDue.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      Text('${docs.length} transaction(s)',
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // Bill-by-bill history
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final total = (data['totalAmount'] is num ? data['totalAmount'] : double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0) as double;
              final paid = (data['totalPaid'] is num ? data['totalPaid'] : double.tryParse(data['totalPaid']?.toString() ?? '0') ?? 0.0) as double;
              final remaining = (data['remainingAmount'] is num ? data['remainingAmount'] : double.tryParse(data['remainingAmount']?.toString() ?? '0') ?? 0.0) as double;
              final date = data['createdAt'] != null
                  ? (data['createdAt'] as dynamic).toDate().toString().split(' ')[0]
                  : 'Unknown';

              return Card(
                color: AppColors.containerBg,
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: remaining <= 0 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              remaining <= 0 ? 'Settled' : 'Pending',
                              style: TextStyle(
                                color: remaining <= 0 ? Colors.greenAccent : Colors.orange,
                                fontWeight: FontWeight.bold, fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildDetailRow('Total Bill', '₹${total.toStringAsFixed(2)}'),
                      _buildDetailRow('Amount Paid', '₹${paid.toStringAsFixed(2)}', color: Colors.greenAccent),
                      _buildDetailRow('Remaining Due', '₹${remaining.toStringAsFixed(2)}', isBold: true, color: remaining > 0 ? Colors.redAccent : Colors.greenAccent),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // ── Raise Dispute Fragment ──────────────────────────────────
  Widget _buildRaiseDisputeFragment() {
    final reasonController = TextEditingController();
    String selectedCategory = 'Incorrect Bill Amount';
    final categories = ['Incorrect Bill Amount', 'Payment Not Recorded', 'Duplicate Entry', 'Wrong Product', 'Other'];
    bool isSubmitting = false;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use this form to raise a dispute about your bill or credit record. Your shop owner will review and resolve it.',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Past disputes
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('disputes')
                    .where('customerId', isEqualTo: currentUser?.uid ?? '')
                    .snapshots(), // Removed .orderBy to avoid index error
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 20, child: Center(child: LinearProgressIndicator()));
                  }
                  
                  // Sort in-memory
                  final rawDocs = snap.data?.docs ?? [];
                  final docs = List<QueryDocumentSnapshot>.from(rawDocs)
                    ..sort((a, b) {
                      final aTime = (a.data() as Map)['createdAt'];
                      final bTime = (b.data() as Map)['createdAt'];
                      if (aTime == null || bTime == null) return 0;
                      return (bTime as dynamic).compareTo(aTime as dynamic);
                    });

                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Disputes', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                      const SizedBox(height: 12),
                      ...docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final createdAt = data['createdAt'] != null
                            ? (data['createdAt'] as dynamic).toDate().toString().split(' ')[0]
                            : 'Unknown';
                        final isResolved = data['status'] == 'resolved';
                        return Card(
                          color: AppColors.containerBg,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(isResolved ? Icons.check_circle : Icons.pending,
                                color: isResolved ? Colors.greenAccent : Colors.orange),
                            title: Text('${data['category'] ?? 'Dispute'}: ${data['reason'] ?? ''}', 
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), 
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Filed: $createdAt', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(isResolved ? 'Resolved: ${data['resolution'] ?? ''}' : 'Status: Waiting for shop owner',
                                    style: TextStyle(color: isResolved ? Colors.greenAccent : Colors.orange, fontSize: 12, fontWeight: isResolved ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isResolved ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(isResolved ? 'RESOLVED' : 'OPEN',
                                  style: TextStyle(color: isResolved ? Colors.greenAccent : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),

              const Text('Raise New Dispute', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
              const SizedBox(height: 12),

              // Category
              Card(
                color: AppColors.containerBg,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Category',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                    ),
                    dropdownColor: AppColors.containerBg,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setLocalState(() => selectedCategory = v ?? selectedCategory),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reason
              Card(
                color: AppColors.containerBg,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: reasonController,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Describe your dispute in detail...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 13),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.edit_note, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please describe your dispute.')));
                            return;
                          }
                          setLocalState(() => isSubmitting = true);
                          await FirebaseFirestore.instance.collection('disputes').add({
                            'customerId': currentUser?.uid ?? '',
                            'customerName': _customerName,
                            'category': selectedCategory,
                            'reason': reason,
                            'status': 'open',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          reasonController.clear();
                          setLocalState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dispute submitted successfully! Your shop owner will review it.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(isSubmitting ? 'Submitting...' : 'Submit Dispute',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
