// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

// Web-only audio using dart:html
import 'dart:html' as html;

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String title;
  final String subtitle;
  final bool isPodcast;
  final VoidCallback? onClose;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.title,
    this.subtitle = '',
    this.isPodcast = false,
    this.onClose,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  html.AudioElement? _audio;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _position = 0;
  double _duration = 0;
  double _playbackRate = 1.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  void _initAudio() {
    String finalUrl = widget.audioUrl;
    
    // Auto-convert Google Drive links to direct streamable links
    if (finalUrl.contains('drive.google.com/file/d/')) {
      final regExp = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
      final match = regExp.firstMatch(finalUrl);
      if (match != null && match.groupCount >= 1) {
        final fileId = match.group(1);
        finalUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
      }
    }

    _audio = html.AudioElement(finalUrl);
    _audio!.crossOrigin = 'anonymous'; // Melhor para Firebase Storage no Web
    _audio!.preload = 'auto'; // Começa a baixar rápido
    _audio!.autoplay = true;  // Autoplay nativo
    
    _audio!.onLoadedMetadata.listen((_) {
      if (mounted) setState(() => _duration = _audio!.duration.toDouble());
    });
    
    _audio!.onEnded.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = 0;
        });
      }
      _timer?.cancel();
    });
    
    _audio!.onError.listen((_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _isPlaying = false;
      }
    });

    // Eventos extras para parar o loading visual se o áudio já carregou
    _audio!.onCanPlay.listen((_) {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    });
    
    _audio!.onPlay.listen((_) {
      if (mounted) setState(() { _isPlaying = true; _isLoading = false; });
      _startTimer();
    });
    
    _audio!.onPause.listen((_) {
      if (mounted && _isPlaying) setState(() => _isPlaying = false);
    });

    // Forçar auto-play via código caso o atributo falhe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isPlaying) _togglePlay();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_audio != null && mounted) {
        setState(() => _position = _audio!.currentTime.toDouble());
      }
    });
  }

  void _togglePlay() async {
    if (_audio == null) return;
    if (_isPlaying) {
      _audio!.pause();
      _timer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isLoading = true);
      try {
        await _audio!.play();
        _startTimer();
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        // Se o navegador bloquear autoplay sem interação ou der erro de rede
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = false;
          });
        }
      }
    }
  }

  void _seek(double value) {
    if (_audio == null) return;
    _audio!.currentTime = value;
    setState(() => _position = value);
  }

  void _setRate(double rate) {
    _audio?.playbackRate = rate;
    setState(() => _playbackRate = rate);
  }

  String _fmt(double secs) {
    if (secs.isNaN || secs.isInfinite) return '--:--';
    final m = secs ~/ 60;
    final s = (secs % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio?.pause();
    _audio = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final accentColor = widget.isPodcast ? const Color(0xFF8B5CF6) : AppTheme.accent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.appBar.withOpacity(0.98),
        border: Border(
           top: BorderSide(color: accentColor.withOpacity(0.3), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating progress bar with almost zero height on its own
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accentColor,
                inactiveTrackColor: t.isDark ? Colors.white12 : Colors.black12,
                thumbColor: accentColor,
                overlayColor: accentColor.withOpacity(0.2),
                trackHeight: 3,
                trackShape: const RectangularSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: SizedBox(
                   height: 12, // extremely tight
                   child: Slider(
                    value: _duration > 0 ? _position.clamp(0.0, _duration) : 0,
                    max: _duration > 0 ? _duration : 1,
                    onChanged: _seek,
                  ),
                ),
              ),
            ),
            
            // Controls & Info Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Play/Pause Button
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withOpacity(0.15),
                      ),
                      child: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: accentColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: accentColor,
                            size: 28,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Text Info
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            color: t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_fmt(_position)} / ${_fmt(_duration)} • ${widget.subtitle}',
                          style: GoogleFonts.inter(
                            color: t.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Speed & Close
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final rates = [0.75, 1.0, 1.25, 1.5, 2.0];
                          final idx = rates.indexOf(_playbackRate);
                          _setRate(rates[(idx + 1) % rates.length]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: t.border),
                          ),
                          child: Text(
                            '${_playbackRate}x',
                            style: GoogleFonts.inter(
                              color: t.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.onClose != null)
                        IconButton(
                          icon: Icon(Icons.close, color: t.textTertiary, size: 22),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
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
