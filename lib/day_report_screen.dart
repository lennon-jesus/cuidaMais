import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/dbhelper.dart';
import 'models/profile.dart';

class DayReportScreen extends StatelessWidget {
  final DateTime date;
  final Profile? profile;

  const DayReportScreen({
    super.key,
    required this.date,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final db = DatabaseHelper();

    return FutureBuilder(
      future: db.getMedsByProfile(profile!.id!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final meds = snapshot.data!;
        final weekday = date.weekday;

        // Filtra só os medicamentos que ocorrem nesse dia
        final medsDoDia = meds.where(
          (m) => m.daysOfWeek[weekday - 1],
        ).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text("Medicamentos de ${DateFormat('dd/MM').format(date)}"),
          ),
          body: medsDoDia.isEmpty
              ? const Center(child: Text("Nenhum medicamento para este dia"))
              : ListView.builder(
                  itemCount: medsDoDia.length,
                  itemBuilder: (context, i) {
                    final m = medsDoDia[i];
                    return ListTile(
                      title: Text(m.medName),
                      subtitle: Text(
                        m.medTimes
                            .map((t) => t.format(context))
                            .join(', '),
                      ),
                      trailing: Text(m.medDose),
                    );
                  },
                ),
        );
      },
    );
  }
}
