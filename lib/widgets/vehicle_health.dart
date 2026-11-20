import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'ui.dart';

/// One detected problem on a vehicle.
class VehicleIssue {
  final String zone; // engine | fuel | service | signal | alerts
  final String level; // CRITICAL | WARNING | INFO
  final String title;
  final String detail;
  final IconData icon;

  const VehicleIssue({
    required this.zone,
    required this.level,
    required this.title,
    required this.detail,
    required this.icon,
  });

  Color get color => issueColor(level);
}

Color issueColor(String level) {
  switch (level) {
    case 'CRITICAL':
      return AppColors.error;
    case 'WARNING':
      return AppColors.warning;
    default:
      return AppColors.primary;
  }
}

int _levelRank(String l) => l == 'CRITICAL' ? 0 : (l == 'WARNING' ? 1 : 2);

/// Derives the problems of a vehicle from its real telemetry, open alerts and
/// maintenance rules. Nothing here is invented: no data means no issue.
List<VehicleIssue> vehicleIssues(Vehicle v, List<AlertItem> alerts, List<RuleView> rules) {
  final out = <VehicleIssue>[];

  final temp = v.temp;
  if (temp != null && temp >= 105) {
    out.add(VehicleIssue(
        zone: 'engine',
        level: 'CRITICAL',
        title: 'Engine overheating',
        detail: '${temp.toStringAsFixed(0)} °C, above the safe limit',
        icon: Icons.thermostat_rounded));
  } else if (temp != null && temp >= 95) {
    out.add(VehicleIssue(
        zone: 'engine',
        level: 'WARNING',
        title: 'Engine running hot',
        detail: '${temp.toStringAsFixed(0)} °C, keep an eye on it',
        icon: Icons.thermostat_rounded));
  }

  final fuel = v.fuel;
  if (fuel != null && fuel < 15) {
    out.add(VehicleIssue(
        zone: 'fuel',
        level: 'CRITICAL',
        title: 'Very low fuel',
        detail: '${fuel.toStringAsFixed(0)}% left, refuel now',
        icon: Icons.local_gas_station_rounded));
  } else if (fuel != null && fuel < 30) {
    out.add(VehicleIssue(
        zone: 'fuel',
        level: 'WARNING',
        title: 'Low fuel',
        detail: '${fuel.toStringAsFixed(0)}% left',
        icon: Icons.local_gas_station_rounded));
  }

  for (final r in rules.where((r) => r.vehicleId == v.id)) {
    if (r.status == 'DUE') {
      out.add(VehicleIssue(
          zone: 'service',
          level: 'CRITICAL',
          title: '${r.name} overdue',
          detail: '${(-r.remaining).toStringAsFixed(0)} ${r.unit} past the interval',
          icon: Icons.build_rounded));
    } else if (r.status == 'DUE_SOON') {
      out.add(VehicleIssue(
          zone: 'service',
          level: 'WARNING',
          title: '${r.name} due soon',
          detail: '${r.remaining.toStringAsFixed(0)} ${r.unit} left',
          icon: Icons.build_rounded));
    }
  }

  final open = alerts.where((a) => a.vehicleId == v.id && !a.acknowledged).toList();
  if (open.isNotEmpty) {
    final worst = open.map((a) => a.severity).reduce((a, b) => _levelRank(a) <= _levelRank(b) ? a : b);
    out.add(VehicleIssue(
        zone: 'alerts',
        level: worst == 'CRITICAL' || worst == 'WARNING' ? worst : 'INFO',
        title: open.length == 1 ? '1 open alert' : '${open.length} open alerts',
        detail: open.first.message,
        icon: Icons.notifications_active_rounded));
  }

  if (v.status == 'OFFLINE') {
    out.add(const VehicleIssue(
        zone: 'signal',
        level: 'WARNING',
        title: 'No telemetry signal',
        detail: 'The vehicle is not reporting data',
        icon: Icons.signal_wifi_off_rounded));
  }

  out.sort((a, b) => _levelRank(a.level).compareTo(_levelRank(b.level)));
  return out;
}

