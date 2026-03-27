import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {

  /// Helper to launch a native SMS. Uses [LaunchMode.externalNonBrowserApplication]
  /// to prevent apps like WhatsApp from intercepting the sms: URI.
  static Future<void> _launchSms(String phone, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{'body': message},
    );
    try {
      // externalNonBrowserApplication forces the OS to pick a dedicated SMS app
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        debugPrint("Cannot launch SMS on this device.");
      }
    } catch (e) {
      debugPrint("Could not launch SMS: $e");
    }
  }

  /// Helper to launch a mailto: link so the device opens an email app.
  static Future<void> _launchEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("No email app found on this device.");
      }
    } catch (e) {
      debugPrint("Could not launch Email: $e");
    }
  }

  static Future<void> sendWelcomeNotification({
    required String customerName,
    required String phone,
    required String shopName,
  }) async {
    final message = "Welcome to $shopName! You have been registered as a customer. Your login is your phone number.";
    await _launchSms(phone, message);
  }

  static Future<void> sendBillNotification({
    required String phone,
    required List<Map<String, dynamic>> items,
    required double totalBill,
    required double paid,
    required double remainingDue,
    required double totalOutstandingBalance,
  }) async {
    final date = DateTime.now().toString().split('.')[0];

    // Keep SMS concise for readability
    String itemsSummary = items.map((item) => "${item['productName']} (x${item['quantity']})").join(", ");
    if (itemsSummary.length > 60) {
      itemsSummary = "${itemsSummary.substring(0, 57)}...";
    }

    final smsMessage = '''BILL DETAILS:
Items: $itemsSummary
Total: Rs.$totalBill | Paid: Rs.$paid
Remaining: Rs.$remainingDue
TOTAL DUE: Rs.$totalOutstandingBalance
Date: $date''';

    await _launchSms(phone, smsMessage);
  }

  static Future<void> sendEmailNotification({
    required String email,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    required double totalOutstanding,
  }) async {
    final date = DateTime.now().toString().split('.')[0];
    final subject = "Invoice for your purchase at Credit Trust";

    String itemRows = items.map((item) {
      return "- ${item['productName']} x ${item['quantity']} @ Rs.${item['price']} = Rs.${(item['total'] as double).toStringAsFixed(2)}";
    }).join("\n");

    final body = '''Hello $customerName,

Your bill has been generated successfully.

DETAILS:
Date: $date

ITEMS PURCHASED:
$itemRows

--------------------------
Total Amount: Rs.${totalAmount.toStringAsFixed(2)}
Paid Amount: Rs.${paidAmount.toStringAsFixed(2)}
Remaining Amount (this bill): Rs.${remainingAmount.toStringAsFixed(2)}

TOTAL OUTSTANDING BALANCE: Rs.${totalOutstanding.toStringAsFixed(2)}

Thank you for your business!
''';

    await _launchEmail(email: email, subject: subject, body: body);
  }

  static Future<void> sendPaymentNotification({
    required String phone,
    required double amountPaid,
    required double newRemainingDue,
  }) async {
    final message = '''Payment received:
Amount: Rs.$amountPaid
Remaining Due: Rs.$newRemainingDue''';
    await _launchSms(phone, message);
  }

  static Future<void> sendDailyReminder({
    required String phone,
    required double limitDue,
  }) async {
    final message = "Reminder: Your outstanding payment of Rs.$limitDue is due. Please clear it at the earliest.";
    await _launchSms(phone, message);
  }
}
