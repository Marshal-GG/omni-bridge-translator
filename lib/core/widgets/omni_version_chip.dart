import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A reusable widget that automatically fetches and displays the app version.
class OmniVersionChip extends StatefulWidget {
  const OmniVersionChip({super.key});

  @override
  State<OmniVersionChip> createState() => _OmniVersionChipState();
}

class _OmniVersionChipState extends State<OmniVersionChip> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'OMNI BRIDGE v$_version'.toUpperCase(),
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
