import 'package:flutter_test/flutter_test.dart';

import 'package:ai_jizhang/models.dart';

void main() {
  test("User.fromJson", () {
    final u = User.fromJson({"id": 1, "phone": "13800000000", "nickname": "小明"});
    expect(u.id, 1);
    expect(u.nickname, "小明");
  });

  test("Tx.fromJson", () {
    final t = Tx.fromJson({
      "id": 1,
      "ledger_id": 1,
      "created_by": 1,
      "creator_name": "小明",
      "category_id": null,
      "category_name": "餐饮",
      "type": "expense",
      "amount": 35.5,
      "date": "2026-09-04",
      "note": "午饭",
      "source": "ai",
    });
    expect(t.amount, 35.5);
    expect(t.categoryName, "餐饮");
    expect(t.date.year, 2026);
    expect(t.source, "ai");
  });

  test("DraftItem.fromJson", () {
    final d = DraftItem.fromJson({
      "type": "income",
      "amount": 800,
      "category_name": "二手闲置",
      "date": "2026-09-04",
      "note": "卖旧手机",
    });
    expect(d.type, "income");
    expect(d.amount, 800);
  });

  test("Summary.fromJson", () {
    final s = Summary.fromJson({
      "month": "2026-09",
      "income": 12000,
      "expense": 3560.5,
      "balance": 8439.5,
    });
    expect(s.balance, 8439.5);
  });
}
