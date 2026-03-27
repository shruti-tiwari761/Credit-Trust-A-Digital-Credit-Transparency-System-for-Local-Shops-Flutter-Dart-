import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class ReminderPage extends StatelessWidget {
  const ReminderPage({super.key});

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    return val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
  }

  static String _fmt(dynamic val) => _toDouble(val).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return StreamBuilder<QuerySnapshot>(
      stream: firebaseService.getCustomers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final customers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _toDouble(data['creditLimit']) > 0;
        }).toList();

        if (customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 70, color: Colors.grey.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('No Pending Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Text('All customers are paid up!', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20.0),
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final doc = customers[index];
            final customer = doc.data() as Map<String, dynamic>;
            final double remaining = _toDouble(customer['creditLimit']);

            return Card(
              color: AppColors.containerBg,
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.orange.withOpacity(0.2),
                          child: const Icon(Icons.notifications_active, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                              Text(customer['phone'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Due', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text('₹${_fmt(remaining)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
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
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        label: Text(
                          'Send Reminder to ${customer['name']?.split(' ').first ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
