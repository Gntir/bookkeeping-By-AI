// App 内更新：启动时静默检查，有新版弹窗提示，下载带进度，下载完唤起系统安装器
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

class UpdateService {
  /// 检查更新；manual=true 时来自设置页手动触发，会提示"已是最新"
  static Future<void> checkAndPrompt(BuildContext context, {bool manual = false}) async {
    try {
      final info = await Api.checkUpdate();
      if (info["available"] != true) {
        if (manual && context.mounted) _toast(context, "服务器上没有可用的更新包");
        return;
      }
      final remoteVersion = (info["version"] ?? "").toString();
      final remoteBuild = int.tryParse(remoteVersion.split("+").last) ?? 0;

      final pi = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(pi.buildNumber) ?? 0;

      if (remoteBuild <= localBuild) {
        if (manual && context.mounted) _toast(context, "已是最新版本（${pi.version}+${pi.buildNumber}）");
        return;
      }
      if (context.mounted) await _showDialog(context, remoteVersion, (info["note"] ?? "").toString());
    } catch (_) {
      // 静默失败不打扰用户；手动检查时给提示
      if (manual && context.mounted) _toast(context, "检查更新失败，请稍后再试");
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static Future<void> _showDialog(BuildContext context, String version, String note) async {
    var downloading = false;
    var progress = 0.0;
    var errorMsg = "";

    await showDialog(
      context: context,
      barrierDismissible: false, // 下载中防误触关闭
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(downloading ? "正在下载新版本" : "发现新版本 $version"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!downloading && note.isNotEmpty)
                Text(note, style: const TextStyle(height: 1.5)),
              if (downloading) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text("已下载 ${(progress * 100).toStringAsFixed(0)}%",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
              if (errorMsg.isNotEmpty)
                Text(errorMsg, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            if (!downloading)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("以后再说"),
              ),
            if (!downloading)
              FilledButton(
                onPressed: () async {
                  setState(() => downloading = true);
                  try {
                    final path = await Api.downloadApk((count, total) {
                      if (total > 0) setState(() => progress = count / total);
                    });
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    // 唤起系统安装器；首次会引导开启"允许安装未知应用"
                    final result = await OpenFilex.open(path,
                        type: "application/vnd.android.package-archive");
                    if (result.type != ResultType.done) {
                      if (context.mounted) _toast(context, "无法打开安装包：${result.message}");
                    }
                  } catch (e) {
                    setState(() {
                      downloading = false;
                      progress = 0;
                      errorMsg = "下载失败：$e，请重试";
                    });
                  }
                },
                child: const Text("立即更新"),
              ),
          ],
        ),
      ),
    );
  }
}
