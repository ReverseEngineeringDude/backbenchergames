import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/lan_room.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/rooms/lan_room_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import 'lan_game_screen.dart';

/// Shown to the HOST after creating a LAN room.
/// Displays a QR code + IP address for the guest to scan/enter.
/// Automatically transitions to [LanGameScreen] when the guest connects.
class LanHostScreen extends StatefulWidget {
  final LanRoom room;
  final GamePlugin plugin;
  final LanRoomService service;
  final String hostUid;
  final String hostDisplayName;

  const LanHostScreen({
    super.key,
    required this.room,
    required this.plugin,
    required this.service,
    required this.hostUid,
    required this.hostDisplayName,
  });

  @override
  State<LanHostScreen> createState() => _LanHostScreenState();
}

class _LanHostScreenState extends State<LanHostScreen> {
  bool _guestJoined = false;

  @override
  void initState() {
    super.initState();
    widget.service.roomStream.listen((room) {
      if (!mounted) return;
      if (room.isActive && !_guestJoined) {
        setState(() => _guestJoined = true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LanGameScreen(
              initialRoom: room,
              plugin: widget.plugin,
              isHost: true,
              localUid: widget.hostUid,
              localDisplayName: widget.hostDisplayName,
              service: widget.service,
            ),
          ),
        );
      }
    });
  }

  /// QR code encodes `backbench-lan://ip:port`
  String get _qrData =>
      'backbench-lan://${widget.room.hostIp}:${widget.room.hostPort}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            widget.service.dismantle(reason: 'Host cancelled');
            Navigator.of(context).pop();
          },
        ),
        title: const Text('LAN Multiplayer – Host', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'SCAN TO CONNECT',
                    style: TextStyle(
                      color: AppColors.playerX,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Guest scans QR or enters IP manually',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.playerXGlow, blurRadius: 20, spreadRadius: 2),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // IP:Port display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'OR enter manually',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${widget.room.hostIp}:${widget.room.hostPort}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(
                                  text: '${widget.room.hostIp}:${widget.room.hostPort}',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied to clipboard!')),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.playerX),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Waiting indicator
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.playerX),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Waiting for guest on same Wi-Fi...',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GUEST JOIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

/// Shown to the GUEST.  They enter the host's IP (or it is pre-filled from QR)
/// and connect. On success they are forwarded to [LanGameScreen].
class LanJoinScreen extends StatefulWidget {
  final GamePlugin plugin;
  final String guestUid;
  final String guestDisplayName;
  final String? prefilledIp; // filled when coming from QR scan

  const LanJoinScreen({
    super.key,
    required this.plugin,
    required this.guestUid,
    required this.guestDisplayName,
    this.prefilledIp,
  });

  @override
  State<LanJoinScreen> createState() => _LanJoinScreenState();
}

class _LanJoinScreenState extends State<LanJoinScreen> {
  final _ipController = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledIp != null) {
      _ipController.text = widget.prefilledIp!;
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final raw = _ipController.text.trim();
    if (raw.isEmpty) return;

    // Parse "ip:port" or just "ip"
    String ip;
    int port = LanRoomService.defaultPort;
    if (raw.contains(':')) {
      final parts = raw.split(':');
      ip = parts[0];
      port = int.tryParse(parts[1]) ?? LanRoomService.defaultPort;
    } else {
      ip = raw;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final service = LanRoomService();
      final room = await service.joinGame(
        hostIp: ip,
        guestUid: widget.guestUid,
        guestDisplayName: widget.guestDisplayName,
        port: port,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LanGameScreen(
              initialRoom: room,
              plugin: widget.plugin,
              isHost: false,
              localUid: widget.guestUid,
              localDisplayName: widget.guestDisplayName,
              service: service,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openScanner() async {
    final scannedIp = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QRScannerSheet(),
    );

    if (scannedIp != null && scannedIp.isNotEmpty) {
      _ipController.text = scannedIp;
      _connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('LAN Multiplayer – Join', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.wifi_rounded, size: 52, color: AppColors.playerX),
                  const SizedBox(height: 16),
                  const Text(
                    'Join LAN Game',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the host\'s IP address shown on their screen\nor scan the QR code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  const SizedBox(height: 28),

                  TextField(
                    controller: _ipController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '192.168.x.x:45678',
                      prefixIcon: Icon(Icons.router_rounded),
                      label: Text('Host IP Address'),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withAlpha(100)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: _connecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(_connecting ? 'Connecting...' : 'CONNECT TO HOST'),
                  ),

                  if (!kIsWeb) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: AppColors.cardBorder)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: AppColors.cardBorder)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _connecting ? null : _openScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('SCAN QR CODE'),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 12),

                  const Text(
                    '⚡ Both devices must be on the same Wi-Fi network or local hotspot.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QRScannerSheet extends StatefulWidget {
  const _QRScannerSheet();

  @override
  State<_QRScannerSheet> createState() => _QRScannerSheetState();
}

class _QRScannerSheetState extends State<_QRScannerSheet> {
  bool _found = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Scan Host QR Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: MobileScanner(
                onDetect: (capture) {
                  if (_found) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final rawValue = barcode.rawValue;
                    if (rawValue != null && rawValue.startsWith('backbench-lan://')) {
                      _found = true;
                      final ipPart = rawValue.replaceFirst('backbench-lan://', '');
                      Navigator.of(context).pop(ipPart);
                      break;
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
