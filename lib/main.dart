// ignore_for_file: use_build_context_synchronously, avoid_print
import 'dart:async';
import 'dart:io';
import 'settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'models/medic.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppThemeMode { system, light, dark }

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar timezone uma vez apenas
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  // Inicializar notificações
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

@pragma('vm:entry-point')
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  @pragma('vm:entry-point')
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print('📱 Notificação clicada: ${details.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
    );

    // Criar canal de notificação para Android 8.0+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminder_channel',
      'Lembretes',
      description: 'Notificações de medicamentos',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      showBadge: true,
      ledColor: Color(0xFF008080),
      enableLights: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(channel);

    // Solicitar permissões para Android 13+
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
      await requestDisableBatteryOptimization();
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotification(NotificationResponse details) {
    print('📱 Notificação em background: ${details.payload}');
  }

  Future<bool> _requestAndroidPermissions() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;

      // Android 13+ (API 33+) requer permissão POST_NOTIFICATIONS
      if (androidInfo.version.sdkInt >= 33) {
        print('📱 Android 13+ detectado, solicitando permissões...');

        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          print('📱 Permissão Android 13+: $granted');
          return granted ?? false; // ← CORREÇÃO AQUI: converter null para false
        }
      }

      return true;
    } catch (e) {
      print('❌ Erro ao solicitar permissões Android: $e');
      return false; // ← CORREÇÃO AQUI: retornar false em caso de erro
    }
  }

  Future<void> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return;

    try {
      // Verifica se já está desativado
      final status = await Permission.ignoreBatteryOptimizations.status;

      if (status.isGranted) {
        print("🔋 Otimização de bateria já está desativada.");
        return;
      }

      print("🔋 Solicitando para desativar otimização de bateria...");

      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.example.cuida_mais',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );

      await intent.launch();
    } catch (e) {
      print("❌ Erro ao solicitar desativação da otimização: $e");
    }
  }

  Future<bool> checkNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidPlugin != null) {
          final granted = await androidPlugin.areNotificationsEnabled();
          print('🔔 Notificações habilitadas: $granted');
          return granted ?? false; // ← CORREÇÃO AQUI
        }
      }
      return true;
    } catch (e) {
      print('❌ Erro ao verificar permissão: $e');
      return false; // ← CORREÇÃO AQUI
    }
  }

  @pragma('vm:entry-point')
  Future<void> scheduleAndroidNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required List<bool> daysOfWeek,
    String? payload,
  }) async {
    try {
      // Verificar permissão primeiro
      final hasPermission = await checkNotificationPermission();
      if (!hasPermission) {
        print('⚠️ Permissão de notificação negada');
        return;
      }

      final now = tz.TZDateTime.now(tz.local);

      // Para cada dia da semana selecionado
      for (int weekday = 0; weekday < daysOfWeek.length; weekday++) {
        if (daysOfWeek[weekday]) {
          // weekday: 0=Segunda, 6=Domingo
          // converter para 1=Segunda, 7=Domingo
          final scheduleWeekday = weekday + 1;

          // Calcular próxima data para este dia da semana
          tz.TZDateTime scheduledDate = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            time.hour,
            time.minute,
          );

          // Ajustar para o próximo dia correto da semana
          int daysToAdd = (scheduleWeekday - scheduledDate.weekday) % 7;
          if (daysToAdd < 0) daysToAdd += 7;
          scheduledDate = scheduledDate.add(Duration(days: daysToAdd));

          // Se já passou, semana que vem
          if (scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 7));
          }

          print(
            '📅 Agendando: $title para $scheduledDate (Dia $scheduleWeekday)',
          );

          // Configuração para Android 12+
          final androidDetails = AndroidNotificationDetails(
            'reminder_channel',
            'Lembretes',
            channelDescription: 'Notificações de medicamentos',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            timeoutAfter: 60000, // 1 minuto
            fullScreenIntent: true,
            setAsGroupSummary: true,
            groupAlertBehavior: GroupAlertBehavior.all,
            color: const Color(0xFF008080),
            visibility: NotificationVisibility.public,
          );

          await _notifications.zonedSchedule(
            id + weekday, // ID único para cada dia
            title,
            body,
            scheduledDate,
            NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payload,
          );

          print('✅ Agendada para $scheduledDate');
        }
      }

      // Verificar notificações pendentes
      await _logPendingNotifications();
    } catch (e) {
      print('❌ Erro ao agendar: $e');

      // Fallback: mostrar notificação imediata de erro
      await showTestNotification(
        title: 'Erro no agendamento',
        body: 'Mas as notificações instantâneas funcionam!',
      );
    }
  }

  Future<void> _logPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      print('📋 Notificações pendentes: ${pending.length}');

      if (pending.isNotEmpty) {
        for (var notif in pending.take(5)) {
          // Mostrar apenas 5
          print('   ID: ${notif.id} - ${notif.title}');
        }
      }
    } catch (e) {
      print('❌ Erro ao verificar pendentes: $e');
    }
  }

  Future<void> showTestNotification({
    String title = 'Teste de Notificação',
    String body = 'Se você está vendo isso, as notificações estão funcionando!',
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Lembretes',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🗑️ Todas notificações canceladas');
  }

  @pragma('vm:entry-point')
  Future<void> scheduleMedicationNotifications(Medicine med) async {
    try {
      if (med.id == null) {
        print('⚠️ Medicamento sem ID');
        return;
      }

      print('💊 Agendando: ${med.medName} com tipo: ${med.notificationType}');

      // Usar o tipo de notificação do medicamento
      if (med.notificationType != NotificationType.none) {
        // Para cada horário
        for (int i = 0; i < med.medTimes.length; i++) {
          final time = med.medTimes[i];
          TimeOfDay notificationTime = time;

          // Ajustar baseado no tipo
          if (med.notificationType == NotificationType.early) {
            int totalMinutes = time.hour * 60 + time.minute - 5;
            notificationTime = TimeOfDay(
              hour: (totalMinutes ~/ 60) % 24,
              minute: totalMinutes % 60,
            );
          } else if (med.notificationType == NotificationType.late) {
            int totalMinutes = time.hour * 60 + time.minute + 5;
            notificationTime = TimeOfDay(
              hour: (totalMinutes ~/ 60) % 24,
              minute: totalMinutes % 60,
            );
          }

          // Para cada dia da semana
          for (int weekday = 0; weekday < med.daysOfWeek.length; weekday++) {
            if (med.daysOfWeek[weekday]) {
              final scheduleWeekday = weekday + 1;
              final now = tz.TZDateTime.now(tz.local);

              tz.TZDateTime scheduledDate = tz.TZDateTime(
                tz.local,
                now.year,
                now.month,
                now.day,
                notificationTime.hour,
                notificationTime.minute,
              );

              int daysToAdd = (scheduleWeekday - scheduledDate.weekday) % 7;
              if (daysToAdd < 0) daysToAdd += 7;
              scheduledDate = scheduledDate.add(Duration(days: daysToAdd));

              if (scheduledDate.isBefore(now)) {
                scheduledDate = scheduledDate.add(const Duration(days: 7));
              }

              final notificationId = generateNotificationId(
                med.id!,
                weekday,
                time,
              );

              await _notifications.zonedSchedule(
                notificationId,
                '💊 Hora de: ${med.medName}',
                '${med.medDose}',
                scheduledDate,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'reminder_channel',
                    'Lembretes',
                    importance: Importance.max,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Erro ao agendar medicamento: $e');
    }
  }

  Future<void> cancelAllMedicationNotifications(Medicine med) async {
    try {
      if (med.id == null) {
        print('⚠️ Medicamento sem ID, não é possível cancelar notificações');
        return;
      }

      print(
        '🗑️ Removendo notificações do medicamento: ${med.medName} (ID: ${med.id})',
      );

      int notificationsCancelled = 0;

      // Para cada horário do medicamento
      for (int i = 0; i < med.medTimes.length; i++) {
        final time = med.medTimes[i];

        // Para cada dia da semana
        for (int weekday = 0; weekday < med.daysOfWeek.length; weekday++) {
          if (med.daysOfWeek[weekday]) {
            // Gerar o ID da notificação
            final notificationId = generateNotificationId(
              med.id!,
              weekday,
              time,
            );

            // Cancelar a notificação
            await _notifications.cancel(notificationId);
            notificationsCancelled++;

            // Formatar horário manualmente (sem context)
            final hourStr = time.hour.toString().padLeft(2, '0');
            final minuteStr = time.minute.toString().padLeft(2, '0');
            final timeStr = '$hourStr:$minuteStr';

            print(
              '   🗑️ Cancelada notificação ID: $notificationId (Dia ${weekday + 1}, $timeStr)',
            );
          }
        }
      }

      print(
        '✅ Removidas $notificationsCancelled notificações do medicamento ${med.medName}',
      );
    } catch (e) {
      print('❌ Erro ao remover notificações do medicamento: $e');
    }
  }

  /// Remove notificações específicas de um horário do medicamento
  /// Remove notificações específicas de um horário do medicamento
  Future<void> cancelSpecificTimeNotifications(
    Medicine med,
    TimeOfDay time,
  ) async {
    try {
      if (med.id == null) {
        print('⚠️ Medicamento sem ID');
        return;
      }

      // Formatar horário manualmente
      final hourStr = time.hour.toString().padLeft(2, '0');
      final minuteStr = time.minute.toString().padLeft(2, '0');
      final timeStr = '$hourStr:$minuteStr';

      print(
        '🗑️ Removendo notificações do horário $timeStr do medicamento ${med.medName}',
      );

      int notificationsCancelled = 0;

      // Para cada dia da semana
      for (int weekday = 0; weekday < med.daysOfWeek.length; weekday++) {
        if (med.daysOfWeek[weekday]) {
          // Gerar o ID da notificação para este horário e dia
          final notificationId = generateNotificationId(med.id!, weekday, time);

          // Cancelar a notificação
          await _notifications.cancel(notificationId);
          notificationsCancelled++;

          print(
            '   🗑️ Cancelada notificação ID: $notificationId (Dia ${weekday + 1})',
          );
        }
      }

      print(
        '✅ Removidas $notificationsCancelled notificações do horário $timeStr',
      );
    } catch (e) {
      print('❌ Erro ao remover notificações do horário: $e');
    }
  }

  /// Atualiza notificações de um medicamento (remove antigas e agenda novas)
  Future<void> updateMedicationNotifications(
    Medicine oldMed,
    Medicine newMed,
  ) async {
    try {
      print(
        '🔄 Atualizando notificações do medicamento: ${oldMed.medName} → ${newMed.medName}',
      );

      // 1. Remover todas notificações antigas
      await cancelAllMedicationNotifications(oldMed);

      // 2. Agendar novas notificações se necessário
      if (newMed.notificationType != NotificationType.none) {
        // Usar o método de agendamento que considera o timing
        await scheduleMedicationNotifications(newMed);
      }

      print('✅ Notificações atualizadas com sucesso');
    } catch (e) {
      print('❌ Erro ao atualizar notificações: $e');
    }
  }

  // Teste prático: agendar para 1 minuto
  Future<void> testOneMinuteNotification() async {
    final now = DateTime.now();
    final futureTime = now.add(const Duration(minutes: 1));
    final timeOfDay = TimeOfDay(
      hour: futureTime.hour,
      minute: futureTime.minute,
    );

    print('⏰ Teste 1 minuto: $futureTime');

    await scheduleAndroidNotification(
      id: 99999,
      title: 'TESTE - 1 Minuto',
      body: 'Esta notificação foi agendada para 1 minuto no futuro',
      time: timeOfDay,
      daysOfWeek: List.filled(7, true),
    );
  }

  // Verificar e limpar notificações antigas
  Future<void> cleanOldNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final now = DateTime.now();

      for (var notif in pending) {
        // Se a notificação tem mais de 7 dias, cancelar
        // (lógica básica - ajustar conforme necessidade)
        if (notif.id < 1000) {
          // IDs de teste
          await _notifications.cancel(notif.id);
          print('🧹 Limpando notificação teste ID: ${notif.id}');
        }
      }
    } catch (e) {
      print('❌ Erro ao limpar notificações: $e');
    }
  }
}

// Função auxiliar para gerar IDs
int generateNotificationId(int medId, int weekdayIndex, TimeOfDay time) {
  return (medId * 100) + (weekdayIndex * 10) + time.hour + time.minute;
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
    // Limpar notificações antigas ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().cleanOldNotifications();
    });
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
      title: 'Cuida+',
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
        scaffoldBackgroundColor: const Color.fromARGB(255, 0, 36, 37),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 26, 26, 26),
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: currentThemeMode,
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
          onThemeChanged: _changeTheme,
        ),
      },
      home: widget.showWelcome
          ? const OnboardingScreen()
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

String formatarDias(List<bool> days) {
  const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  if (days.every((d) => !d)) return "Nenhum dia";
  if (days.every((d) => d)) return "Todos os dias";
  return [
    for (int i = 0; i < days.length; i++)
      if (days[i]) nomes[i],
  ].join(', ');
}
