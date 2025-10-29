// ignore_for_file: use_build_context_synchronously
import 'settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

enum AppThemeMode { system, light, dark }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final seenWelcome = prefs.getBool("seenWelcome") ?? false;
  final themeIndex = prefs.getInt('themeMode') ?? 0;

  runApp(
    MedApp(
      showWelcome: !seenWelcome,
      initialTheme: AppThemeMode.values[themeIndex],
    ),
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(settings);
  }

  Future<void> scheduleWeeklyNotification(
    int id,
    String title,
    String body,
    TimeOfDay time,
    int weekday,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _notifications.zonedSchedule(
      id & 0x7FFFFFFF,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Lembretes',
          channelDescription: 'Notificações de medicamentos',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

class MedApp extends StatefulWidget {
  final bool showWelcome;
  final AppThemeMode initialTheme;

  const MedApp({
    super.key,
    required this.showWelcome,
    required this.initialTheme,
  });

  @override
  State<MedApp> createState() => _MedAppState();
}

class _MedAppState extends State<MedApp> {
  late AppThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialTheme;
  }

  void _changeTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  ThemeMode get currentThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Converte AppThemeMode → ThemeMode
    ThemeMode currentThemeMode;
    switch (_themeMode) {
      case AppThemeMode.light:
        currentThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        currentThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
      default:
        currentThemeMode = ThemeMode.system;
    }

    return MaterialApp(
      title: 'Gerenciador de Medicamentos',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.teal.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF1E164B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E164B),
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: currentThemeMode, // ✅ usa o modo atual
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      routes: {
        '/settings': (context) => SettingsScreen(
          currentTheme: _themeMode,
          onThemeChanged: _changeTheme, // ✅ adiciona callback
        ),
      },
      home: widget.showWelcome
          ? const OnboardingScreen() // ✅ fixo, sempre claro
          : HomeScreen(onThemeChanged: _changeTheme, currentTheme: _themeMode),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "title": "Bem-vindo ao Cuida+",
      "text":
          "Gerencie seus medicamentos de forma prática e segura. Receba lembretes e mantenha sua rotina em dia!",
      "image": "assets/images/logosemitrans.png",
    },
    {
      "title": "Crie seu perfil",
      "text":
          "Adicione um perfil com seu nome ou de quem você cuida. Assim, o app organiza os remédios individualmente.",
    },
    {
      "title": "Cadastre seus medicamentos",
      "text":
          "Informe o nome, dose, horários e dias da semana. O Cuida+ lembra você no momento certo!",
    },
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("seenWelcome", true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          onThemeChanged: (theme) {
            final appState = context.findAncestorStateOfType<_MedAppState>();
            appState?._changeTheme(theme);
          },
          currentTheme: Theme.of(context).brightness == Brightness.dark
              ? AppThemeMode.dark
              : AppThemeMode.light,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.teal.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (page["image"] != null)
                            Image.asset(page["image"]!, height: 180),
                          const SizedBox(height: 30),
                          Text(
                            page["title"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page["text"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Indicadores
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => Container(
                    margin: const EdgeInsets.all(4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.teal
                          : Colors.teal.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Botões
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text(
                        "Pular",
                        style: TextStyle(color: Colors.teal, fontSize: 18),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? "Começar"
                            : "Continuar",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Função auxiliar para formatar dias
String formatarDias(List<bool> days) {
  const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  if (days.every((d) => !d)) return "Nenhum dia";
  if (days.every((d) => d)) return "Todos os dias";
  return [
    for (int i = 0; i < days.length; i++)
      if (days[i]) nomes[i],
  ].join(', ');
}
