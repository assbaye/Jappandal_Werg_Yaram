import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';

class TeleConsultationScreen extends ConsumerStatefulWidget {
  final String consultationId;

  const TeleConsultationScreen({super.key, required this.consultationId});

  @override
  ConsumerState<TeleConsultationScreen> createState() => _TeleConsultationScreenState();
}

class _TeleConsultationScreenState extends ConsumerState<TeleConsultationScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localAudioMuted = false;
  bool _localVideoMuted = false;
  bool _isLoading = true;
  String? _error;
  Duration _duration = Duration.zero;
  Timer? _timer;

  String? _agoraAppId;
  String? _agoraChannel;
  String? _agoraToken;
  int? _agoraUid;

  @override
  void initState() {
    super.initState();
    _initConsultation();
  }

  Future<void> _initConsultation() async {
    // 1. Demander les permissions
    await [Permission.camera, Permission.microphone].request();

    // 2. Obtenir le token Agora via mutation GraphQL
    try {
      final client = ref.read(graphQLClientProvider);
      final result = await client.mutate(
        MutationOptions(
          document: gql(demarrerTeleConsultationMutation),
          variables: {'consultation_id': widget.consultationId},
        ),
      );

      if (result.hasException) {
        setState(() {
          _error = result.exception?.graphqlErrors.firstOrNull?.message ?? 'Impossible de démarrer la consultation';
          _isLoading = false;
        });
        return;
      }

      final data = result.data!['demarrerTeleConsultation'] as Map<String, dynamic>;
      // App ID, canal, token et uid viennent du serveur (le token est lié à cet uid)
      _agoraAppId = data['agora_app_id'] as String?;
      _agoraChannel = data['agora_channel'] as String?;
      _agoraToken = data['agora_token'] as String?;
      _agoraUid = data['agora_uid'] as int?;

      // 3. Initialiser le moteur Agora
      await _initAgora();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initAgora() async {
    if (_agoraChannel == null || _agoraAppId == null || _agoraAppId!.isEmpty) {
      setState(() {
        _error = 'La vidéo n\'est pas configurée sur le serveur.';
        _isLoading = false;
      });
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: _agoraAppId!));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        _startTimer();
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (mounted) setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (mounted) setState(() => _remoteUid = null);
      },
      onError: (err, msg) {
        final detail = switch (err) {
          ErrorCodeType.errInvalidToken || ErrorCodeType.errTokenExpired =>
            'Jeton vidéo refusé : vérifiez AGORA_APP_CERTIFICATE sur le serveur.',
          ErrorCodeType.errInvalidAppId => 'App ID Agora invalide : vérifiez AGORA_APP_ID sur le serveur.',
          _ => 'Erreur vidéo ($err) $msg',
        };
        if (mounted) setState(() => _error = detail);
      },
    ));

    await _engine!.enableVideo();
    await _engine!.startPreview();
    await _engine!.joinChannel(
      token: _agoraToken ?? '',
      channelId: _agoraChannel!,
      uid: _agoraUid ?? 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    if (mounted) setState(() => _isLoading = false);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _quitter() async {
    _timer?.cancel();
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) context.go('/consultations');
  }

  void _toggleAudio() {
    setState(() => _localAudioMuted = !_localAudioMuted);
    _engine?.muteLocalAudioStream(_localAudioMuted);
  }

  void _toggleVideo() {
    setState(() => _localVideoMuted = !_localVideoMuted);
    _engine?.muteLocalVideoStream(_localVideoMuted);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Connexion en cours...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/consultations'),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Vue distante (plein écran)
          if (_remoteUid != null && _engine != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: _agoraChannel!),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, color: Colors.white54, size: 80),
                  SizedBox(height: 12),
                  Text('En attente du médecin...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),

          // Vue locale (coin inférieur droit)
          if (_engine != null && !_localVideoMuted)
            Positioned(
              right: 16,
              bottom: 100,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

          // Timer durée
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contrôles (bas)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _localAudioMuted ? Icons.mic_off : Icons.mic,
                    label: _localAudioMuted ? 'Micro off' : 'Micro',
                    color: _localAudioMuted ? Colors.red : Colors.white,
                    onTap: _toggleAudio,
                  ),
                  _ControlButton(
                    icon: Icons.call_end,
                    label: 'Raccrocher',
                    color: Colors.red,
                    backgroundColor: Colors.red,
                    iconColor: Colors.white,
                    onTap: _quitter,
                    large: true,
                  ),
                  _ControlButton(
                    icon: _localVideoMuted ? Icons.videocam_off : Icons.videocam,
                    label: _localVideoMuted ? 'Caméra off' : 'Caméra',
                    color: _localVideoMuted ? Colors.red : Colors.white,
                    onTap: _toggleVideo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool large;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor ?? color, size: large ? 32 : 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
