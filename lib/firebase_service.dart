import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current Admin's isolated specific collection reference
  CollectionReference _adminCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User is not logged in!");
    return _firestore.collection('users').doc(uid).collection('isolated_data');
  }

  // Customers
  Future<void> addCustomer(Map<String, dynamic> customerData) async {
    try {
      customerData['createdAt'] = FieldValue.serverTimestamp();
      await _adminCollection().doc('customers').collection('list').add(customerData);
    } catch (e) {
      debugPrint("Error adding customer: \$e");
      rethrow;
    }
  }

  Stream<QuerySnapshot> getCustomers() {
    return _adminCollection().doc('customers').collection('list').orderBy('createdAt', descending: true).snapshots();
  }

  // Add customer and return the DocumentReference (used to get the doc ID for customer auth linking)
  Future<DocumentReference> addCustomerAndGetRef(Map<String, dynamic> customerData) async {
    try {
      customerData['createdAt'] = FieldValue.serverTimestamp();
      return await _adminCollection().doc('customers').collection('list').add(customerData);
    } catch (e) {
      debugPrint("Error adding customer: $e");
      rethrow;
    }
  }

  
  // Bills & Credit modification - Returns the new total balance
  Future<double> generateBill(String customerId, Map<String, dynamic> billData, double totalAmount, double remainingAmount) async {
    try {
      final batch = _firestore.batch();
      final serverTimestamp = FieldValue.serverTimestamp();
      
      // 1. Save Bill in Admin's isolated collection
      billData['createdAt'] = serverTimestamp;
      final billRef = _adminCollection().doc('bills').collection('list').doc();
      batch.set(billRef, billData);
      
      // 2. Update Customer Credit in Admin's collection
      final customerRef = _adminCollection().doc('customers').collection('list').doc(customerId);
      batch.update(customerRef, {
        'creditLimit': FieldValue.increment(remainingAmount) // Here creditLimit is actually the "Due Balance"
      });
      
      // 3. Synchronize with Customer's own dashboard collection
      // First, get the customer's Auth UID from the admin's customer record
      final customerDoc = await customerRef.get();
      if (customerDoc.exists) {
        final String? customerAuthUid = customerDoc.get('customerAuthUid');
        if (customerAuthUid != null) {
          final customerAccountRef = _firestore.collection('customer_accounts').doc(customerAuthUid);
          
          // Save a copy of the bill for the customer to see
          final customerBillRef = customerAccountRef.collection('bills').doc(billRef.id);
          batch.set(customerBillRef, {
            ...billData,
            'adminUid': _auth.currentUser?.uid, // Keep track of which shop sent the bill
          });
          
          // Update the balance in the customer's profile record
          batch.update(customerAccountRef, {
            'creditLimit': FieldValue.increment(remainingAmount)
          });
        }
      }
      
      await batch.commit();

      // Get the final updated balance to return for notifications
      final updatedDoc = await customerRef.get();
      return (updatedDoc.get('creditLimit') ?? 0.0).toDouble();
    } catch (e) {
      debugPrint("Error generating bill: $e");
      rethrow;
    }
  }
  
  // Jama Credit / Repayment
  Future<void> jamaCredit(String customerId, double amountPaid, DateTime paymentDate) async {
      try {
        final batch = _firestore.batch();
        
        // Save Transaction
        final transRef = _adminCollection().doc('transactions').collection('list').doc();
        batch.set(transRef, {
          'customerId': customerId,
          'amountPaid': amountPaid,
          'date': Timestamp.fromDate(paymentDate),
          'type': 'jama_credit',
          'createdAt': FieldValue.serverTimestamp()
        });

        // Reduce Pending Credit in Admin's collection
        final customerRef = _adminCollection().doc('customers').collection('list').doc(customerId);
        batch.update(customerRef, {
           'creditLimit': FieldValue.increment(-amountPaid) 
        });

        // --- FIX: Also sync balance in customer_accounts so dashboard updates ---
        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final String? customerAuthUid = customerDoc.get('customerAuthUid');
          if (customerAuthUid != null) {
            final customerAccountRef = _firestore.collection('customer_accounts').doc(customerAuthUid);
            batch.update(customerAccountRef, {
              'creditLimit': FieldValue.increment(-amountPaid),
            });
          }
        }

        await batch.commit();
      } catch (e) {
        debugPrint("Error paying credit: \$e");
        rethrow;
      }
  }
}
