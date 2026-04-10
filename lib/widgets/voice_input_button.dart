import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:larga/services/speech_service.dart';

class VoiceInputButton extends StatefulWidget {
  final void Function(String transcript) onTranscript;
  final void Function(String error)? onError;
  final void Function(bool isListening)? onListeningChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const VoiceInputButton({
    super.key,
    required this.onTranscript,
    this.onError,
    this.onListeningChanged,
    this.size = 48,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final _speechService = SpeechService.instance;

  bool _isAvailable = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechService.initialize();
    if (mounted) {
      setState(() {
        _isAvailable = available;
        _isInitializing = false;
      });
    }
  }

  void _showVoiceOverlay() {
    Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: VoiceInputOverlay(
              onTranscript: (transcript) {
                Navigator.of(context).pop(transcript);
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
              onError: widget.onError,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    ).then((transcript) {
      if (transcript != null && transcript.isNotEmpty) {
        widget.onTranscript(transcript);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_isAvailable) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = widget.inactiveColor ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showVoiceOverlay,
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.mic_rounded,
            color: color,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}

class VoiceInputOverlay extends StatefulWidget {
  final void Function(String transcript) onTranscript;
  final VoidCallback onCancel;
  final void Function(String error)? onError;

  const VoiceInputOverlay({
    super.key,
    required this.onTranscript,
    required this.onCancel,
    this.onError,
  });

  @override
  State<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends State<VoiceInputOverlay>
    with TickerProviderStateMixin {
  final _speechService = SpeechService.instance;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  
  StreamSubscription<SpeechEvent>? _eventSubscription;

  String _transcript = '';
  bool _isListening = false;
  String? _error;

  // App brand colors (coral theme)
  static const _primaryColor = Color(0xFFF06B64);
  static const _primaryColorLight = Color(0xFFFF8A80);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _eventSubscription = _speechService.events.listen(_handleSpeechEvent);
    _startListening();
  }

  Future<void> _startListening() async {
    final success = await _speechService.startListening();
    if (!success && mounted) {
      setState(() {
        _error = 'Could not start voice input';
      });
    }
  }

  void _handleSpeechEvent(SpeechEvent event) {
    if (!mounted) return;

    switch (event.status) {
      case SpeechStatus.listening:
        setState(() {
          _isListening = true;
          _error = null;
          if (event.transcript != null) {
            _transcript = event.transcript!;
          }
        });
        _pulseController.repeat(reverse: true);
        break;

      case SpeechStatus.idle:
        setState(() {
          _isListening = false;
          if (event.isFinal && event.transcript != null) {
            _transcript = event.transcript!;
          }
        });
        _pulseController.stop();
        break;

      case SpeechStatus.processing:
        break;

      case SpeechStatus.error:
        setState(() {
          _isListening = false;
          _error = event.error;
        });
        _pulseController.stop();
        if (event.error != null) {
          widget.onError?.call(event.error!);
        }
        break;
    }
  }

  Future<void> _stopAndSubmit() async {
    final transcript = await _speechService.stopListening();
    if (transcript != null && transcript.isNotEmpty) {
      widget.onTranscript(transcript);
    } else {
      widget.onCancel();
    }
  }

  void _cancel() {
    _speechService.cancel();
    widget.onCancel();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    if (_isListening) {
      _speechService.cancel();
    }
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient background with blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      const Color(0xFF2D1B1A).withValues(alpha: 0.95),
                      const Color(0xFF1A1212).withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with cancel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _cancel,
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white70,
                        iconSize: 28,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Error state or listening state
                if (_error != null)
                  _buildErrorState()
                else
                  _buildListeningState(),
                
                const Spacer(flex: 3),
                
                // Bottom action button
                if (_error == null) _buildBottomAction(),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.mic_off_rounded,
              color: Colors.red,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Voice Input Unavailable',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated microphone with waves
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated waves
              if (_isListening)
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(200, 200),
                      painter: _SoundWavePainter(
                        progress: _waveController.value,
                        color: _primaryColor,
                      ),
                    );
                  },
                ),
              
              // Main mic button
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: child,
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isListening
                          ? [_primaryColorLight, _primaryColor]
                          : [Colors.grey.shade600, Colors.grey.shade700],
                    ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Status text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _isListening ? 'Listening...' : 'Starting...',
            key: ValueKey(_isListening),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Sound bars visualization
        if (_isListening)
          SizedBox(
            height: 32,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final phase = (_waveController.value + index * 0.15) % 1.0;
                    final height = 8 + 16 * math.sin(phase * math.pi);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 4,
                      height: height,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        
        const SizedBox(height: 40),
        
        // Transcript card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? _primaryColor : Colors.grey,
                            boxShadow: _isListening
                                ? [
                                    BoxShadow(
                                      color: _primaryColor.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isListening ? 'Recording' : 'Ready',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        _transcript.isEmpty 
                            ? 'Say something like:\n"Lunch at Jollibee 350 pesos"'
                            : _transcript,
                        key: ValueKey(_transcript.isEmpty),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _transcript.isEmpty ? Colors.white38 : Colors.white,
                          fontStyle: _transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    final hasTranscript = _transcript.isNotEmpty;
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: hasTranscript ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: hasTranscript ? _stopAndSubmit : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: hasTranscript
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8A80), Color(0xFFF06B64)],
                  )
                : null,
            color: hasTranscript ? null : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            boxShadow: hasTranscript
                ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_rounded,
                color: hasTranscript ? Colors.white : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Done',
                style: TextStyle(
                  color: hasTranscript ? Colors.white : Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SoundWavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.33) % 1.0;
      final radius = 50 + 50 * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.6;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
