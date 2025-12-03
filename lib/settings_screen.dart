// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'services/backup_service.dart';
import 'package:local_auth/local_auth.dart';

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

final LocalAuthentication _localAuth = LocalAuthentication();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _pickAndRestore() async {
    final picked = await _backupService.pickBackupFile();
    if (picked == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar restauração'),
        content: const Text(
          'Isso irá substituir TODOS os dados atuais pelos do backup.\n'
          'Todos os medicamentos, perfis e configurações atuais serão perdidos.\n\n'
          'Após a restauração, o app precisará ser reiniciado.\n\n'
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _working = true);
    final res = await _backupService.restoreFromZip(picked);
    setState(() => _working = false);

    if (res.success) {
      // Mostrar mensagem e depois pedir para fechar o app
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restaurado com sucesso!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Aguardar a mensagem ser mostrada
      await Future.delayed(const Duration(seconds: 2));

      // Mostrar diálogo para fechar o app
      _showRestartDialog(
        title: 'Restauração Concluída',
        message:
            'O backup foi restaurado com sucesso!\n\n'
            'Para aplicar todas as mudanças, é necessário fechar '
            'e reabrir o app completamente.',
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _authenticateAndCreateBackup() async {
  bool authenticated = await _authenticateUser(
    reason: 'Autentique-se para criar um backup dos seus dados'
  );
  
  if (authenticated) {
    await _createBackupAndShare();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autenticação falhou. Backup não criado.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Método para autenticar antes de restaurar
Future<void> _authenticateAndRestore() async {
  bool authenticated = await _authenticateUser(
    reason: 'Autentique-se para restaurar dados do backup'
  );
  
  if (authenticated) {
    await _pickAndRestore();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autenticação falhou. Restauração cancelada.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

Future<void> _authenticateAndReset() async {
  bool authenticated = await _authenticateUser(
    reason: 'Autentique-se para resetar app'
  );
  
  if (authenticated) {
    await _resetApp();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autenticação falhou. Reset cancelado.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Método genérico de autenticação
Future<bool> _authenticateUser({required String reason}) async {
  try {
    // Verificar se o dispositivo suporta autenticação biométrica
    final canAuthenticate = await _localAuth.canCheckBiometrics || 
                            await _localAuth.isDeviceSupported();
    
    if (!canAuthenticate) {
      // Se não suportar autenticação, permitir continuar com um aviso
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Autenticação não disponível'),
          content: const Text(
            'Seu dispositivo não possui autenticação biométrica configurada. '
            'Deseja continuar sem autenticação?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      
      return proceed ?? false;
    }
    
    // Tentar autenticar com biometria ou senha do dispositivo
    final authenticated = await _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: false, // Permite PIN/senha também
        stickyAuth: true,
      ),
    );
    
    return authenticated;
    
  } catch (e) {
    print('Erro na autenticação: $e');
    
    // Em caso de erro, mostrar opção para continuar com confirmação
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erro na autenticação'),
        content: Text(
          'Não foi possível realizar a autenticação: $e\n\n'
          'Deseja continuar mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, continuar'),
          ),
        ],
      ),
    );
    
    return proceed ?? false;
  }
}

  Future<void> _resetApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reset total'),
        content: const Text(
          'Isso apagará TODOS os dados do app:\n'
          '• Todos os medicamentos\n'
          '• Todos os perfis\n'
          '• Todas as configurações\n'
          'Após o reset, o app precisará ser reiniciado.\n\n'
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, resetar tudo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _working = true);
    final res = await _backupService.resetAppToDefaults();
    setState(() => _working = false);

    if (res.success) {
      // Mostrar mensagem e depois pedir para fechar o app
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App resetado com sucesso!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Aguardar a mensagem ser mostrada
      await Future.delayed(const Duration(seconds: 2));

      // Mostrar diálogo para fechar o app
      _showRestartDialog(
        title: 'Reset Concluído',
        message:
            'O app foi resetado às configurações iniciais!\n\n'
            'Todos os dados foram apagados. Para começar '
            'a usar o app novamente, é necessário fechar '
            'e reabri-lo completamente.',
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  void _showRestartDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Tentar fechar o app
              _closeApp();
            },
            child: const Text('Fechar App Agora'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Só voltar para as configurações
            },
            child: const Text('Fechar Mais Tarde'),
          ),
        ],
      ),
    );
  }

  void _closeApp() {
    // Tentar fechar o app usando SystemNavigator
    try {
      if (Platform.isAndroid) {
        // Android - pode fechar o app
        SystemNavigator.pop();
      } else if (Platform.isIOS) {
        // iOS - não pode fechar programaticamente, mostrar instruções
        _showIOSInstructions();
      } else {
        // Outras plataformas
        SystemNavigator.pop();
      }
    } catch (e) {
      // Se não conseguir fechar, mostrar tela de instruções
      _showCloseInstructions();
    }
  }

  void _showIOSInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('iOS - Instruções'),
        icon: const Icon(Icons.phone_iphone, size: 48),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No iPhone/iPad, siga estes passos:\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Pressione o botão Home duas vezes rápido'),
            SizedBox(height: 4),
            Text('2. Encontre o app Cuida+ na lista de apps'),
            SizedBox(height: 4),
            Text('3. Arraste o app para cima para fechá-lo'),
            SizedBox(height: 4),
            Text('4. Abra o app novamente na tela inicial'),
            SizedBox(height: 16),
            Text(
              'Isso é necessário para aplicar todas as mudanças.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _showCloseInstructions() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Reinício Necessário')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restart_alt, size: 80, color: Colors.teal),
                  const SizedBox(height: 24),
                  const Text(
                    'Operação Concluída!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Para aplicar todas as mudanças, por favor:\n\n'
                    '1. Feche completamente este app\n'
                    '2. Abra o app novamente\n\n'
                    'Isso garantirá que todos os dados sejam carregados corretamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Tentar fechar novamente
                      try {
                        SystemNavigator.pop();
                      } catch (e) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Tentar Fechar o App'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Voltar para a tela inicial
                      Navigator.of(context).pop();
                    },
                    child: const Text('Voltar ao App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      (route) => false,
    );
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
      body: SingleChildScrollView(
        child: Padding(
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
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedTheme = v);
                    widget.onThemeChanged(v);
                  }
                },
              ),
              
              RadioListTile<AppThemeMode>(
                title: const Text('Claro'),
                value: AppThemeMode.light,
                groupValue: _selectedTheme,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedTheme = v);
                    widget.onThemeChanged(v);
                  }
                },
              ),
              
              RadioListTile<AppThemeMode>(
                title: const Text('Escuro'),
                value: AppThemeMode.dark,
                groupValue: _selectedTheme,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedTheme = v);
                    widget.onThemeChanged(v);
                  }
                },
              ),

              const Divider(height: 32),

              const Text(
                'Backup & Recuperação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              const Text(
                'Importante: Backup e restauração incluem todos os dados: '
                'medicamentos, perfis, imagens e configurações.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              
              const SizedBox(height: 12),

              // BOTÃO DE BACKUP COM AUTENTICAÇÃO
              ElevatedButton.icon(
                onPressed: _working ? null : () => _authenticateAndCreateBackup(),
                icon: const Icon(Icons.backup),
                label: Text(_working ? 'Processando...' : 'Criar backup (exportar)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

              const SizedBox(height: 12),

              // BOTÃO DE RESTAURAÇÃO COM AUTENTICAÇÃO
              ElevatedButton.icon(
                onPressed: _working ? null : () => _authenticateAndRestore(),
                icon: const Icon(Icons.restore),
                label: Text(_working ? 'Processando...' : 'Restaurar backup'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // BOTÃO DE RESET (SEM AUTENTICAÇÃO - já tem confirmação extra)
              ElevatedButton.icon(
                onPressed: _working ? null : () => _authenticateAndReset(),
                icon: const Icon(Icons.restart_alt),
                label: Text(
                  _working ? 'Processando...' : 'Resetar app (apagar tudo)'
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Restauração e reset requerem que o app seja '
                        'fechado e reabrido para aplicar as mudanças. '
                        'Caso o app não feche corretamente com a opção '
                        'automática, tente fechá-lo manualmente.',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, _selectedTheme);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}
}
