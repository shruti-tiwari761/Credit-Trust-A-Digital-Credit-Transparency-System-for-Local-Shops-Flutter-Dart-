import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login user
  Future<UserCredential?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during login');
    }
  }

  // Get the role of a user from Firestore ('Admin' or 'Customer')
  Future<String?> getUserRole(String uid) async {
    try {
      // Check admin collection first
      final adminDoc = await _firestore.collection('users').doc(uid).get();
      if (adminDoc.exists) {
        return adminDoc.data()?['role'] as String?;
      }
      // Check customer_accounts collection
      final customerDoc = await _firestore.collection('customer_accounts').doc(uid).get();
      if (customerDoc.exists) {
        return customerDoc.data()?['role'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
    return null;
  }

  // Register Admin / Shopkeeper
  Future<UserCredential?> registerAdmin({
    required String name,
    required String email,
    required String phone,
    required String shopName,
    required String shopAddress,
    required String password,
  }) async {
    try {
      // 1. Create the user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Save additional user data in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'shopName': shopName,
          'shopAddress': shopAddress,
          'role': 'Admin', // Indicates it's an admin/shopkeeper
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during registration');
    }
  }

  /// Register a Customer from an admin's "Add Customer" flow.
  /// Uses a secondary Firebase App instance to avoid signing out the current admin.
  Future<String?> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required double creditLimit,
    required String adminUid,
    required String shopName,
    required String customerId,
  }) async {
    try {
      // Use a secondary Firebase App instance so the admin stays signed in
      final FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create customer Firebase Auth account using secondary auth
      // email = customer email, password = customer phone number
      final UserCredential customerCred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: phone, // phone number as initial password
      );

      final String customerUid = customerCred.user!.uid;

      // Save customer profile in top-level 'customer_accounts' collection
      await _firestore.collection('customer_accounts').doc(customerUid).set({
        'uid': customerUid,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'creditLimit': creditLimit,
        'adminUid': adminUid,
        'shopName': shopName,
        'customerId': customerId,
        'role': 'Customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clean up the secondary app instance
      await secondaryApp.delete();

      return customerUid;
    } on FirebaseAuthException catch (e) {
      // If the email already exists just return null
      if (e.code == 'email-already-in-use') {
        debugPrint("Customer account already exists for $email");
        return null;
      }
      throw Exception(e.message ?? 'Error creating customer account');
    } catch (e) {
      // Try to clean up secondary app on failure
      try { await Firebase.app('SecondaryApp').delete(); } catch (_) {}
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
