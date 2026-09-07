// 数据模型（与后端 schemas.py 对应）

class User {
  final int id;
  final String phone;
  final String nickname;

  User({required this.id, required this.phone, required this.nickname});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json["id"],
        phone: json["phone"],
        nickname: json["nickname"],
      );
}

class Ledger {
  final int id;
  final String name;
  final String inviteCode;
  final String role;
  final int memberCount;

  Ledger({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.role,
    required this.memberCount,
  });

  factory Ledger.fromJson(Map<String, dynamic> json) => Ledger(
        id: json["id"],
        name: json["name"],
        inviteCode: json["invite_code"],
        role: json["role"],
        memberCount: json["member_count"],
      );
}

class Category {
  final int id;
  final String name;
  final String type;
  final String icon;

  Category({required this.id, required this.name, required this.type, required this.icon});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json["id"],
        name: json["name"],
        type: json["type"],
        icon: json["icon"],
      );
}

class Tx {
  final int id;
  final int ledgerId;
  final int createdBy;
  final String creatorName;
  final int? categoryId;
  final String categoryName;
  final String type; // expense / income
  final double amount;
  final DateTime date;
  final String note;
  final String source; // manual / ai / salary

  Tx({
    required this.id,
    required this.ledgerId,
    required this.createdBy,
    required this.creatorName,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.amount,
    required this.date,
    required this.note,
    required this.source,
  });

  factory Tx.fromJson(Map<String, dynamic> json) => Tx(
        id: json["id"],
        ledgerId: json["ledger_id"],
        createdBy: json["created_by"],
        creatorName: json["creator_name"] ?? "",
        categoryId: json["category_id"],
        categoryName: json["category_name"],
        type: json["type"],
        amount: (json["amount"] as num).toDouble(),
        date: DateTime.parse(json["date"]),
        note: json["note"] ?? "",
        source: json["source"] ?? "manual",
      );
}

class Summary {
  final String month;
  final double income;
  final double expense;
  final double balance;

  Summary({required this.month, required this.income, required this.expense, required this.balance});

  factory Summary.fromJson(Map<String, dynamic> json) => Summary(
        month: json["month"],
        income: (json["income"] as num).toDouble(),
        expense: (json["expense"] as num).toDouble(),
        balance: (json["balance"] as num).toDouble(),
      );
}

class CategoryStat {
  final String categoryName;
  final String icon;
  final double amount;
  final int count;

  CategoryStat({required this.categoryName, required this.icon, required this.amount, required this.count});

  factory CategoryStat.fromJson(Map<String, dynamic> json) => CategoryStat(
        categoryName: json["category_name"],
        icon: json["icon"],
        amount: (json["amount"] as num).toDouble(),
        count: json["count"],
      );
}

class DailyStat {
  final String date;
  final double expense;
  final double income;

  DailyStat({required this.date, required this.expense, required this.income});

  factory DailyStat.fromJson(Map<String, dynamic> json) => DailyStat(
        date: json["date"],
        expense: (json["expense"] as num).toDouble(),
        income: (json["income"] as num).toDouble(),
      );
}

class MemberStat {
  final int userId;
  final String nickname;
  final double expense;
  final double income;

  MemberStat({required this.userId, required this.nickname, required this.expense, required this.income});

  factory MemberStat.fromJson(Map<String, dynamic> json) => MemberStat(
        userId: json["user_id"],
        nickname: json["nickname"],
        expense: (json["expense"] as num).toDouble(),
        income: (json["income"] as num).toDouble(),
      );
}

class MonthlyStat {
  final String month;
  final double income;
  final double expense;

  MonthlyStat({required this.month, required this.income, required this.expense});

  factory MonthlyStat.fromJson(Map<String, dynamic> json) => MonthlyStat(
        month: json["month"],
        income: (json["income"] as num).toDouble(),
        expense: (json["expense"] as num).toDouble(),
      );
}

/// AI 解析出的记账草稿
class DraftItem {
  String type;
  double amount;
  String categoryName;
  DateTime date;
  String note;

  DraftItem({
    required this.type,
    required this.amount,
    required this.categoryName,
    required this.date,
    required this.note,
  });

  factory DraftItem.fromJson(Map<String, dynamic> json) => DraftItem(
        type: json["type"],
        amount: (json["amount"] as num).toDouble(),
        categoryName: json["category_name"],
        date: DateTime.parse(json["date"]),
        note: json["note"] ?? "",
      );
}

class SalaryRule {
  final int id;
  final int ledgerId;
  final String name;
  final double amount;
  final int payDay;
  final bool active;
  final String? lastRun;

  SalaryRule({
    required this.id,
    required this.ledgerId,
    required this.name,
    required this.amount,
    required this.payDay,
    required this.active,
    required this.lastRun,
  });

  factory SalaryRule.fromJson(Map<String, dynamic> json) => SalaryRule(
        id: json["id"],
        ledgerId: json["ledger_id"],
        name: json["name"],
        amount: (json["amount"] as num).toDouble(),
        payDay: json["pay_day"],
        active: json["active"],
        lastRun: json["last_run"],
      );
}
