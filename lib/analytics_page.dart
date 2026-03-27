import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';

double _num(dynamic v) {
  if (v == null) return 0.0;
  return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
}
String _fmt(double v) => v.toStringAsFixed(2);

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('User not logged in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('isolated_data')
          .doc('bills')
          .collection('list')
          .snapshots(),
      builder: (context, billSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('isolated_data')
              .doc('transactions')
              .collection('list')
              .snapshots(),
          builder: (context, transSnapshot) {
            double totalSales = 0;
            double totalOutstanding = 0;
            
            if (billSnapshot.hasData) {
              for (var doc in billSnapshot.data!.docs) {
                totalSales += _num((doc.data() as Map<String, dynamic>)['totalAmount']);
              }
            }

            double recoveryRate = 0;
            if (transSnapshot.hasData && totalSales > 0) {
                double totalPaid = 0;
                for (var doc in transSnapshot.data!.docs) {
                   totalPaid += _num((doc.data() as Map<String, dynamic>)['amountPaid']);
                }
                recoveryRate = (totalPaid / totalSales) * 100;
                totalOutstanding = totalSales - totalPaid;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Analytics Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 24),
                  _buildAnalyticsCard('Total Sales', '₹${_fmt(totalSales)}', Icons.bar_chart, Colors.blue),
                  const SizedBox(height: 16),
                  _buildAnalyticsCard('Outstanding Credit', '₹${_fmt(totalOutstanding)}', Icons.pie_chart, Colors.red),
                  const SizedBox(height: 16),
                  _buildAnalyticsCard('Recovery Rate', '${recoveryRate.toStringAsFixed(1)}%', Icons.show_chart, Colors.green),
                  const SizedBox(height: 24),
                  const Card(
                    color: AppColors.containerBg,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Detailed charts will be integrated with sync fusion charts soon.', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: AppColors.containerBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
