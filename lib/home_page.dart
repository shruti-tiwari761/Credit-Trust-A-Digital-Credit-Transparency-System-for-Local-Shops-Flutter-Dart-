import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';
import 'firebase_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return const Center(child: Text('User not logged in'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: firebaseService.getCustomers(),
            builder: (context, customerSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('isolated_data')
                    .doc('transactions')
                    .collection('list')
                    .snapshots(),
                builder: (context, transSnapshot) {
                  int totalCustomers = customerSnapshot.hasData ? customerSnapshot.data!.docs.length : 0;
                  double totalCreditGiven = 0;
                  double totalPaid = 0;

                  if (customerSnapshot.hasData) {
                    for (var doc in customerSnapshot.data!.docs) {
                      totalCreditGiven += (doc.data() as Map<String, dynamic>)['creditLimit'] ?? 0.0;
                    }
                  }

                  if (transSnapshot.hasData) {
                    for (var doc in transSnapshot.data!.docs) {
                      totalPaid += (doc.data() as Map<String, dynamic>)['amountPaid'] ?? 0.0;
                    }
                  }

                  double remainingDue = totalCreditGiven; // Simplified: creditLimit is the balance

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16.0,
                    crossAxisSpacing: 16.0,
                    childAspectRatio: 1.1, // Adjusted for better fit
                    children: [
                      _buildSummaryCard('Total Customers', totalCustomers.toString(), Icons.people, Colors.blue),
                      _buildSummaryCard('Total Credit', '₹${totalCreditGiven.toStringAsFixed(0)}', Icons.trending_up, Colors.red),
                      _buildSummaryCard('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', Icons.check_circle, Colors.green),
                      _buildSummaryCard('Remaining Due', '₹${remainingDue.toStringAsFixed(0)}', Icons.warning, Colors.orange),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: AppColors.containerBg,
      elevation: 4,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Reduced vertical padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color), // Slightly smaller icon
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
