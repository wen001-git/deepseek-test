import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/locale_provider.dart';

/// Consumes a Stream<String> of text chunks from Flask and renders them
/// as Markdown in real time.
///
/// [streamBuilder] receives the selected model string ('deepseek-chat' or
/// 'deepseek-reasoner') so callers can include it in the request body.
///
/// [isAdmin] enables the collapsible Prompt Debug panel which parses and
/// strips the [DEBUG:{json}:DEBUG] prefix the server injects for admins.
class StreamingWidget extends ConsumerStatefulWidget {
  final Stream<String> Function(String model) streamBuilder;
  final String title;
  final bool isAdmin;
  final void Function(String text)? onComplete;
  /// Called on every chunk during streaming with the current accumulated
  /// character count. Called with 0 when streaming ends or errors.
  final void Function(int charCount)? onProgress;

  const StreamingWidget({
    super.key,
    required this.streamBuilder,
    required this.title,
    this.isAdmin = false,
    this.onComplete,
    this.onProgress,
  });

  @override
  ConsumerState<StreamingWidget> createState() => StreamingWidgetState();
}

class StreamingWidgetState extends ConsumerState<StreamingWidget> {
  String _model = 'deepseek-chat';
  final StringBuffer _buffer = StringBuffer();
  String _text = '';           // full received text
  String _displayText = '';    // typewriter cursor position
  int _displayPos = 0;
  bool _loading = false;
  bool _firstTokenReceived = false;
  String? _error;
  _DebugData? _debug;

  int _waitingMsgIndex = 0;
  Timer? _waitingTimer;

  // Typewriter timer: reveals _text into _displayText at a controlled pace
  // so text always appears to "type out" smoothly regardless of chunk timing.
  Timer? _typeTimer;