/// Compact issue pills for list cards.
class IssueChips extends StatelessWidget {
  final List<VehicleIssue> issues;
  const IssueChips({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (issues.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text('No issues detected', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
        ],
      );
    }
    final shown = issues.take(2).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final i in shown) StatusChip(label: i.title, color: i.color),
        if (issues.length > shown.length)
          StatusChip(label: '+${issues.length - shown.length} more', color: AppColors.offline),
      ],
    );
  }
}

/// Side-view vehicle with its problem zones highlighted, plus the issue list.
class VehicleHealthView extends StatelessWidget {
  final Vehicle vehicle;
  final List<VehicleIssue> issues;
  const VehicleHealthView({super.key, required this.vehicle, required this.issues});

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final problems = issues.where((i) => i.level != 'INFO').length;
    final headColor = issues.isEmpty
        ? AppColors.success
        : (issues.first.level == 'CRITICAL' ? AppColors.error : (issues.first.level == 'WARNING' ? AppColors.warning : AppColors.primary));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Vehicle health', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            StatusChip(
              label: issues.isEmpty ? 'Healthy' : (problems == 0 ? 'Notice' : '$problems ${problems == 1 ? 'issue' : 'issues'}'),
              color: headColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        VehicleCarArt(vehicle: v, issues: issues),
        const SizedBox(height: 8),
        if (issues.isEmpty)
          _IssueRow(
            issue: const VehicleIssue(
              zone: 'none',
              level: 'OK',
              title: 'No issues detected',
              detail: 'Engine, fuel and service are within normal limits',
              icon: Icons.check_circle_rounded,
            ),
            color: AppColors.success,
          )
        else
          for (var i = 0; i < issues.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            _IssueRow(issue: issues[i], color: issues[i].color),
          ],
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  final VehicleIssue issue;
  final Color color;
  const _IssueRow({required this.issue, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        IconBadge(icon: issue.icon, color: color, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(issue.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Luxury four-door coupe, side view, drawn in a 600x300 unit canvas (front on the right).
/// The zones with a problem are tinted on the body itself.
class _CarPainter extends CustomPainter {
  final bool zones;
  final bool dark;
  final Color surface;
  final Color ground;
  final Color label;
  final Color engine;
  final Color service;
  final Color fuel;

  _CarPainter({
    required this.zones,
    required this.dark,
    required this.surface,
    required this.ground,
    required this.label,
    required this.engine,
    required this.service,
    required this.fuel,
  });

  static const double _gy = 262; // ground line
  static const double _wy = 225; // wheel centre y
  static const List<double> _wx = [140, 470];

  static bool _bad(Color c) => c == AppColors.error || c == AppColors.warning;

  static Path _bodyPath() => Path()
    ..moveTo(46, 236)
    ..lineTo(42, 202)
    ..cubicTo(41, 184, 44, 172, 52, 167)
    ..cubicTo(80, 160, 110, 156, 130, 152)
    ..cubicTo(170, 138, 210, 108, 286, 102)
    ..lineTo(342, 103)
    ..cubicTo(372, 106, 396, 130, 426, 152)
    ..cubicTo(470, 158, 512, 166, 538, 176)
    ..cubicTo(552, 182, 560, 192, 562, 206)
    ..lineTo(562, 228)
    ..cubicTo(562, 234, 558, 237, 550, 237)
    ..close();

  Path get _rearGlass => Path()
    ..moveTo(148, 152)
    ..cubicTo(180, 128, 216, 114, 258, 111)
    ..lineTo(258, 152)
    ..close();

  Path get _frontGlass => Path()
    ..moveTo(272, 152)
    ..lineTo(272, 111)
    ..lineTo(338, 111)
    ..cubicTo(364, 114, 386, 132, 406, 152)
    ..close();

  Paint _fill(Color c) => Paint()..color = c..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  LinearGradient _vertical(List<Color> colors, [List<double>? stops]) =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 600);
    if (!zones) canvas.translate(0, -78);

    final paint = dark
        ? const [Color(0xFFF4F6FA), Color(0xFFCFD6E0), Color(0xFF98A3B4), Color(0xFF5D687A), Color(0xFF3B4454)]
        : const [Color(0xFF7B8FB3), Color(0xFF3E4F70), Color(0xFF1F2B42), Color(0xFF111A2B), Color(0xFF0A111E)];
    final glassColors = dark
        ? const [Color(0xFF1C2433), Color(0xFF05080D)]
        : const [Color(0xFFAEBFD6), Color(0xFF41536F)];
    final archColor = dark ? const Color(0xFF04060A) : const Color(0xFF05080F);
    final tyre = dark ? const Color(0xFF06080C) : const Color(0xFF0A0F18);

    // ground shadow + line
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(306, _gy), width: 580, height: 20),
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x8C000000), Color(0x00000000)])
              .createShader(Rect.fromCenter(center: const Offset(306, _gy), width: 580, height: 20)));
    canvas.drawLine(const Offset(10, _gy), const Offset(590, _gy), _stroke(ground, 1.5));
    for (final x in _wx) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, _gy - 1), width: 80, height: 8),
          _fill(const Color(0x8C000000)));
    }

    // body
    final body = _bodyPath();
    canvas.drawPath(
        body,
        Paint()
          ..shader = _vertical(paint, const [0, .3, .55, .8, 1]).createShader(const Rect.fromLTRB(0, 106, 600, 238))
          ..isAntiAlias = true);

    canvas.save();
    canvas.clipPath(body);
    // light band along the shoulder
    final band = Path()
      ..moveTo(40, 178)
      ..cubicTo(200, 170, 400, 170, 570, 192)
      ..lineTo(570, 206)
      ..cubicTo(400, 188, 200, 186, 40, 196)
      ..close();
    canvas.drawPath(
        band,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0x2EFFFFFF), Color(0x00FFFFFF)],
                  stops: [0, .25, .6, 1])
              .createShader(const Rect.fromLTRB(40, 170, 570, 206)));
    // darker lower body
    canvas.drawRect(const Rect.fromLTRB(40, 212, 570, 240), _fill(const Color(0x29000000)));
    canvas.drawRect(const Rect.fromLTRB(40, 226, 570, 240), _fill(const Color(0x38000000)));
    // wheel arches
    for (final x in _wx) {
      canvas.drawCircle(Offset(x, _wy), 45, _fill(archColor));
      canvas.drawCircle(Offset(x, _wy), 45, _stroke(const Color(0x99000000), 4));
    }
    canvas.restore();

    // character line + outline
    final crease = Path()
      ..moveTo(70, 193)
      ..cubicTo(200, 177, 380, 177, 536, 197);
    canvas.drawPath(crease, _stroke(const Color(0x8CFFFFFF), 1.4));
    canvas.drawPath(body, _stroke(const Color(0x66000000), 1.4));

    // glass
    final frame = Path()
      ..addPath(_rearGlass, Offset.zero)
      ..addPath(_frontGlass, Offset.zero);
    canvas.drawPath(frame, _stroke(const Color(0xFF05080D), 5));
    final glassPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: glassColors)
          .createShader(const Rect.fromLTRB(148, 110, 406, 152));
    canvas.drawPath(_rearGlass, glassPaint);
    canvas.drawPath(_frontGlass, glassPaint);
    canvas.drawPath(
        Path()
          ..moveTo(180, 150)
          ..lineTo(214, 122)
          ..lineTo(228, 120)
          ..lineTo(198, 150)
          ..close(),
        _fill(const Color(0x29FFFFFF)));
    canvas.drawPath(
        Path()
          ..moveTo(288, 150)
          ..lineTo(308, 116)
          ..lineTo(320, 116)
          ..lineTo(304, 150)
          ..close(),
        _fill(const Color(0x24FFFFFF)));

    // beltline, sill, door cuts, handles, mirror
    canvas.drawLine(const Offset(100, 158), const Offset(424, 156), _stroke(const Color(0xE6E5E9F0), 2));
    canvas.drawLine(const Offset(120, 233), const Offset(440, 233), _stroke(const Color(0x8CD9DEE7), 2));
    final cut = _stroke(const Color(0x73000000), 1.2);
    canvas.drawLine(const Offset(265, 160), const Offset(265, 230), cut);
    canvas.drawPath(Path()..moveTo(118, 162)..cubicTo(112, 190, 114, 212, 118, 228), cut);
    canvas.drawPath(Path()..moveTo(398, 160)..cubicTo(406, 190, 404, 214, 400, 228), cut);
    for (final x in [206.0, 296.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 174, 28, 6), const Radius.circular(3)),
          _fill(const Color(0xFFDFE5EE)));
    }
    final mirror = Path()
      ..moveTo(392, 150)
      ..lineTo(414, 148)
      ..cubicTo(420, 150, 419, 158, 414, 160)
      ..lineTo(396, 161)
      ..close();
    canvas.drawPath(mirror, _fill(dark ? const Color(0xFFB4BDCB) : const Color(0xFF2A3854)));
    canvas.drawPath(mirror, _stroke(const Color(0x80000000), 1));

    // tail light
    final tail = Path()
      ..moveTo(43, 176)
      ..lineTo(76, 168)
      ..lineTo(78, 180)
      ..lineTo(44, 192)
      ..close();
    canvas.drawPath(
        tail,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF7F1018), Color(0xFFEF4444)])
              .createShader(const Rect.fromLTRB(43, 168, 78, 192)));
    canvas.drawLine(const Offset(48, 182), const Offset(74, 173), _stroke(const Color(0xFFFECACA), 1.6));

    // headlight, grille, fog light
    final head = Path()
      ..moveTo(522, 172)
      ..lineTo(552, 180)
      ..cubicTo(558, 184, 561, 190, 561, 198)
      ..lineTo(528, 190)
      ..close();
    canvas.drawPath(
        head,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF1B2433), Color(0xFFE8EEF9)])
              .createShader(const Rect.fromLTRB(522, 172, 561, 198)));
    canvas.drawPath(head, _stroke(const Color(0xFF0B1220), 1));
    canvas.drawCircle(const Offset(543, 186), 3.4, _fill(Colors.white));
    canvas.drawCircle(const Offset(553, 190), 3, _fill(Colors.white));
    canvas.drawLine(const Offset(526, 176), const Offset(556, 183), _stroke(Colors.white, 2));
    canvas.drawPath(
        Path()
          ..moveTo(541, 203)
          ..lineTo(561, 205)
          ..lineTo(561, 225)
          ..lineTo(543, 225)
          ..close(),
        _fill(const Color(0xFF070B12)));
    for (final y in [208.0, 213.0, 218.0]) {
      canvas.drawLine(Offset(545, y), Offset(561, y + 1), _stroke(const Color(0xFFAAB4C3), 1));
    }
    canvas.drawOval(Rect.fromCenter(center: const Offset(533, 222), width: 12, height: 6), _fill(const Color(0xFFFDE68A)));

    // wheels
    for (final x in _wx) {
      _wheel(canvas, x, tyre);
    }

    // problem zones tinted on the body
    canvas.save();
    canvas.clipPath(body);
    void tint(Offset c, double rx, double ry, Color col, double a) {
      canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), _fill(col.withAlpha((a * 255).round())));
    }

    if (_bad(engine)) tint(const Offset(486, 176), 70, 34, engine, .38);
    if (_bad(fuel)) tint(const Offset(90, 196), 44, 30, fuel, .34);
    if (_bad(service)) tint(const Offset(300, 202), 60, 28, service, .30);
    canvas.restore();

    if (!zones) return;
    // zone markers
    _zone(canvas, const Offset(90, 198), fuel, 'Fuel', 176);
    _zone(canvas, const Offset(300, 202), service, 'Service', 184);
    _zone(canvas, const Offset(486, 178), engine, 'Engine', 158);
  }

  void _wheel(Canvas canvas, double cx, Color tyre) {
    final c = Offset(cx, _wy);
    final rim = Paint()
      ..shader = const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFC3CAD5), Color(0xFF7E8896)])
          .createShader(Rect.fromCircle(center: c, radius: 30));
    canvas.drawCircle(c, 37, _fill(tyre));
    canvas.drawCircle(c, 34.5, _stroke(const Color(0xFF2A3342), 1.6));
    canvas.drawCircle(c, 31, _stroke(const Color(0x80000000), 2));
    canvas.drawCircle(c, 28.5, rim);
    canvas.drawCircle(c, 25, _fill(const Color(0xFF0A0F18)));
    canvas.drawCircle(c, 20, _fill(const Color(0xFF59616F)));
    canvas.drawCircle(c, 20, _stroke(const Color(0xFF2D3541), 2.5));
    // brake caliper
    canvas.drawArc(Rect.fromCircle(center: c, radius: 20), -1.2, 0.95, false, _stroke(const Color(0xFFE11D2E), 5));
    // spokes
    for (var i = 0; i < 5; i++) {
      for (final off in [-9.0, 9.0]) {
        canvas.save();
        canvas.translate(cx, _wy);
        canvas.rotate((i * 72 + off) * 3.1415926535 / 180);
        final spoke = Path()
          ..moveTo(-2.4, -8)
          ..lineTo(-3.6, -27)
          ..lineTo(3.6, -27)
          ..lineTo(2.4, -8)
          ..close();
        canvas.drawPath(spoke, rim);
        canvas.drawPath(spoke, _stroke(const Color(0xFF6B7686), .5));
        canvas.restore();
      }
    }
    canvas.drawCircle(c, 7.5, rim);
    canvas.drawCircle(c, 3, _fill(const Color(0xFF0A0F18)));
  }

  void _zone(Canvas canvas, Offset o, Color c, String text, double lineEnd) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: _bad(c) ? c : label)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(o.dx - tp.width / 2, 6));

    // dashed leader line
    final dash = _stroke(c, 1.8);
    var y = 34.0;
    while (y < lineEnd) {
      canvas.drawLine(Offset(o.dx, y), Offset(o.dx, (y + 3).clamp(0, lineEnd).toDouble()), dash);
      y += 7;
    }

    final bad = _bad(c);
    canvas.drawCircle(o, bad ? 26 : 22, _fill(c.withAlpha(bad ? 56 : 64)));
    canvas.drawCircle(o, 13, _fill(surface));
    canvas.drawCircle(o, 10, _fill(c));
    if (bad) {
      final mark = TextPainter(
        text: const TextSpan(text: '!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      mark.paint(canvas, Offset(o.dx - mark.width / 2, o.dy - mark.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) =>
      old.engine != engine ||
      old.service != service ||
      old.fuel != fuel ||
      old.zones != zones ||
      old.dark != dark ||
      old.surface != surface ||
      old.ground != ground ||
      old.label != label;
}

/// Colour of one zone: the worst issue in it, green when healthy, grey when there is no data.
Color zoneColor(List<VehicleIssue> issues, String zone, bool hasData) {
  final z = issues.where((i) => i.zone == zone).toList();
  if (z.isNotEmpty) return z.first.color; // list is sorted by severity
  return hasData ? AppColors.success : AppColors.offline;
}

/// The vehicle illustration. With [zones] it shows the Fuel / Service / Engine markers;
/// without it, a cropped hero version. Zones with a problem are tinted on the body.
class VehicleCarArt extends StatelessWidget {
  final Vehicle? vehicle;
  final List<VehicleIssue> issues;
  final bool zones;
  final bool? dark;
  const VehicleCarArt({super.key, this.vehicle, this.issues = const [], this.zones = true, this.dark});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 600 / (zones ? 300 : 190),
      child: RepaintBoundary(
        child: CustomPaint(
        painter: _CarPainter(
          zones: zones,
          dark: isDark,
          surface: p.surface,
          ground: zones ? p.border : const Color(0x33FFFFFF),
          label: p.textSecondary,
          engine: zoneColor(issues, 'engine', vehicle?.temp != null),
          service: zoneColor(issues, 'service', true),
          fuel: zoneColor(issues, 'fuel', vehicle?.fuel != null),
        ),
        ),
      ),
    );
  }
}

/// Dusk sky with mountains, used behind the car in hero headers.
class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.expand(child: CustomPaint(painter: _SkyPainter()));
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1C2745), Color(0xFF4B5B88), Color(0xFFD49A8C), Color(0xFFE8B79B)],
            stops: [0, .55, .85, 1],
          ).createShader(Offset.zero & size));
    Path ridge(List<List<double>> pts) {
      final path = Path()..moveTo(0, h * pts.first[1]);
      for (final pt in pts) {
        path.lineTo(w * pt[0], h * pt[1]);
      }
      return path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    canvas.drawPath(
        ridge([[0, .66], [.15, .57], [.28, .63], [.46, .5], [.64, .62], [.82, .54], [1, .63]]),
        Paint()..color = const Color(0xD92C3A5E));
    canvas.drawPath(
        ridge([[0, .75], [.2, .67], [.38, .74], [.59, .645], [.8, .72], [1, .67]]),
        Paint()..color = const Color(0xE61E2A48));
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}
