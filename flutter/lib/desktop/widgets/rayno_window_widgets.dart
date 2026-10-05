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

  const RaynoHeader({
    super.key,
    this.onChatTap,
    this.chatHasUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return WindowDragArea(
      child: Container(
        height: kRaynoHeaderHeight.toDouble(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          // The host panel is always dark, independent of the app theme.
          color: Color(0xFF1E1E1E),
          border: Border(
            bottom: BorderSide(color: Color(0xFF444444)),
          ),
        ),
        child: Row(
          children: [
            Text(
              'RAYNO DESK',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            _HeaderIconButton(
              icon: Icons.chat_bubble_outline,
              tooltip: 'چت',
              color: Colors.white,
              badge: chatHasUnread,
              onTap: onChatTap,
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

/// Aggregate connectivity shown by the two status lights.
class RaynoConnectivity {
  final bool internet;
  final bool server;

  const RaynoConnectivity({
    required this.internet,
    required this.server,
  });

  static const offline = RaynoConnectivity(internet: false, server: false);
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
          ],
        ),
        const SizedBox(height: 12),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
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
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            // A wider halo when connected reads as "live" without a legend.
            boxShadow: [
              BoxShadow(
                color: dot.withValues(alpha: 0.7),
                blurRadius: on ? 14 : 6,
                spreadRadius: on ? 3 : 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        Text(
          sub,
          style: const TextStyle(fontSize: 9, color: Color(0xFF8A8A8A)),
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
  final VoidCallback onAttach;
  final VoidCallback onClose;

  const RaynoChatPanel({
    super.key,
    required this.connId,
    required this.peerName,
    required this.messages,
    required this.onSend,
    required this.onAttach,
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
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1C),
        border: Border(
          right: BorderSide(color: Color(0xFF3A3A3C), width: 1),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 15,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'بستن',
                    color: const Color(0xFFBBBBBB),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      widget.peerName.isEmpty
                          ? 'چت پشتیبانی'
                          : 'چت پشتیبانی — ${widget.peerName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF3A3A3C)),
            Expanded(
              child: widget.messages.isEmpty
                  ? const Center(
                      child: Text(
                        'پیامی وجود ندارد',
                        style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
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
                            color: MyTheme.accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.messages[i],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white),
                          ),
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
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'پیام خود را تایپ کنید...',
                        hintStyle: TextStyle(color: Color(0xFF7A7A7A)),
                        filled: true,
                        fillColor: Color(0xFF232326),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF3A3A3C)),
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: MyTheme.accent),
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'پیوست',
                    iconSize: 18,
                    color: const Color(0xFFBBBBBB),
                    onPressed: widget.onAttach,
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    tooltip: 'ارسال',
                    iconSize: 18,
                    color: MyTheme.accent,
                    onPressed: sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      backgroundColor: const Color(0xFF1E1E20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3A3A3C)),
      ),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(18),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('درخواست ورودی',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF232326),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('شناسه درخواست‌کننده:',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                    const SizedBox(height: 4),
                    SelectableText(
                      peerId,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Consolas',
                          color: Colors.white),
                    ),
                    if (peerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(peerName,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9E9E9E))),
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