  void _startWaitingMessages() {
    _waitingMsgIndex = 0;
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _firstTokenReceived) {
        _waitingTimer?.cancel();
        return;
      }
      final lastIndex = 2;
      setState(() {
        _waitingMsgIndex = (_waitingMsgIndex + 1).clamp(0, lastIndex);
      });
    });
  }

  /// Start the typewriter timer.
  /// Each tick (16 ms ≈ 60 fps) advances [_displayPos] toward [_text.length].
  /// Speed is adaptive: the further behind, the faster we catch up.
  void _startTypeTimer() {
    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) {
        _typeTimer?.cancel();
        return;
      }
      final target = _text.length;
      if (_displayPos >= target) {
        if (!_loading) _typeTimer?.cancel();
        return;
      }
      // Adaptive speed: catch up faster when more text is buffered.
      final buffered = target - _displayPos;
      final step = buffered > 500 ? 50 : buffered > 100 ? 20 : 8;
      setState(() {
        _displayPos = (_displayPos + step).clamp(0, target);
        _displayText = _text.substring(0, _displayPos);
      });
    });
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _typeTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _buffer.clear();
    _debug = null;
    _waitingTimer?.cancel();
    _typeTimer?.cancel();
    setState(() {
      _text = '';
      _displayText = '';
      _displayPos = 0;
      _loading = true;
      _firstTokenReceived = false;
      _error = null;
      _waitingMsgIndex = 0;
    });
    _startWaitingMessages();

    // Non-admin users never receive the [DEBUG:...:DEBUG] prefix, so skip
    // accumulation entirely — write every chunk straight to the buffer so
    // text appears character-by-character without any delay.
    // Admin users still need accumulation to detect the optional prefix.
    String accumulator = '';
    bool debugParsed = !widget.isAdmin;

    try {
      await for (final chunk in widget.streamBuilder(_model)) {
        if (!debugParsed) {
          accumulator += chunk;
          final match =
              RegExp(r'^\[DEBUG:([\s\S]*?):DEBUG\]\n').firstMatch(accumulator);
          if (match != null) {
            try {
              final decoded = jsonDecode(match.group(1)!) as Map<String, dynamic>;
              _debug = _DebugData(
                sys: decoded['sys'] as String? ?? '',
                usr: decoded['usr'] as String? ?? '',
              );
            } catch (_) {}
            // Strip the debug marker, keep remainder
            accumulator = accumulator.substring(match.end);
            _buffer.write(accumulator);
            debugParsed = true;
          } else if (!accumulator.startsWith('[') || accumulator.length > 4000) {
            // Clearly not a debug marker — flush accumulator
            _buffer.write(accumulator);
            debugParsed = true;
          }
          // else: still accumulating to find complete marker
        } else {
          _buffer.write(chunk);
        }

        // Update the full received text without calling setState —
        // the typewriter timer handles all visual updates at 60 fps.
        _text = _buffer.toString();

        if (_text.isNotEmpty && !_firstTokenReceived) {
          _waitingTimer?.cancel();
          _firstTokenReceived = true;
          _startTypeTimer();
          // Single setState to show the text card and cancel waiting UI.
          setState(() {});
        }

        // Notify parent of progress (triggers FAB char-count update).
        widget.onProgress?.call(_text.length);
      }

      // Streaming complete: immediately reveal full text and switch to Markdown.
      _typeTimer?.cancel();
      setState(() {
        _loading = false;
        _displayText = _text;
        _displayPos = _text.length;
      });
      widget.onProgress?.call(0); // signal streaming done
      if (_text.isNotEmpty) widget.onComplete?.call(_text);
    } catch (e) {
      _waitingTimer?.cancel();
      _typeTimer?.cancel();
      widget.onProgress?.call(0);
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _text));
    final s = ref.read(stringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.copiedToClipboard), duration: const Duration(seconds: 2)),
    );
  }

  void _share() => Share.share(_text, subject: widget.title);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final waitingMessages = [
      s.connectingAi,
      s.aiThinkingWait,
      s.outputStartingSoon,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Model selector ───────────────────────────────────────────────────
        SegmentedButton<String>(
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: [
            ButtonSegment(
              value: 'deepseek-chat',
              icon: Icon(Icons.bolt, size: 14),
              label: Text(s.quickGenerate, style: const TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: 'deepseek-reasoner',
              icon: Icon(Icons.psychology_outlined, size: 14),
              label: Text(s.deepThink, style: const TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_model},
          onSelectionChanged:
              _loading ? null : (s) => setState(() => _model = s.first),
        ),
        const SizedBox(height: 12),

        // ── Prompt Debug (admin only) ─────────────────────────────────────
        if (widget.isAdmin && _debug != null) ...[
          _PromptDebugPanel(debug: _debug!),
          const SizedBox(height: 8),
        ],

        // ── Error ────────────────────────────────────────────────────────
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ),

        // ── Output ───────────────────────────────────────────────────────
        if (_displayText.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 16),
                label: Text(s.copy),
              ),
              TextButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share, size: 16),
                label: Text(s.share),
              ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              // During streaming: plain selectable text for immediate word-by-word
              // display with no Markdown parsing overhead.
              // After complete: render as Markdown for proper formatting.
              child: _loading
                  ? SelectableText(
                      _displayText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : MarkdownBody(
                      data: _text,
                      onTapLink: (_, href, __) async {
                        if (href != null) launchUrl(Uri.parse(href));
                      },
                    ),
            ),
          ),
        ],

        // ── Loading ──────────────────────────────────────────────────────
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                _firstTokenReceived
                    ? (_model == 'deepseek-reasoner'
                        ? s.deepThinkingDelay
                        : s.generating)
                    : (_model == 'deepseek-reasoner'
                        ? s.deepThinkingDelay
                        : waitingMessages[_waitingMsgIndex]),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ]),
          ),

        const SizedBox(height: 80), // space for FAB
      ],
    );
  }

  /// Called by the parent FAB to trigger generation.
  void start() => _start();
}

// ── Internal data ─────────────────────────────────────────────────────────────

class _DebugData {
  final String sys;
  final String usr;
  const _DebugData({required this.sys, required this.usr});
}

// ── Prompt Debug Panel ───────────────────────────────────────────────────────

class _PromptDebugPanel extends StatefulWidget {
  final _DebugData debug;
  const _PromptDebugPanel({required this.debug});

  @override
  State<_PromptDebugPanel> createState() => _PromptDebugPanelState();
}

class _PromptDebugPanelState extends State<_PromptDebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: const Color(0xFF1a1a2e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366f1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Prompt Debug',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                    size: 20,
                  ),
                ]),
              ),
            ),
            if (_expanded) ...[
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _debugSection('SYSTEM PROMPT', widget.debug.sys),
                      const SizedBox(height: 12),
                      _debugSection('USER PROMPT', widget.debug.usr),
                    ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _debugSection(String label, String text) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: Color(0xFF6366f1),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    ]);
  }
}
