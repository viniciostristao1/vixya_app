import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um tema visual do app (cores + degradês). Os 4 escolhidos pelo usuário estão em [kThemes].
class VixyaTheme {
  final String id;
  final String name;
  final String tag;
  final Color bg;
  final Color? bg2; // se != null, o fundo é um degradê bg -> bg2
  final Color surface;
  final Color onBg;
  final Color muted;
  final Color primary;
  final Color primaryOn;
  final Color accent;
  final List<Color>? btnGradient; // botão GERAR em degradê
  final bool glow; // brilho neon no botão (estilo gamer)

  const VixyaTheme({
    required this.id,
    required this.name,
    this.tag = '',
    required this.bg,
    this.bg2,
    required this.surface,
    required this.onBg,
    required this.muted,
    required this.primary,
    required this.primaryOn,
    required this.accent,
    this.btnGradient,
    this.glow = false,
  });

  bool get hasBgGradient => bg2 != null;

  BoxDecoration get backgroundDecoration => hasBgGradient
      ? BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bg, bg2!]))
      : BoxDecoration(color: bg);

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark).copyWith(
      primary: primary,
      onPrimary: primaryOn,
      secondary: accent,
      onSecondary: primaryOn,
      surface: surface,
      onSurface: onBg,
      error: const Color(0xFFEF4444),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent, // o fundo é pintado no builder (permite degradê)
      canvasColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onBg,
        elevation: 0,
        titleTextStyle: TextStyle(color: onBg, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: onBg),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: Typography.whiteMountainView.apply(bodyColor: onBg, displayColor: onBg),
      iconTheme: IconThemeData(color: muted),
      listTileTheme: ListTileThemeData(iconColor: primary, textColor: onBg),
      inputDecorationTheme: InputDecorationTheme(
        border: border(muted),
        enabledBorder: border(muted.withValues(alpha: .6)),
        focusedBorder: border(primary, 2),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: primaryOn)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: onBg, side: BorderSide(color: muted))),
      dropdownMenuTheme:
          DropdownMenuThemeData(menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(surface))),
      snackBarTheme:
          SnackBarThemeData(backgroundColor: surface, contentTextStyle: TextStyle(color: onBg)),
    );
  }
}

const kThemes = <VixyaTheme>[
  VixyaTheme(
      id: 'gamer2',
      name: 'Gamer Vermelho×Azul',
      tag: 'fundo preto + brilho',
      bg: Color(0xFF08070C),
      surface: Color(0xFF15131C),
      onBg: Color(0xFFF2F4FF),
      muted: Color(0xFF6E7391),
      primary: Color(0xFF3B82F6),
      primaryOn: Colors.white,
      accent: Color(0xFFF43F5E),
      btnGradient: [Color(0xFFF43F5E), Color(0xFF3B82F6)],
      glow: true),
  VixyaTheme(
      id: 'cyber',
      name: 'Cyberpunk',
      tag: 'verde neon',
      bg: Color(0xFF0B0F0C),
      surface: Color(0xFF141B15),
      onBg: Color(0xFFEAFFF0),
      muted: Color(0xFF6FA083),
      primary: Color(0xFF00E676),
      primaryOn: Colors.white,
      accent: Color(0xFF00E676),
      glow: true),
  VixyaTheme(
      id: 'sunset',
      name: 'Sunset',
      tag: 'fundo em degradê',
      bg: Color(0xFF3B2A6B),
      bg2: Color(0xFFC0397A),
      surface: Color(0xFF5B2E77),
      onBg: Color(0xFFFFF5FB),
      muted: Color(0xFFE3BFD6),
      primary: Color(0xFFFB7185),
      primaryOn: Color(0xFF2A0A16),
      accent: Color(0xFFFDBA74),
      btnGradient: [Color(0xFFFB923C), Color(0xFFFB7185)]),
];

/// Guarda o tema atual e persiste a escolha. A UI observa [current].
class ThemeController {
  static const _k = 'vixya_theme';
  final ValueNotifier<VixyaTheme> current = ValueNotifier(kThemes.first);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_k);
    current.value = kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);
  }

  Future<void> set(VixyaTheme t) async {
    current.value = t;
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, t.id);
  }
}

final themeCtrl = ThemeController();

/// Botão "GERAR VÍDEO" que respeita o tema: degradê + brilho quando o tema pede.
class GerarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool sending;
  final String label;
  const GerarButton({super.key, required this.onPressed, required this.sending, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = themeCtrl.current.value;
    final fg = t.primaryOn;
    final content = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      sending
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          : Icon(Icons.auto_awesome, color: fg, size: 20),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: .5)),
    ]);
    if (t.btnGradient == null) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: t.primary,
            foregroundColor: fg,
            elevation: t.glow ? 3 : 0,
            shadowColor: t.glow ? t.primary.withValues(alpha: .35) : null),
        child: content,
      );
    }
    return Opacity(
      opacity: onPressed == null ? .45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: t.btnGradient!, begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: t.glow && onPressed != null
              ? [
                  BoxShadow(
                      color: t.primary.withValues(alpha: .28),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 4)),
                  BoxShadow(
                      color: t.accent.withValues(alpha: .18),
                      blurRadius: 10,
                      spreadRadius: -2,
                      offset: const Offset(0, 2)),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Container(height: 54, alignment: Alignment.center, child: content),
          ),
        ),
      ),
    );
  }
}
