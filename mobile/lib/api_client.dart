import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'models.dart';

/// 全局轻量状态（demo 级别，不引入状态管理框架）
class AppState {
  static String token = "";
  static User? user;
  static List<Ledger> ledgers = [];
  static int currentLedgerId = 0;

  static Ledger? get currentLedger {
    final list = ledgers.where((l) => l.id == currentLedgerId).toList();
    return list.isEmpty ? null : list.first;
  }

  static Future<void> saveToken(String t) async {
    token = t;
    final sp = await SharedPreferences.getInstance();
    await sp.setString("token", t);
  }

  static Future<void> clear() async {
    token = "";
    user = null;
    ledgers = [];
    currentLedgerId = 0;
    final sp = await SharedPreferences.getInstance();
    await sp.remove("token");
  }

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString("token") ?? "";
    final lastLedger = sp.getInt("ledger_id") ?? 0;
    if (token.isNotEmpty) {
      try {
        await Api.refreshState();
        if (lastLedger > 0 && ledgers.any((l) => l.id == lastLedger)) {
          currentLedgerId = lastLedger;
        }
      } catch (_) {
        // token 过期等情况：静默，走登录页
        token = "";
      }
    }
  }

  // 账本切换监听：各数据页注册回调，切换账本后自动刷新数据
  static final List<void Function()> _ledgerListeners = [];

  static void onLedgerSwitched(void Function() cb) => _ledgerListeners.add(cb);

  static void offLedgerSwitched(void Function() cb) => _ledgerListeners.remove(cb);

  static Future<void> setCurrentLedger(int id) async {
    currentLedgerId = id;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt("ledger_id", id);
    for (final cb in List.of(_ledgerListeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class Api {
  static late Dio dio;

  static Future<void> init() async {
    // 服务器地址在 lib/app_config.dart（已被 .gitignore 忽略，模板见 app_config.template.dart）
    const base = kServerBaseUrl;
    dio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      // AI 解析偶发慢渠道可达 45s（后端上限），90s 保证能收到后端的友好超时提示
      receiveTimeout: const Duration(seconds: 90),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (AppState.token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer ${AppState.token}";
        }
        handler.next(options);
      },
    ));
  }

  static Future<void> setBaseUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("base_url", url);
    dio.options.baseUrl = url;
  }

  static String get baseUrl => dio.options.baseUrl;

  static Map<String, dynamic> _handle(Response resp) {
    return resp.data as Map<String, dynamic>;
  }

  /// 返回 dynamic：可能是 Map（对象）也可能是 List（数组）
  static Future<dynamic> _get(String path,
      {Map<String, dynamic>? query}) async {
    try {
      final resp = await dio.get(path, queryParameters: query);
      return resp.data;
    } on DioException catch (e) {
      throw ApiException(_err(e));
    }
  }

  static Future<Map<String, dynamic>> _post(String path, dynamic data) async {
    try {
      return _handle(await dio.post(path, data: data));
    } on DioException catch (e) {
      throw ApiException(_err(e));
    }
  }

  static Future<Map<String, dynamic>> _put(String path, dynamic data) async {
    try {
      return _handle(await dio.put(path, data: data));
    } on DioException catch (e) {
      throw ApiException(_err(e));
    }
  }

  static Future<void> _delete(String path) async {
    try {
      await dio.delete(path);
    } on DioException catch (e) {
      throw ApiException(_err(e));
    }
  }

  static String _err(DioException e) {
    final data = e.response?.data;
    if (data is Map && data["detail"] != null) return data["detail"].toString();
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return "连不上服务器，请检查地址（真机需用电脑局域网IP）";
    }
    return "请求失败：${e.message}";
  }

  // ---------- Auth ----------
  static Future<void> register(String phone, String password, String nickname) async {
    final d = await _post("/api/auth/register", {
      "phone": phone,
      "password": password,
      "nickname": nickname,
    });
    await AppState.saveToken(d["token"]);
    await refreshState();
  }

  static Future<void> login(String phone, String password) async {
    final d = await _post("/api/auth/login", {"phone": phone, "password": password});
    await AppState.saveToken(d["token"]);
    await refreshState();
  }

  static Future<void> refreshState() async {
    final me = await _get("/api/auth/me");
    AppState.user = User.fromJson(me);
    final list = await _get("/api/ledgers");
    AppState.ledgers = (list as List).map((e) => Ledger.fromJson(e)).toList();
    if (AppState.ledgers.isNotEmpty && AppState.currentLedgerId == 0) {
      await AppState.setCurrentLedger(AppState.ledgers.first.id);
    }
  }

  // ---------- Ledger ----------
  static Future<Ledger> createLedger(String name) async {
    final d = await _post("/api/ledgers", {"name": name});
    final l = Ledger.fromJson(d);
    AppState.ledgers.add(l);
    return l;
  }

  static Future<Ledger> joinLedger(String code) async {
    final d = await _post("/api/ledgers/join", {"invite_code": code});
    final l = Ledger.fromJson(d);
    AppState.ledgers.add(l);
    return l;
  }

  static Future<List<User>> members(int ledgerId) async {
    final d = await _get("/api/ledgers/$ledgerId/members");
    return (d as List).map((e) => User.fromJson(e)).toList();
  }

  // ---------- Category ----------
  static Future<List<Category>> categories(String type) async {
    final d = await _get("/api/categories", query: {
      "type": type,
      "ledger_id": AppState.currentLedgerId,
    });
    return (d as List).map((e) => Category.fromJson(e)).toList();
  }

  // ---------- Transaction ----------
  static Future<List<Tx>> transactions({String? month, String? type}) async {
    final d = await _get("/api/transactions", query: {
      "ledger_id": AppState.currentLedgerId,
      if (month != null) "month": month,
      if (type != null) "type": type,
      "size": 200,
    });
    return ((d["items"] as List)).map((e) => Tx.fromJson(e)).toList();
  }

  static Future<Tx> createTransaction({
    required String type,
    required double amount,
    required String categoryName,
    int? categoryId,
    DateTime? date,
    String note = "",
    String source = "manual",
  }) async {
    final d = await _post("/api/transactions", {
      "ledger_id": AppState.currentLedgerId,
      "type": type,
      "amount": amount,
      "category_id": categoryId,
      "category_name": categoryName,
      "date": (date ?? DateTime.now()).toIso8601String().substring(0, 10),
      "note": note,
      "source": source,
    });
    return Tx.fromJson(d);
  }

  static Future<void> updateTransaction(int id, Map<String, dynamic> changes) async {
    await _put("/api/transactions/$id", changes);
  }

  static Future<void> deleteTransaction(int id) async {
    await _delete("/api/transactions/$id");
  }

  // ---------- AI ----------
  static Future<Map<String, dynamic>> aiParse(String text,
      {List<Map<String, dynamic>>? history}) async {
    return _post("/api/ai/parse", {
      "ledger_id": AppState.currentLedgerId,
      "text": text,
      if (history != null && history.isNotEmpty) "history": history,
    });
  }

  // ---------- Salary ----------
  static Future<List<SalaryRule>> salaryRules() async {
    final d = await _get("/api/salary-rules");
    return (d as List).map((e) => SalaryRule.fromJson(e)).toList();
  }

  static Future<SalaryRule> saveSalaryRule({
    int? id,
    required double amount,
    required int payDay,
    String name = "工资",
  }) async {
    final body = {
      "ledger_id": AppState.currentLedgerId,
      "name": name,
      "amount": amount,
      "pay_day": payDay,
    };
    final d = id == null
        ? await _post("/api/salary-rules", body)
        : await _put("/api/salary-rules/$id", body);
    return SalaryRule.fromJson(d);
  }

  static Future<void> deleteSalaryRule(int id) async {
    await _delete("/api/salary-rules/$id");
  }

  // ---------- Stats ----------
  static Future<Summary> summary(String month) async {
    final d = await _get("/api/stats/summary",
        query: {"ledger_id": AppState.currentLedgerId, "month": month});
    return Summary.fromJson(d);
  }

  static Future<List<CategoryStat>> categoryStats(String month, String type) async {
    final d = await _get("/api/stats/categories", query: {
      "ledger_id": AppState.currentLedgerId,
      "month": month,
      "type": type,
    });
    return (d as List).map((e) => CategoryStat.fromJson(e)).toList();
  }

  static Future<List<DailyStat>> dailyStats(String month) async {
    final d = await _get("/api/stats/daily",
        query: {"ledger_id": AppState.currentLedgerId, "month": month});
    return (d as List).map((e) => DailyStat.fromJson(e)).toList();
  }

  static Future<List<MemberStat>> memberStats(String month) async {
    final d = await _get("/api/stats/members",
        query: {"ledger_id": AppState.currentLedgerId, "month": month});
    return (d as List).map((e) => MemberStat.fromJson(e)).toList();
  }

  static Future<List<MonthlyStat>> monthlyStats(int year) async {
    final d = await _get("/api/stats/monthly",
        query: {"ledger_id": AppState.currentLedgerId, "year": year});
    return (d as List).map((e) => MonthlyStat.fromJson(e)).toList();
  }
}
