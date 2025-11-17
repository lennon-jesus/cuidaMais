// screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/dbhelper.dart';
import 'models/medic.dart';
import 'models/profile.dart';

class ReportScreen extends StatefulWidget {
  final Profile profile;
  const ReportScreen({super.key, required this.profile});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Medicine> _meds = [];
  Map<String, List<Map<String, dynamic>>> _byDate = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meds = await _db.getMedsByProfile(widget.profile.id!);
    // takenDoses assumed Map<String,int> inside Medicine.takenDoses
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (var m in meds) {
      m.takenDoses.forEach((date, count) {
        if (count == 0) return;
        map.putIfAbsent(date, () => []);
        map[date]!.add({
          'medName': m.medName,
          'medDose': m.medDose,
          'count': count,
        });
      });
    }
    setState(() {
      _meds = meds;
      _byDate = Map.fromEntries(
        map.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)), // order desc by date
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_byDate.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relatório de doses')),
        body: const Center(child: Text('Nenhuma dose registrada ainda.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de doses')),
      body: ListView(
        children: _byDate.entries.map((entry) {
          final date = entry.key;
          final items = entry.value;
          DateTime dt = DateFormat('yyyy-MM-dd').parse(date);
          final subtitle = DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(dt);
          return ExpansionTile(
            title: Text(subtitle),
            children: items.map((it) {
              return ListTile(
                title: Text("${it['medName']} - ${it['medDose']}"),
                trailing: Text("Tomadas: ${it['count']}"),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
