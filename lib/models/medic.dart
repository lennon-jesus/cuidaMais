import 'package:flutter/material.dart';

/// Tipos de notificação disponíveis para cada medicação
enum NotificationType {
  none,   // não notificar
  onTime, // notificar no horário exato
  early,  // notificar com adiantamento
  late,   // notificar com atraso
}

class Medicine {
  int? id;
  String medName;
  String medDose;
  List<TimeOfDay> medTimes;
  String? imagePath;
  String? observations;
  List<bool> daysOfWeek; // [Seg, Ter, Qua, Qui, Sex, Sab, Dom]

  int maxDoses; // quantidade total de doses disponíveis
  Map<String, int> takenDoses; // {'2025-09-23': 1, '2025-09-24': 0}

  int profileId; // identifica o perfil dono do medicamento

  NotificationType notificationType; // tipo de notificação

  Medicine({
    this.id,
    required this.medName,
    required this.medDose,
    required this.medTimes,
    this.imagePath,
    this.observations,
    List<bool>? daysOfWeek,
    this.maxDoses = 0,
    Map<String, int>? takenDoses,
    this.profileId = 0,
    this.notificationType = NotificationType.onTime,
  })  : daysOfWeek = daysOfWeek ?? List.filled(7, true),
        takenDoses = takenDoses ?? {};

  /// Converte o objeto em um Map para salvar no banco
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medName': medName,
      'medDose': medDose,
      'medTimes': medTimes.map((t) => "${t.hour}:${t.minute}").join(','),
      'imagePath': imagePath,
      'observations': observations,
      'daysOfWeek': daysOfWeek.map((d) => d ? "1" : "0").join(','),
      'maxDoses': maxDoses,
      'takenDoses':
          takenDoses.entries.map((e) => "${e.key}:${e.value}").join(';'),
      'profileId': profileId,
      'notificationType': notificationType.name, // salva nome do enum
    };
  }

  /// Constrói o objeto a partir do Map do banco
  factory Medicine.fromMap(Map<String, dynamic> map) {
    Map<String, int> parsedTakenDoses = {};

    if (map['takenDoses'] != null && (map['takenDoses'] as String).isNotEmpty) {
      for (var entry in (map['takenDoses'] as String).split(';')) {
        if (entry.isEmpty) continue;
        final parts = entry.split(':');
        parsedTakenDoses[parts[0]] = int.parse(parts[1]);
      }
    }

    return Medicine(
      id: map['id'],
      medName: map['medName'],
      medDose: map['medDose'],
      medTimes: (map['medTimes'] as String)
          .split(',')
          .where((t) => t.isNotEmpty)
          .map((t) {
        final parts = t.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList(),
      imagePath: map['imagePath'],
      observations: map['observations'],
      daysOfWeek: (map['daysOfWeek'] as String)
          .split(',')
          .map((d) => d == "1")
          .toList(),
      maxDoses: map['maxDoses'] ?? 0,
      takenDoses: parsedTakenDoses,
      profileId: map['profileId'] ?? 0,
      notificationType: NotificationType.values.firstWhere(
        (e) => e.name == map['notificationType'],
        orElse: () => NotificationType.onTime,
      ),
    );
  }
}
