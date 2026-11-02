// App 内更新：启动时静默检查，有新版弹窗提示；下载走系统 DownloadManager
//（支持后台下载，通知栏可见进度），失败自动回退到 App 内前台断点续传下载
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  static Future<void> _showDialog(BuildContext context, String version, String note) async {
    var downloading = false;
    var progress = 0.0;
    var errorMsg = "";
    StreamSubscription<OtaEvent>? sub;

    // 系统下载失败时回退：App 内前台断点续传（wakelock 防息屏断网）
    Future<void> fallbackDownload(StateSetter setState, BuildContext ctx) async {
      await WakelockPlus.enable();
      try {
        final path = await Api.downloadApk(version, (count, total) {
          if (total > 0) setState(() => progress = count / total);
        });
        if (ctx.mounted) Navigator.of(ctx).pop();
        final result = await OpenFilex.open(path,
            type: "application/vnd.android.package-archive");
        if (result.type != ResultType.done && context.mounted) {
          _toast(context, "无法打开安装包：${result.message}");
        }
      } catch (e) {
        setState(() {
          downloading = false;
          errorMsg = "下载失败：$e，请重试";
        });
      } finally {
        await WakelockPlus.disable();
      }
    }

    Future<void> startDownload(StateSetter setState, BuildContext ctx) async {
      setState(() {
        downloading = true;
        errorMsg = "";
      });
      sub = OtaUpdate()
          .execute(Api.downloadUrl, destinationFilename: "ai_jizhang_update.apk")
          .listen((OtaEvent event) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final p = double.tryParse(event.value ?? "") ?? 0;
            if (p > 0) setState(() => progress = p / 100);
            break;
          case OtaStatus.INSTALLING:
            // 下载完成，插件已唤起系统安装器
            sub?.cancel();
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) _toast(context, "下载完成，请在系统安装界面确认");
            break;
          case OtaStatus.CANCELED:
            setState(() {
              downloading = false;
              progress = 0;
              errorMsg = "已取消下载";
            });
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
            setState(() {
              downloading = false;
              errorMsg = "已有下载任务在进行中（通知栏可查看），稍后再试";
            });
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            sub?.cancel();
            setState(() {
              downloading = false;
              errorMsg = "请在系统设置中允许本应用「安装未知应用」后重试";
            });
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
            // 系统下载失败 → 回退 App 内前台下载（自带断点续传重试）；
            // ctx 在 fallbackDownload 内部有 mounted 守卫
            // ignore: use_build_context_synchronously
            fallbackDownload(setState, ctx);
            break;
          default:
            break;
        }
      });
    }

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
                LinearProgressIndicator(value: progress > 0 ? progress : null),
                const SizedBox(height: 8),
                Text(
                  progress > 0 ? "已下载 ${(progress * 100).toStringAsFixed(0)}%" : "准备中…",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text("系统后台下载中，切后台/息屏不中断，通知栏可看进度",
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
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
            if (downloading)
              TextButton(
                onPressed: () => OtaUpdate().cancel(),
                child: const Text("取消下载"),
              ),
            if (!downloading)
              FilledButton(
                onPressed: () => startDownload(setState, ctx),
                child: const Text("立即更新"),
              ),
          ],
        ),
      ),
    );
    await sub?.cancel();
  }
}
