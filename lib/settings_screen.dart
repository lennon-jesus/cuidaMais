// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  final AppThemeMode currentTheme;

  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required void Function(AppThemeMode mode) onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppThemeMode _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _selectedTheme);
        return false; // impede o pop automático, pois já fizemos o pop manual
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tema do aplicativo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              RadioListTile<AppThemeMode>(
                title: const Text('Padrão do sistema'),
                value: AppThemeMode.system,
                groupValue: _selectedTheme,
                onChanged: (v) => setState(() => _selectedTheme = v!),
              ),
              RadioListTile<AppThemeMode>(
                title: const Text('Claro'),
                value: AppThemeMode.light,
                groupValue: _selectedTheme,
                onChanged: (v) => setState(() => _selectedTheme = v!),
              ),
              RadioListTile<AppThemeMode>(
                title: const Text('Escuro'),
                value: AppThemeMode.dark,
                groupValue: _selectedTheme,
                onChanged: (v) => setState(() => _selectedTheme = v!),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _selectedTheme),
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar tema'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
