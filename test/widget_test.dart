import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_market/main.dart';

void main() {
  testWidgets('shows the marketplace home screen', (tester) async {
    await tester.pumpWidget(const NpMarketApp());

    expect(find.text('FLASH SALE'), findsOneWidget);
    expect(find.text('Mall'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);

    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProductCard).first);
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดสินค้า'), findsWidgets);
    expect(find.text('ใส่ตะกร้า'), findsOneWidget);
    expect(find.text('ซื้อเลย'), findsOneWidget);

    await tester.tap(find.text('ใส่ตะกร้า'));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มไปยังรถเข็น'), findsOneWidget);

    await tester.tap(find.text('เพิ่มไปยังรถเข็น'));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มสินค้าในตะกร้าแล้ว'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('ตะกร้า'), findsWidgets);

    await tester.tap(find.byType(CartCheckBox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('ทำการสั่งซื้อ'), findsOneWidget);

    await tester.tap(find.text('สั่งสินค้า'));
    await tester.pumpAndSettle();
    expect(find.text('ชำระเงิน'), findsOneWidget);

    await tester.tap(find.text('ยืนยันชำระเงิน'));
    await tester.pumpAndSettle();
    expect(find.text('สั่งซื้อสำเร็จ'), findsOneWidget);

    await tester.tap(find.text('ดูรายละเอียดคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดคำสั่งซื้อ'), findsOneWidget);
  });
}
