import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';

enum _State { idle, downloading, launching, error }

/// Download-and-launch button for app updates.
///
/// If [downloadUrl] is provided it streams the installer to the system temp
/// directory and launches it directly. Otherwise falls back to opening
/// [releaseUrl] in the browser.
class UpdateDownloadButton extends StatefulWidget {
  final String? downloadUrl;
  final String releaseUrl;

  /// When true renders a full-width [ElevatedButton] (force-update screen).
  /// When false renders a compact inline text link (about screen).
  final bool primary;

  const UpdateDownloadButton({
    super.key,
    required this.releaseUrl,
    this.downloadUrl,
    this.primary = false,
  });

  @override
  State<UpdateDownloadButton> createState() => _UpdateDownloadButtonState();
}

class _UpdateDownloadButtonState extends State<UpdateDownloadButton> {
  static const String _tag = 'UpdateDownload';

  _State _state = _State.idle;
  double _progress = 0;
  String? _error;

  Future<void> _handleTap() async {
    if (_state == _State.downloading || _state == _State.launching) return;

    final direct = widget.downloadUrl;
    if (direct != null && direct.isNotEmpty) {
      await _downloadAndLaunch(direct);
    } else {
      await _openBrowser(widget.releaseUrl);
    }
  }

  Future<void> _downloadAndLaunch(String url) async {
    setState(() {
      _state = _State.downloading;
      _progress = 0;
      _error = null;
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      int received = 0;

      final fileName = Uri.parse(url).pathSegments.last.isNotEmpty
          ? Uri.parse(url).pathSegments.last
          : 'omni_bridge_setup.exe';
      final filePath = '${Directory.systemTemp.path}\\$fileName';
      final sink = File(filePath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      }

      await sink.close();
      client.close();

      if (!mounted) return;
      setState(() => _state = _State.launching);

      AppLogger.i('Launching installer: $filePath', tag: _tag);
      await Process.start(filePath, [], mode: ProcessStartMode.detached);
    } catch (e) {
      AppLogger.e('Download failed', error: e, tag: _tag);
      if (mounted) {
        setState(() {
          _state = _State.error;
          _error = 'Download failed — tap to retry';
        });
      }
    }
  }

  Future<void> _openBrowser(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Rendering ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return widget.primary ? _buildPrimary() : _buildInline();
  }

  Widget _buildPrimary() {
    final label = _primaryLabel();
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentTeal,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: _state == _State.launching ? null : _handleTap,
        child: _state == _State.downloading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _progress > 0
                        ? 'Downloading ${(_progress * 100).toInt()}%'
                        : 'Downloading…',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _state == _State.launching
                        ? Icons.check_rounded
                        : _state == _State.error
                        ? Icons.refresh_rounded
                        : Icons.download_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInline() {
    if (_state == _State.downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 9,
            height: 9,
            child: CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              strokeWidth: 1.5,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _progress > 0
                ? '${(_progress * 100).toInt()}%'
                : 'Downloading…',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
          ),
        ],
      );
    }

    final (text, color) = switch (_state) {
      _State.launching => ('Launching…', Colors.tealAccent),
      _State.error => (_error ?? 'Error — retry', Colors.redAccent),
      _ => ('Download', Colors.orangeAccent),
    };

    return GestureDetector(
      onTap: _handleTap,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }

  String _primaryLabel() => switch (_state) {
    _State.launching => 'Launching…',
    _State.error => 'Retry Download',
    _ => 'Download Update',
  };
}
