// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'services/backup_service.dart';
import 'db/dbhelper.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  final AppThemeMode currentTheme;
  final void Function(AppThemeMode mode) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppThemeMode _selectedTheme;
  final BackupService _backupService = BackupService();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  Future<void> _createBackupAndShare() async {
    setState(() => _working = true);
    final res = await _backupService.createBackup();
    setState(() => _working = false);

    if (res.success && res.filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup criado e compartilhável.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }

  Future<void> _pickAndRestore() async {
    final picked = await _backupService.pickBackupFile();
    if (picked == null) return;

    setState(() => _working = true);
    final res = await _backupService.restoreFromZip(picked);
    setState(() => _working = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.message)),
    );
  }

  Future<void> _resetApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reset'),
        content: const Text(
            'Isso apagará todos os dados e retornará o app às configurações iniciais. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, apagar')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _working = true);
      final res = await _backupService.resetAppToDefaults();
      setState(() => _working = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _selectedTheme);
        return false;
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
                onChanged: (v) => setState(
                  () => _selectedTheme = v!,
                ),
              ),
              RadioListTile<AppThemeMode>(
                title: const Text('Claro'),
                value: AppThemeMode.light,
                groupValue: _selectedTheme,
                onChanged: (v) => setState(
                  () => _selectedTheme = v!,
                ),
              ),
              RadioListTile<AppThemeMode>(
                title: const Text('Escuro'),
                value: AppThemeMode.dark,
                groupValue: _selectedTheme,
                onChanged: (v) => setState(
                  () => _selectedTheme = v!,
                ),
              ),

              const Divider(height: 32),

              const Text(
                'Backup & Recuperação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: _working ? null : _createBackupAndShare,
                icon: const Icon(Icons.backup),
                label: Text(_working ? 'Processando...' : 'Criar backup (exportar)'),
              ),

              const SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: _working ? null : _pickAndRestore,
                icon: const Icon(Icons.restore),
                label: Text(_working ? 'Processando...' : 'Restaurar backup'),
              ),

              const SizedBox(height: 8),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _working ? null : _resetApp,
                icon: const Icon(Icons.restart_alt),
                label: Text(
                    _working ? 'Processando...' : 'Resetar app às configurações iniciais'),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onThemeChanged(_selectedTheme); 
                    Navigator.pop(context, _selectedTheme);
                  },
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
