import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---------------------------------------------------------------------------
///  Design tokens
/// ---------------------------------------------------------------------------
class OtpColors {
  static const bg = Color(0xFF0B0C0E);
  static const bgTop = Color(0xFF15181C);
  static const card = Color(0xFF131518);
  static const cardBorder = Color(0xFF202328);
  static const tile = Color(0xFF181B1F);
  static const tileBorder = Color(0xFF2A2E34);
  static const tileBorderStrong = Color(0xFF454B53);
  static const focus = Color(0xFFE4E9EF);
  static const text = Color(0xFFF3F5F7);
  static const muted = Color(0xFF8B9199);
  static const faint = Color(0xFF5E646C);
  static const green = Color(0xFF34D399);
  static const greenBright = Color(0xFF4BE3A6);
  static const greenTile = Color(0xFF0E2A20);
  static const red = Color(0xFFF26D6D);
}

/// Set to false (e.g. in widget tests) to skip downloading the font.
bool otpUseGoogleFonts = true;

TextStyle _font({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = OtpColors.text,
  double letterSpacing = 0,
  double? height,
}) {
  final base = TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
  return otpUseGoogleFonts ? GoogleFonts.plusJakartaSans(textStyle: base) : base;
}

enum _Phase { input, verifying, success }

const _correctCode = '4719';
const _codeLength = 4;
const _tileSize = 56.0;
const _tileGap = 12.0;
const _orbitRadius = 74.0;

