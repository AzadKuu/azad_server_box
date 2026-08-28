import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_status.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/view/page/storage/transfer_list.dart';

/// A compact floating card that shows active file transfers with progress bars.
///
/// Sits at the top-right corner. Watches [fileTransferProvider] and auto-hides
/// when no transfers are in progress. Tapping it opens the full transfer list.
/// The close button hides it for the rest of this app session.
class TransferFloatingProgress extends ConsumerStatefulWidget {
  const TransferFloatingProgress({super.key});

  @override
  ConsumerState<TransferFloatingProgress> createState() =>
      _TransferFloatingProgressState();
}

class _TransferFloatingProgressState
    extends ConsumerState<TransferFloatingProgress> {
  /// Set by the close button; stays hidden until the app restarts.
  static bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    final transfers = ref.watch(fileTransferProvider).transfers;

    final active = transfers.where(_isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final total = active.length;

    return Positioned(
      top: 8,
      right: 8,
      width: 220,
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_upload, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => TransferListPage.route.go(context),
                      child: Text(
                        total == 1
                            ? active.first.fileName
                            : '$total ${libL10n.mission}',
                        style: UIs.text13,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _hidden = true),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => TransferListPage.route.go(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < active.length && i < 2; i++) ...[
                      _buildProgress(active[i], showName: total > 1),
                      if (i < active.length - 1 && i < 1)
                        const SizedBox(height: 4),
                    ],
                    if (total > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '... ${total - 2} ${libL10n.more}',
                          style: UIs.text11Grey,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isActive(FileTransferStatus t) {
    if (t.error != null) return false;
    return t.status != FileTransferStage.finished && t.status != null;
  }

  Widget _buildProgress(FileTransferStatus t, {required bool showName}) {
    final progress = (t.progress ?? 0).clamp(0.0, 100.0) / 100.0;
    final transferred = (t.transferredBytes ?? 0).bytes2Str;
    final size = (t.size ?? 0).bytes2Str;
    final speed = '${(t.speedBytesPerSecond ?? 0).bytes2Str}/s';

    final stageText = switch (t.status) {
      FileTransferStage.preparing => libL10n.upload,
      FileTransferStage.connected => l10n.sftpSSHConnected,
      FileTransferStage.loading => '$transferred/$size $speed',
      _ => '',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showName)
          Text(
            t.fileName,
            style: UIs.text11Grey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 1),
        Text(stageText, style: UIs.text11Grey),
      ],
    );
  }
}
