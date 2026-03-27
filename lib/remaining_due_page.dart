import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class RemainingDuePage extends StatelessWidget {
  const RemainingDuePage({super.key});

  String _formatAmount(dynamic val) {
    if (val == null) return '0.00';
    return (val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0)
        .toStringAsFixed(2);
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    return val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return StreamBuilder<QuerySnapshot>(
      stream: firebaseService.getCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final customers = snapshot.data!.docs;
        final withDues = customers.where((d) => _toDouble((d.data() as Map)['creditLimit']) > 0).toList();

        // Summary header
        final totalDue = withDues.fold<double>(0, (sum, d) => sum + _toDouble((d.data() as Map)['creditLimit']));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- Summary Banner ---
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade800, Colors.red.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Outstanding', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('₹${_formatAmount(totalDue)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      Text('${withDues.length} customer(s) with dues',
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // --- Customer Cards ---
            ...customers.map((doc) {
              final customer = doc.data() as Map<String, dynamic>;
              final double remaining = _toDouble(customer['creditLimit']);
              final bool isPaid = remaining <= 0;

              String dueDate = 'N/A';
              if (customer['createdAt'] != null) {
                final DateTime created = (customer['createdAt'] as Timestamp).toDate();
                dueDate = created.add(const Duration(days: 30)).toString().split(' ')[0];
              }

              final bool isOverdue = !isPaid && customer['createdAt'] != null &&
                  (customer['createdAt'] as Timestamp).toDate().add(const Duration(days: 30)).isBefore(DateTime.now());

              return Card(
                color: AppColors.containerBg,
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    // Main tile
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: isPaid
                                ? Colors.green.shade900.withOpacity(0.3)
                                : (isOverdue ? Colors.red.shade900.withOpacity(0.3) : Colors.orange.shade900.withOpacity(0.3)),
                            child: Text(
                              (customer['name'] ?? 'U').toString()[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? Colors.greenAccent : (isOverdue ? Colors.redAccent : Colors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        customer['name'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    if (isOverdue)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                        child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(customer['phone'] ?? '',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Amount row
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.containerSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Outstanding Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(
                                '₹${_formatAmount(remaining)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Due Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(
                                isPaid ? '—' : dueDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue ? Colors.redAccent : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isPaid ? 'Paid' : (isOverdue ? 'Overdue' : 'Pending'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    if (!isPaid)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.sms_outlined, color: Colors.orange, size: 18),
                            label: const Text('Send Reminder', style: TextStyle(color: Colors.orange, fontSize: 13)),
                            onPressed: () async {
                              if (customer['phone'] != null) {
                                await NotificationService.sendDailyReminder(
                                  phone: customer['phone'],
                                  limitDue: remaining,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Reminder SMS triggered!')));
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('All Cleared!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Text('No outstanding dues at this time.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showDisputeDialog(BuildContext context, String customerId, Map<String, dynamic> customer) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.containerBg,
        title: Row(
          children: [
            const Icon(Icons.gavel, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('Dispute: ${customer['name']}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reason for dispute:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.containerSoft,
                hintText: 'e.g. Customer claims bill amount is incorrect...',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              // Save dispute to Firestore
              await FirebaseFirestore.instance
                  .collection('disputes')
                  .add({
                'customerId': customerId,
                'customerName': customer['name'],
                'reason': reasonController.text.trim(),
                'status': 'open',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dispute filed successfully!'), backgroundColor: Colors.blueAccent),
                );
              }
            },
            child: const Text('Submit Dispute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