/// ---------------------------------------------------------------------------
///  Screen
/// ---------------------------------------------------------------------------
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _success = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  _Phase _phase = _Phase.input;
  bool _error = false;
  bool _showMessage = true;
  bool _hasFocus = false;
  Timer? _fillTimer;
  Timer? _resendTimer;
  int _resendSeconds = 25;

  String get _code => _controller.text;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
    });
    _morph.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _phase = _Phase.success);
        HapticFeedback.mediumImpact();
        _success.forward(from: 0);
        _pulse.repeat();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _fillTimer?.cancel();
    _resendTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _blink.dispose();
    _shake.dispose();
    _morph.dispose();
    _success.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- logic --

  void _onChanged(String value) {
    if (_phase != _Phase.input) return;
    HapticFeedback.selectionClick();
    setState(() => _error = false);
    if (value.length == _codeLength) _submit();
  }

  void _submit() {
    if (_code == _correctCode) {
      _fillTimer?.cancel();
      _focusNode.unfocus();
      setState(() {
        _phase = _Phase.verifying;
        _showMessage = false;
      });
      _startResendCountdown();
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted && _phase == _Phase.verifying) _morph.forward(from: 0);
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      _shake.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _controller.clear();
          _error = false;
        });
        _focusNode.requestFocus();
      });
    }
  }

  void _fillFromMessage() {
    if (_phase != _Phase.input) return;
    _fillTimer?.cancel();
    _controller.clear();
    setState(() => _error = false);
    var i = 0;
    _fillTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (!mounted || _phase != _Phase.input) return t.cancel();
      _controller.text = _correctCode.substring(0, i + 1);
      _controller.selection = TextSelection.collapsed(offset: i + 1);
      _onChanged(_controller.text);
      i++;
      if (i >= _codeLength) t.cancel();
    });
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 25);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  void _resend() {
    if (_resendSeconds > 0 || _phase != _Phase.input) return;
    setState(() => _showMessage = true);
  }

  void _reset() {
    _fillTimer?.cancel();
    _resendTimer?.cancel();
    _pulse.stop();
    _morph.reset();
    _success.reset();
    setState(() {
      _controller.clear();
      _phase = _Phase.input;
      _error = false;
      _showMessage = true;
      _resendSeconds = 25;
    });
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.4,
            colors: [OtpColors.bgTop, OtpColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    _card(),
                    const SizedBox(height: 18),
                    _footerHint(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Text(
          'COMPONENT · 89',
          style: _font(size: 11, color: OtpColors.muted, letterSpacing: 3.2),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF8C9DB3), Color(0xFFDCE3EA), Color(0xFFFFFFFF)],
                stops: [0.0, 0.45, 1.0],
              ).createShader(rect),
              child: Text(
                'OTP Verification',
                style: _font(
                  size: 30,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.2,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'v3',
              style: _font(size: 16, weight: FontWeight.w700, color: OtpColors.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget _footerHint() {
    return Text.rich(
      TextSpan(
        style: _font(size: 12.5, color: OtpColors.faint),
        children: [
          const TextSpan(text: 'Type it, paste it, or let the message fill it — '),
          TextSpan(
            text: _correctCode,
            style: _font(size: 12.5, weight: FontWeight.w700, color: OtpColors.muted),
          ),
          const TextSpan(text: ' is the good one.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _card() {
    return Container(
      height: 540,
      decoration: BoxDecoration(
        color: OtpColors.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: OtpColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 20)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2E3238),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 26),
          _titleBlock(),
          Expanded(child: _stage()),
          SizedBox(height: 118, child: _bottomSlot()),
        ],
      ),
    );
  }

  Widget _titleBlock() {
    final success = _phase == _Phase.success;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(success),
        children: [
          Text(
            success ? 'Verified successfully' : 'Verify your number',
            style: _font(
              size: 22,
              weight: FontWeight.w700,
              letterSpacing: -0.6,
              color: success ? OtpColors.green : OtpColors.text,
            ),
          ),
          const SizedBox(height: 10),
          success
              ? Text(
                  'Your number has been verified.',
                  style: _font(size: 13.5, color: OtpColors.muted),
                )
              : Text.rich(
                  TextSpan(
                    style: _font(size: 13.5, color: OtpColors.muted),
                    children: [
                      const TextSpan(text: 'Enter the 4–digit code we sent to '),
                      TextSpan(
                        text: '+1 415 ••• 0142',
                        style: _font(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: const Color(0xFFC9CED4),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- stage --

  Widget _stage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Invisible field that actually receives keyboard / paste / autofill.
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: _phase == _Phase.input,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              showCursor: false,
              enableInteractiveSelection: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              decoration: const InputDecoration.collapsed(hintText: ''),
              onChanged: _onChanged,
            ),
          ),
        ),
        if (_phase == _Phase.input) _inputRow(),
        if (_phase == _Phase.verifying) _morphStage(),
        if (_phase == _Phase.success) _successStage(),
      ],
    );
  }

  Widget _inputRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.unfocus();
        Future.microtask(_focusNode.requestFocus);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_shake, _blink, _controller]),
        builder: (context, _) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_codeLength, (i) {
                final digit = i < _code.length ? _code[i] : null;
                final focused = _hasFocus &&
                    (i == _code.length || (i == _codeLength - 1 && _code.length == _codeLength));
                return Padding(
                  padding: EdgeInsets.only(right: i == _codeLength - 1 ? 0 : _tileGap),
                  child: _InputTile(
                    digit: digit,
                    focused: focused,
                    error: _error,
                    showCursor: focused && digit == null && _blink.value < 0.55,
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _morphStage() {
    return AnimatedBuilder(
      animation: _morph,
      builder: (context, _) => SizedBox(
        width: 300,
        height: 260,
        child: _MorphStage(progress: _morph.value, code: _code),
      ),
    );
  }

  Widget _successStage() {
    return AnimatedBuilder(
      animation: Listenable.merge([_success, _pulse]),
      builder: (context, _) {
        final p = _success.value;
        final check = Curves.easeOutCubic.transform(const Interval(0.05, 0.4).transform(p));
        final glow = const Interval(0.0, 0.5).transform(p);
        return SizedBox(
          width: 300,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SuccessBurstPainter(progress: p, pulse: _pulse.value),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: OtpColors.greenTile,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OtpColors.greenBright, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: OtpColors.green.withValues(alpha: 0.35 * glow),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CustomPaint(painter: _CheckPainter(check)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------- bottom slot --

  Widget _bottomSlot() {
    Widget child;
    if (_phase == _Phase.success) {
      child = AnimatedBuilder(
        key: const ValueKey('success'),
        animation: _success,
        builder: (context, _) {
          final a = Curves.easeOutCubic.transform(const Interval(0.35, 0.75).transform(_success.value));
          final b = Curves.easeOutBack.transform(const Interval(0.45, 0.9).transform(_success.value));
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Opacity(
                opacity: a,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - a)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 15, color: OtpColors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Verified and secure',
                        style: _font(size: 13, weight: FontWeight.w600, color: OtpColors.green),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: b.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.85 + 0.15 * b, child: _ContinueButton(onTap: _reset)),
              ),
              const SizedBox(height: 4),
            ],
          );
        },
      );
    } else if (_showMessage) {
      child = Align(
        key: const ValueKey('message'),
        alignment: Alignment.bottomCenter,
        child: _MessageCard(onFill: _fillFromMessage),
      );
    } else {
      final ready = _resendSeconds <= 0;
      child = Align(
        key: const ValueKey('resend'),
        alignment: const Alignment(0, 0.35),
        child: GestureDetector(
          onTap: _resend,
          child: Text.rich(
            TextSpan(
              style: _font(size: 13.5, color: OtpColors.faint),
              children: [
                const TextSpan(text: "Didn't receive the code?   "),
                TextSpan(
                  text: ready ? 'Resend' : 'Resend in ${_resendSeconds}s',
                  style: _font(
                    size: 13.5,
                    weight: ready ? FontWeight.w700 : FontWeight.w500,
                    color: ready ? OtpColors.text : OtpColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// ---------------------------------------------------------------------------
///  Input tile (row state)
/// ---------------------------------------------------------------------------
class _InputTile extends StatelessWidget {
  const _InputTile({
    required this.digit,
    required this.focused,
    required this.error,
    required this.showCursor,
  });

  final String? digit;
  final bool focused;
  final bool error;
  final bool showCursor;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? OtpColors.red
        : focused
            ? OtpColors.focus
            : digit != null
                ? OtpColors.tileBorderStrong
                : OtpColors.tileBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: focused ? const Color(0xFF1C2025) : OtpColors.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: focused || error ? 1.8 : 1.2),
        boxShadow: [
          if (focused)
            BoxShadow(
              color: const Color(0xFF9FB3C8).withValues(alpha: 0.22),
              spreadRadius: 4,
              blurRadius: 0,
            ),
          if (error)
            BoxShadow(color: OtpColors.red.withValues(alpha: 0.18), spreadRadius: 3),
        ],
      ),
      alignment: Alignment.center,
      child: digit != null
          ? TweenAnimationBuilder<double>(
              key: ValueKey(digit),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - v)),
                  child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
                ),
              ),
              child: Text(
                digit!,
                style: _font(
                  size: 22,
                  weight: FontWeight.w700,
                  color: error ? OtpColors.red : OtpColors.text,
                ),
              ),
            )
          : Opacity(
              opacity: showCursor ? 1 : 0,
              child: Container(
                width: 2,
                height: 22,
                decoration: BoxDecoration(
                  color: OtpColors.focus,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
    );
  }
}

/// ---------------------------------------------------------------------------
///  Morph animation: row → orbit ring → spin → green → spiral collapse
/// ---------------------------------------------------------------------------
class _MorphStage extends StatelessWidget {
  const _MorphStage({required this.progress, required this.code});

  final double progress;
  final String code;

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final t = progress;

    final ringIn = _iv(t, 0.0, 0.14, Curves.easeOutCubic);
    final toOrbit = _iv(t, 0.10, 0.32, Curves.easeOutBack);
    final spin = _iv(t, 0.38, 0.60, Curves.easeInOutCubic);
    final green = _iv(t, 0.56, 0.66, Curves.easeOut);
    final collapse = _iv(t, 0.70, 0.86, Curves.easeInCubic);
    final tilesOut = _iv(t, 0.80, 0.88);
    final core = _iv(t, 0.84, 1.0, Curves.easeOutBack);

    // Starting angles: digit 1 → left, 2 → top, 3 → right, 4 → bottom.
    const baseAngles = [math.pi, -math.pi / 2, 0.0, math.pi / 2];
    final orbit = spin * math.pi / 2 + collapse * math.pi * 1.2;

    final children = <Widget>[];

    // Ring + centre dot.
    final ringOpacity = ringIn * (1 - collapse);
    children.add(Center(
      child: Opacity(
        opacity: ringOpacity,
        child: Transform.scale(
          scale: (0.7 + 0.3 * ringIn) * (1 - 0.6 * collapse),
          child: Container(
            width: _orbitRadius * 2,
            height: _orbitRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.12),
                  OtpColors.green.withValues(alpha: 0.35),
                  green,
                )!,
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    ));
    children.add(Center(
      child: Opacity(
        opacity: toOrbit.clamp(0.0, 1.0) * (1 - tilesOut),
        child: Container(
          width: 5 + green,
          height: 5 + green,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(const Color(0xFFB8BEC6), Colors.white, green),
          ),
        ),
      ),
    ));

    // Tiles.
    for (var i = 0; i < _codeLength; i++) {
      final rowPos = Offset((i - 1.5) * (_tileSize + _tileGap), 0);
      final radius = _orbitRadius * (1 - collapse);
      final orbitPos = Offset.fromDirection(baseAngles[i] + orbit, radius);
      final pos = Offset.lerp(rowPos, orbitPos, toOrbit)!;

      final tilt = math.sin(spin * math.pi) * 0.75 + collapse * math.pi * 1.5;
      final scale = (1 + 0.04 * math.sin(toOrbit * math.pi)) * (1 - 0.65 * collapse);

      children.add(Center(
        child: Transform.translate(
          offset: pos,
          child: Opacity(
            opacity: 1 - tilesOut,
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: scale,
                child: _MorphTile(digit: i < code.length ? code[i] : '', green: green),
              ),
            ),
          ),
        ),
      ));
    }

    // Empty green core that the success state grows from.
    if (core > 0) {
      children.add(Center(
        child: Opacity(
          opacity: core.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: (1 - core) * math.pi / 2,
            child: Transform.scale(
              scale: 0.25 + 0.75 * core,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: OtpColors.greenTile.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OtpColors.greenBright, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: OtpColors.green.withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class _MorphTile extends StatelessWidget {
  const _MorphTile({required this.digit, required this.green});

  final String digit;
  final double green;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _tileSize,
      height: _tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(OtpColors.tile, OtpColors.greenTile, green),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.lerp(OtpColors.tileBorderStrong, OtpColors.green, green)!,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: OtpColors.green.withValues(alpha: 0.28 * green),
            blurRadius: 16,
          ),
          const BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        digit,
        style: _font(
          size: 22,
          weight: FontWeight.w700,
          color: Color.lerp(OtpColors.text, const Color(0xFFD9FBEA), green)!,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
///  Success visuals
/// ---------------------------------------------------------------------------
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = size.center(Offset.zero);
    final path = Path()
      ..moveTo(c.dx - 8, c.dy + 0.5)
      ..lineTo(c.dx - 2.5, c.dy + 6)
      ..lineTo(c.dx + 8.5, c.dy - 5.5);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

class _Particle {
  _Particle(math.Random r)
      : angle = r.nextDouble() * math.pi * 2,
        distance = 72 + r.nextDouble() * 70,
        size = 1.2 + r.nextDouble() * 1.8,
        alpha = 0.35 + r.nextDouble() * 0.6,
        phase = r.nextDouble() * math.pi * 2,
        delay = r.nextDouble() * 0.2;

  final double angle, distance, size, alpha, phase, delay;
}

final List<_Particle> _particles = List.generate(26, (_) => _Particle(_rng));
final math.Random _rng = math.Random(89);

class _SuccessBurstPainter extends CustomPainter {
  _SuccessBurstPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ringT = Curves.easeOutCubic.transform(const Interval(0.0, 0.55).transform(progress));

    // Expanding pulse ripple.
    final rippleSize = ui.lerpDouble(64, 230, pulse)!;
    _roundedSquare(
      canvas,
      c,
      rippleSize,
      18 + rippleSize * 0.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = OtpColors.green.withValues(alpha: 0.22 * (1 - pulse) * ringT),
    );

    // Concentric rounded squares.
    const rings = [(116.0, 34.0, 0.10), (170.0, 48.0, 0.06)];
    for (var i = 0; i < rings.length; i++) {
      final (s, r, a) = rings[i];
      final t = Curves.easeOutBack.transform(
        Interval(0.05 * i, 0.5 + 0.08 * i).transform(progress),
      );
      final breathe = 1 + 0.015 * math.sin(pulse * math.pi * 2 + i);
      final sz = s * (0.6 + 0.4 * t) * breathe;
      _roundedSquare(
        canvas,
        c,
        sz,
        r,
        Paint()..color = OtpColors.green.withValues(alpha: a * 0.35 * ringT),
      );
      _roundedSquare(
        canvas,
        c,
        sz,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = OtpColors.green.withValues(alpha: (a + 0.08) * ringT),
      );
    }

    // Particles flung outward, then drifting.
    for (final p in _particles) {
      final t = Curves.easeOutCubic.transform(
        Interval(p.delay, (p.delay + 0.6).clamp(0.0, 1.0)).transform(progress),
      );
      if (t <= 0) continue;
      final drift = math.sin(pulse * math.pi * 2 + p.phase) * 4;
      final d = ui.lerpDouble(36, p.distance, t)! + drift;
      final pos = c + Offset.fromDirection(p.angle + pulse * 0.15, d);
      canvas.drawCircle(
        pos,
        p.size,
        Paint()..color = OtpColors.greenBright.withValues(alpha: p.alpha * t),
      );
    }
  }

  void _roundedSquare(Canvas canvas, Offset c, double size, double radius, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: size, height: size),
        Radius.circular(radius),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SuccessBurstPainter old) =>
      old.progress != progress || old.pulse != pulse;
}

/// ---------------------------------------------------------------------------
///  Message card + Continue button
/// ---------------------------------------------------------------------------
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.onFill});
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181B1F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF262A30)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE6EEF7), Color(0xFF9FB6CF)],
              ),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: Color(0xFF1C2430)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MESSAGE · OTP',
                  style: _font(size: 10.5, weight: FontWeight.w600, color: OtpColors.muted, letterSpacing: 1.6),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: _font(size: 14, color: const Color(0xFFD5DAE0)),
                    children: [
                      TextSpan(
                        text: _correctCode,
                        style: _font(size: 14, weight: FontWeight.w800, color: OtpColors.text),
                      ),
                      const TextSpan(text: ' is your verification code.'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PressableScale(
            onTap: onFill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                'Fill',
                style: _font(size: 14, weight: FontWeight.w700, color: const Color(0xFF111316)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: OtpColors.green.withValues(alpha: 0.55), width: 1.4),
        ),
        child: Container(
          width: 150,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3FE0A3), Color(0xFF22B97C)],
            ),
            boxShadow: [
              BoxShadow(color: OtpColors.green.withValues(alpha: 0.35), blurRadius: 18),
            ],
          ),
          child: Text(
            'Continue',
            style: _font(size: 14.5, weight: FontWeight.w700, color: const Color(0xFF062A1B)),
          ),
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
