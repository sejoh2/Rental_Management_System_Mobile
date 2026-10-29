import 'package:caretaker_app/features/tenants/record_payment_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M-Pesa money needs its receipt number', () {
    expect(receiptProblem('mpesa', ''), 'Enter the M-Pesa receipt number.');
    expect(receiptProblem('mpesa', '  '), 'Enter the M-Pesa receipt number.');
    expect(receiptProblem('mpesa', 'TJU4K8P2QX'), isNull);
    expect(receiptProblem('mpesa', 'tju4 k8p2 qx'), isNull);
    expect(receiptProblem('mpesa', 'ABC'), isNotNull);
    expect(receiptProblem('mpesa', 'TJU4K8P2Q#'), isNotNull);
  });

  test('cash, bank and other payments do not need one', () {
    expect(receiptProblem('cash', ''), isNull);
    expect(receiptProblem('bank', ''), isNull);
    expect(receiptProblem('other', 'anything'), isNull);
  });

  test('the receipt is sent as the server keeps it', () {
    expect(normalizeReceipt(' tju4 k8p2qx '), 'TJU4K8P2QX');
  });
}
