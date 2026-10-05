import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// common.dart exports its own Dialog helper; the Material one is used here.
import '../../common.dart' hide Dialog;
import '../../models/platform_model.dart';

/// Window geometry for the compact single-purpose host window:
/// width is screen/6 clamped to [kRaynoMinWidth]..[kRaynoMaxWidth], and the
/// height follows from that width so the content/window ratio stays stable.
const int kRaynoMinWidth = 320;
const int kRaynoMaxWidth = 420;
const int kRaynoMinHeight = 400;
const int kRaynoMaxHeight = 520;
const int kRaynoEdgeMargin = 10;
const int kRaynoHeaderHeight = 44;

Size raynoWindowSize(Size screen) {
  final w = (screen.width / 6).round().clamp(kRaynoMinWidth, kRaynoMaxWidth);
  final h = (w * 1.25).round().clamp(kRaynoMinHeight, kRaynoMaxHeight);
  return Size(w.toDouble(), h.toDouble());
}

const String kRaynoWindowPosOption = 'rayno-window-pos';

/// Persists and restores the top-right default position. Out-of-range saved
/// positions are ignored so the window can never start off-screen.
Future<Offset> raynoRestorePosition(Size windowSize) async {
  final fallback = await raynoDefaultPosition(windowSize);
  final raw = bind.mainGetLocalOption(key: kRaynoWindowPosOption);
  if (raw.isEmpty) return fallback;
  final parts = raw.split(',');
  if (parts.length != 2) return fallback;
  final screen = await windowManager.getSize();
  final x = double.tryParse(parts[0]);
  final y = double.tryParse(parts[1]);
  if (x == null || y == null) return fallback;
  if (x < 0 || y < 0 || x + windowSize.width > screen.width ||
      y + windowSize.height > screen.height) {
    return fallback;
  }
  return Offset(x, y);
}

Future<Offset> raynoDefaultPosition(Size windowSize) async {
  final screen = await windowManager.getSize();
  return Offset(
    screen.width - windowSize.width - kRaynoEdgeMargin,
    kRaynoEdgeMargin.toDouble(),
  );
}

/// The drag area of a frameless window. `window_manager` only drags from the
/// caption role, so an explicit GestureDetector is needed for a custom header.
class WindowDragArea extends StatelessWidget {
  final Widget child;
  final double? width;

  const WindowDragArea({super.key, required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => windowManager.startDragging(),
      onPanUpdate: (_) {},
      child: width == null ? child : SizedBox(width: width, child: child),
    );
  }
}

class RaynoHeader extends StatelessWidget {
  final VoidCallback? onChatTap;
  final bool chatHasUnread;
  final VoidCallback? onClose;

  const RaynoHeader({
    super.key,
    this.onChatTap,
    this.chatHasUnread = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MyTheme.currentThemeMode() == ThemeMode.dark;
    final fg = isDark ? Colors.white : const Color(0xFF222222);
    return WindowDragArea(
      child: Container(
        height: kRaynoHeaderHeight.toDouble(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F7),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFE2E2E6),
            ),
          ),
        ),
        child: Row(
          children: [
            loadIcon(26),
            const SizedBox(width: 8),
            Text(
              'راینو دسک',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const Spacer(),
            _HeaderIconButton(
              icon: Icons.chat_bubble_outline,
              tooltip: 'چت',
              color: fg,
              badge: chatHasUnread,
              onTap: onChatTap,
            ),
            const SizedBox(width: 4),
            _HeaderIconButton(
              icon: Icons.close,
              tooltip: 'بستن',
              color: fg,
              onTap: onClose ?? () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  final bool badge;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
    this.badge = false,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: hover ? MyTheme.canvasColor.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(widget.icon, size: 18, color: widget.color),
                ),
                if (widget.badge)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF39B7FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aggregate connectivity used by the three status lights.
class RaynoConnectivity {
  final bool internet;
  final bool server;
  final bool agent;

  const RaynoConnectivity({
    required this.internet,
    required this.server,
    required this.agent,
  });

  static const offline = RaynoConnectivity(
      internet: false, server: false, agent: false);
}

class RaynoStatusLights extends StatelessWidget {
  final RaynoConnectivity state;
  final String statusText;

  const RaynoStatusLights({
    super.key,
    required this.state,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatusLight(label: 'اینترنت', sub: 'Internet', on: state.internet),
            _StatusLight(label: 'سرور', sub: 'Server', on: state.server),
            _StatusLight(label: 'ارتباط کارشناس', sub: 'Agent', on: state.agent),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

class _StatusLight extends StatelessWidget {
  final String label;
  final String sub;
  final bool on;

  const _StatusLight({
    required this.label,
    required this.sub,
    required this.on,
  });

  @override
  Widget build(BuildContext context) {
    const onColor = Color(0xFF2ECC71);
    const offColor = Color(0xFFE74C3C);
    final dot = on ? onColor : offColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dot.withValues(alpha: 0.55),
                blurRadius: on ? 10 : 4,
                spreadRadius: on ? 2 : 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        Text(
          sub,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

/// Slide-in chat panel. Messages go to the peer through the existing
/// `cm_send_chat` bridge, keyed by the connection id of the active client.
class RaynoChatPanel extends StatefulWidget {
  final int? connId;
  final String peerName;
  final List<String> messages;
  final Future<void> Function(String text) onSend;
  final VoidCallback onClose;

  const RaynoChatPanel({
    super.key,
    required this.connId,
    required this.peerName,
    required this.messages,
    required this.onSend,
    required this.onClose,
  });

  @override
  State<RaynoChatPanel> createState() => _RaynoChatPanelState();
}

class _RaynoChatPanelState extends State<RaynoChatPanel> {
  final _controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MyTheme.currentThemeMode() == ThemeMode.dark;
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF444444) : const Color(0xFFE2E2E6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'چت${widget.peerName.isEmpty ? '' : ' — ${widget.peerName}'}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'بستن',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Text(
                      'پیامی وجود ندارد',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.messages.length,
                    itemBuilder: (_, i) => Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: MyTheme.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(widget.messages[i], style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'پیام خود را تایپ کنید...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'ارسال',
                  onPressed: sending ? null : _send,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal shown when a peer asks to connect. Accept closes with `false` on the
/// connection-manager side only after the caller decides.
class RaynoIncomingRequest extends StatelessWidget {
  final String peerId;
  final String peerName;
  final bool isFileTransfer;
  final bool isTerminal;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RaynoIncomingRequest({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.isFileTransfer,
    required this.isTerminal,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (isFileTransfer) 'انتقال فایل',
      if (isTerminal) 'ترمینال',
    ];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('درخواست ورودی',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('شناسه درخواست‌کننده:',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 4),
                  SelectableText(
                    peerId,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Consolas'),
                  ),
                  if (peerName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(peerName,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(tags.join(' · '),
                        style: const TextStyle(
                            fontSize: 11, color: MyTheme.accent)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _RequestButton(
                    label: 'پذیرش',
                    color: const Color(0xFF2ECC71),
                    onPressed: busy ? null : onAccept,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RequestButton(
                    label: 'قطع ارتباط',
                    color: const Color(0xFFE74C3C),
                    onPressed: busy ? null : onReject,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _RequestButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}