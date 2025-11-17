// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '/models/medic.dart';
import '/models/profile.dart';
import '/db/dbhelper.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(AppThemeMode)? onThemeChanged;
  final AppThemeMode? currentTheme;

  const HomeScreen({super.key, this.onThemeChanged, this.currentTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> authenticateUser() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirme para remover o perfil',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (e) {
      return false;
    }
  }

  void deleteProfile(Profile profile) async {
    bool ok = await authenticateUser();
    if (ok) {
      await _dbHelper.deleteProfile(profile.id!);
      setState(() {
        if (activeProfile?.id == profile.id) {
          activeProfile = null;
        }
      });
      loadProfiles();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Autenticação falhou")));
    }
  }

  List<Medicine> _medicine = [];
  Profile? activeProfile;
  List<Profile> profiles = [];
  Profile? get dropdownValue {
    if (activeProfile == null) return null;
    try {
      return profiles.firstWhere((p) => p.id == activeProfile!.id);
    } catch (_) {
      return null;
    }
  }

  String gerarTextoCompartilhamento(Medicine med) {
    final DateTime agora = DateTime.now();
    final String dataFormatada = DateFormat(
      "d 'de' MMMM 'de' y",
      'pt_BR',
    ).format(agora);
    final String horarios = med.medTimes
        .map((t) => t.format(context))
        .join(', ');

    return "Olá, ${activeProfile?.name ?? ''}. Você possui agendada a medicação "
        "${med.medName} (${med.medDose}) às $horarios do dia $dataFormatada.";
  }

  @override
  void initState() {
    super.initState();
    loadProfiles();
    _loadMed();
    Future.delayed(const Duration(milliseconds: 400), _checkProfileExists);
  }

  Future<void> _checkProfileExists() async {
    if (profiles.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      _showAddProfileDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Crie um perfil para começar!"),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void loadProfiles() async {
    profiles = await _dbHelper.getProfiles();
    if (profiles.isNotEmpty && activeProfile == null) {
      activeProfile = profiles.first;
      await _loadMed();
    }
    setState(() {});
  }

  void _showAddProfileDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Novo Perfil"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Nome do perfil"),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Cancelar edição"),
                    content: const Text(
                      "Tem certeza que deseja descartar as alterações?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Não"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Sim"),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _dbHelper.insertProfile(Profile(name: controller.text));
                  Navigator.pop(context);
                  loadProfiles();
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadMed() async {
    if (activeProfile != null) {
      _medicine = await _dbHelper.getMedsByProfile(activeProfile!.id!);
      setState(() {});
    } else {
      _medicine = [];
      setState(() {});
    }
  }

  Future<String?> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    return pickedFile?.path;
  }

  /// ------------------ CALENDÁRIO: 7 DIAS ANTES + 7 DIAS DEPOIS ------------------
  List<DateTime> _getTwoWeeks() {
    DateTime today = DateTime.now();
    DateTime start = today.subtract(const Duration(days: 2));
    return List.generate(10, (i) => start.add(Duration(days: i)));
  }

  /// ------------------ FORMULÁRIO DE MEDICAMENTO ------------------
  void _openForm({Medicine? med}) {
    String medName = med?.medName ?? "";
    String medDose = med?.medDose ?? "";
    List<TimeOfDay> medTimes = List.from(med?.medTimes ?? []);
    String? selectedImagePath = med?.imagePath;
    String? observations = med?.observations ?? "";
    int maxDoses = med?.maxDoses ?? 0;
    int profileId = med?.profileId ?? 0;
    List<bool> daysOfWeek = List.from(med?.daysOfWeek ?? List.filled(7, true));
    NotificationType notificationType =
        med?.notificationType ?? NotificationType.onTime;

    final nameController = TextEditingController(text: medName);
    final doseController = TextEditingController(text: medDose);
    final obsController = TextEditingController(text: observations);
    final maxDosesController = TextEditingController(text: maxDoses.toString());

    bool nameError = false;
    bool doseError = false;
    bool timesError = false;

    final weekdays = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(
              med == null ? "Adicionar Medicamento" : "Editar Medicamento",
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Nome",
                      errorText: nameError ? "Obrigatório" : null,
                    ),
                    onChanged: (v) => medName = v,
                  ),
                  TextField(
                    controller: doseController,
                    decoration: InputDecoration(
                      labelText: "Dosagem",
                      errorText: doseError ? "Obrigatório" : null,
                    ),
                    onChanged: (v) => medDose = v,
                  ),
                  TextField(
                    controller: maxDosesController,
                    decoration: InputDecoration(
                      labelText: "Quantidade máxima de doses",
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => maxDoses = int.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 10),

                  // Dias da semana
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Dias da semana:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      return FilterChip(
                        label: Text(weekdays[i]),
                        selected: daysOfWeek[i],
                        onSelected: (selected) =>
                            setStateSB(() => daysOfWeek[i] = selected),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),

                  // Horários
                  Column(
                    children: [
                      ...medTimes.asMap().entries.map((entry) {
                        int i = entry.key;
                        TimeOfDay time = entry.value;
                        return ListTile(
                          title: Text(
                            "Horário ${i + 1}: ${time.format(context)}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () async {
                              TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: time,
                              );
                              if (picked != null) {
                                if (medTimes.contains(picked)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Esse horário já foi adicionado.",
                                      ),
                                    ),
                                  );
                                } else {
                                  setStateSB(() => medTimes[i] = picked);
                                }
                              }
                            },
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Adicionar horário"),
                        onPressed: () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null && !medTimes.contains(picked)) {
                            setStateSB(() => medTimes.add(picked));
                          }
                        },
                      ),
                      if (timesError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Pelo menos um horário deve ser registrado",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tipo de notificação
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Tipo de notificação:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DropdownButton<NotificationType>(
                    value: notificationType,
                    isExpanded: true,
                    items: NotificationType.values.map((type) {
                      String label;
                      switch (type) {
                        case NotificationType.none:
                          label = "Não notificar";
                          break;
                        case NotificationType.onTime:
                          label = "No horário exato";
                          break;
                        case NotificationType.early:
                          label = "Com adiantamento (5 min antes)";
                          break;
                        case NotificationType.late:
                          label = "Com atraso (5 min depois)";
                          break;
                      }
                      return DropdownMenuItem(value: type, child: Text(label));
                    }).toList(),
                    onChanged: (val) =>
                        setStateSB(() => notificationType = val!),
                  ),

                  ElevatedButton.icon(
                    onPressed: () async {
                      String? path = await _pickImage();
                      if (path != null) {
                        setStateSB(() => selectedImagePath = path);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(
                      selectedImagePath != null
                          ? "Trocar Imagem"
                          : "Adicionar Imagem",
                    ),
                  ),
                  if (selectedImagePath != null)
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Image.file(
                            File(selectedImagePath!),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setStateSB(() => selectedImagePath = null),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            "Remover Imagem",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: obsController,
                    decoration: const InputDecoration(labelText: "Observações"),
                    maxLines: 3,
                    onChanged: (v) => observations = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Cancelar edição"),
                      content: const Text(
                        "Tem certeza que deseja descartar as alterações?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Não"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Sim"),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    Navigator.pop(context);
                  }
                },
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  setStateSB(() {
                    nameError = medName.isEmpty;
                    doseError = medDose.isEmpty;
                    timesError = medTimes.isEmpty;
                  });

                  if (!nameError && !doseError && !timesError) {
                    if (med == null) {
                      final novoMed = Medicine(
                        medName: medName,
                        medDose: medDose,
                        medTimes: medTimes,
                        imagePath: selectedImagePath,
                        observations: observations,
                        daysOfWeek: daysOfWeek,
                        maxDoses: maxDoses,
                        profileId: activeProfile!.id!,
                        notificationType: notificationType,
                      );
                      await _dbHelper.insertMed(novoMed);
                    } else {
                      med.medName = medName;
                      med.medDose = medDose;
                      med.medTimes = medTimes;
                      med.imagePath = selectedImagePath;
                      med.observations = observations;
                      med.daysOfWeek = daysOfWeek;
                      med.maxDoses = maxDoses;
                      med.notificationType = notificationType;
                      await _dbHelper.updateMed(med);
                    }

                    await _loadMed();
                    Navigator.pop(context);

                    for (var t in medTimes) {
                      for (int i = 0; i < daysOfWeek.length; i++) {
                        if (daysOfWeek[i] &&
                            notificationType != NotificationType.none) {
                          TimeOfDay adjustedTime = t;
                          if (notificationType == NotificationType.early) {
                            final totalMinutes = t.hour * 60 + t.minute - 5;
                            adjustedTime = TimeOfDay(
                              hour: (totalMinutes ~/ 60) % 24,
                              minute: totalMinutes % 60,
                            );
                          } else if (notificationType ==
                              NotificationType.late) {
                            final totalMinutes = t.hour * 60 + t.minute + 5;
                            adjustedTime = TimeOfDay(
                              hour: (totalMinutes ~/ 60) % 24,
                              minute: totalMinutes % 60,
                            );
                          }

                          await _notificationService.scheduleWeeklyNotification(
                            med?.id ?? DateTime.now().millisecondsSinceEpoch,
                            "Hora do Remédio",
                            "$medName - $medDose",
                            adjustedTime,
                            i + 1,
                          );
                        }
                      }
                    }
                  }
                },
                child: const Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ------------------ MARCAR DOSE ------------------
  void _markDose(Medicine med, DateTime date, bool taken) async {
    String key = DateFormat('yyyy-MM-dd').format(date);
    int current = med.takenDoses[key] ?? 0;
    if (taken && med.maxDoses > 0) med.maxDoses--;
    med.takenDoses[key] = taken ? current + 1 : current;
    await _dbHelper.updateMed(med);
    await _loadMed();
  }

  /// ------------------ REMOVER MEDICAMENTO COM AUTENTICAÇÃO ------------------
  Future<void> _removeMed(Medicine med) async {
    bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Autentique-se para remover o medicamento',
    );
    if (authenticated && med.id != null) {
      await _dbHelper.deleteMed(med.id!);
      await _loadMed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getTwoWeeks();
    DateTime today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Medicamentos"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final newTheme = await Navigator.pushNamed(context, '/settings');
              if (newTheme is AppThemeMode) {
                final callback = widget.onThemeChanged;
                if (callback != null) callback(newTheme);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --------------- CALENDÁRIO 10 DIAS ----------------
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              itemBuilder: (context, i) {
                bool hasMed = _medicine.any((m) {
                  int weekday = weekDays[i].weekday;
                  return m.daysOfWeek[weekday - 1];
                });

                bool isToday =
                    weekDays[i].day == today.day &&
                    weekDays[i].month == today.month &&
                    weekDays[i].year == today.year;

                return Container(
                  width: 60,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.teal
                        : hasMed
                        ? Colors.teal.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat(
                            'E',
                            'pt_BR',
                          ).format(weekDays[i]), // Seg, Ter, etc
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${weekDays[i].day}",
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: activeProfile == null
                    ? null
                    : () {
                        _openForm();
                      },
                icon: const Icon(Icons.add, size: 28, color: Colors.white),
                label: const Text(
                  "Adicionar Medicamento",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          profiles.isEmpty
              ? const Text("Nenhum perfil cadastrado")
              : DropdownButton<Profile>(
                  value: profiles.contains(activeProfile)
                      ? activeProfile
                      : null,
                  hint: const Text("Selecione um perfil"),
                  items: profiles.map((p) {
                    return DropdownMenuItem(value: p, child: Text(p.name));
                  }).toList(),
                  onChanged: (Profile? p) {
                    setState(() {
                      activeProfile = p;
                    });
                    _loadMed();
                  },
                ),

          Wrap(
  alignment: WrapAlignment.center,
  spacing: 12,
  runSpacing: 12,
  children: [
    ElevatedButton.icon(
      onPressed: _showAddProfileDialog,
      icon: const Icon(Icons.person_add),
      label: const Text("Criar Perfil"),
    ),
    if (activeProfile != null)
      ElevatedButton.icon(
        onPressed: () => deleteProfile(activeProfile!),
        icon: const Icon(Icons.delete),
        label: const Text("Remover Perfil"),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      ),
    if (activeProfile != null)
      ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportScreen(profile: activeProfile!),
            ),
          );
        },
        icon: const Icon(Icons.assignment_turned_in),
        label: const Text("Relatório"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
        ),
      ),
  ],
),


          // --------------- LISTA DE MEDICAMENTOS ----------------
          Expanded(
            child: _medicine.isEmpty
                ? const Center(child: Text("Nenhum medicamento cadastrado."))
                : ListView.builder(
                    itemCount: _medicine.length,
                    itemBuilder: (context, index) {
                      final med = _medicine[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ExpansionTile(
                          title: Text("${med.medName} - ${med.medDose}"),
                          subtitle: Text(
                            "Horários: ${med.medTimes.map((t) => t.format(context)).join(', ')}\nDias: ${formatarDias(med.daysOfWeek)}\nDoses restantes: ${med.maxDoses}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  final texto = gerarTextoCompartilhamento(med);
                                  Share.share(texto);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _openForm(med: med),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeMed(med),
                              ),
                            ],
                          ),
                          children: [
                            if (med.imagePath != null)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.file(
                                  File(med.imagePath!),
                                  height: 150,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (med.observations != null &&
                                med.observations!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text("Observações: ${med.observations}"),
                              ),
                            // ------------------ BOTÕES MARCAR DOSE ------------------
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () async {
                                      _markDose(med, DateTime.now(), true);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Medicamento marcado como tomado.",
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text("Tomada"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      _markDose(med, DateTime.now(), false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Medicamento marcado como esquecido.",
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text("Esquecida"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
