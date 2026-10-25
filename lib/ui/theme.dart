import 'package:flutter/material.dart';

const forest = Color(0xFF294D3A);
const olive = Color(0xFF81864E);
const cream = Color(0xFFF6F5EF);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: forest,
    brightness: brightness,
    primary: dark ? const Color(0xFFB5D2A9) : forest,
    primaryContainer: dark ? const Color(0xFF354633) : const Color(0xFFE3E6D0),
    secondary: dark ? const Color(0xFFD2D6A5) : olive,
    surface: dark ? const Color(0xFF171C18) : cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF232B24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF232B24) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .6),
      thickness: 1,
    ),
  );
}

class DoorMark extends StatelessWidget {
  const DoorMark({super.key, this.size = 52, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bible Door',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? Colors.white.withValues(alpha: .13) : forest,
        borderRadius: BorderRadius.circular(size * .25),
      ),
      child: CustomPaint(painter: _DoorPainter()),
    ),
  );
}

class _DoorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF3EAC4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * .29, h * .77)
        ..lineTo(w * .29, h * .25)
        ..lineTo(w * .7, h * .25)
        ..lineTo(w * .7, h * .77),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .39, h * .75)
        ..lineTo(w * .39, h * .28)
        ..lineTo(w * .63, h * .36)
        ..lineTo(w * .63, h * .83)
        ..close(),
      paint,
    );
    canvas.drawCircle(
      Offset(w * .55, h * .57),
      w * .025,
      Paint()..color = const Color(0xFFF3EAC4),
    );
    canvas.drawLine(Offset(w * .21, h * .78), Offset(w * .32, h * .78), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.eyebrow, this.title, this.subtitle, {super.key});
  final String eyebrow, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.6),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 24), child: action),
          ],
        ),
      ),
    ),
  );
}
