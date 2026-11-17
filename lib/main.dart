import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_stub.dart'
    if (dart.library.js_interop) 'notifications_web.dart' as notifications;

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');
const supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const mindArtRedirectUrl =
    'https://alexandremarques8110-hub.github.io/mindart-assistente/';
bool get cloudStorageEnabled =>
    supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (cloudStorageEnabled) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
  runApp(const MindArtApp());
}

const ink = Color(0xFF182B3A);
const teal = Color(0xFF167C80);
const paper = Color(0xFFF5F7F5);

class MindArtApp extends StatelessWidget {
  const MindArtApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MindArt',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: teal),
          appBarTheme: const AppBarTheme(
            backgroundColor: paper,
            foregroundColor: ink,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        home: cloudStorageEnabled ? const AccountGate() : const HomeShell(),
      );
}

class AccountGate extends StatelessWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return const AccountPage();
        return HomeShell(key: ValueKey(session.user.id));
      },
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) {
      _message('Informe seu e-mail e uma senha com pelo menos 6 caracteres.');
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_creatingAccount) {
        final response = await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: mindArtRedirectUrl,
        );
        if (response.session == null && mounted) {
          _message('Confira seu e-mail para confirmar a conta.');
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      _message(error.message);
    } catch (_) {
      _message(
          'Não foi possível conectar. Confira sua internet e tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _message('Digite seu e-mail para receber o link de recuperação.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: mindArtRedirectUrl,
      );
      _message('Se o e-mail estiver cadastrado, você receberá um link.');
    } on AuthException catch (error) {
      _message(error.message);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.auto_awesome, color: teal, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _creatingAccount
                            ? 'Criar sua conta'
                            : 'Entrar no MindArt',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Acesse seus registros em seus aparelhos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _busy ? null : _submit(),
                      ),
                      if (!_creatingAccount)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text('Esqueci a senha'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_creatingAccount ? 'Criar conta' : 'Entrar'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                  () => _creatingAccount = !_creatingAccount,
                                ),
                        child: Text(_creatingAccount
                            ? 'Já tenho uma conta'
                            : 'Criar uma conta nova'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class TaskItem {
  TaskItem(this.title, this.project, this.date, {this.done = false});
  String title;
  String project;
  String date;
  bool done;

  Map<String, Object?> toJson() => {
        'title': title,
        'project': project,
        'date': date,
        'done': done,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        json['title'] as String,
        json['project'] as String,
        json['date'] as String,
        done: json['done'] as bool? ?? false,
      );
}

class ExpenseItem {
  ExpenseItem(this.title, this.category, this.value);
  String title;
  String category;
  double value;

  Map<String, Object?> toJson() => {
        'title': title,
        'category': category,
        'value': value,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        json['title'] as String,
        json['category'] as String,
        (json['value'] as num).toDouble(),
      );
}

class RoutineEvent {
  RoutineEvent(this.title, this.startsAt);
  String title;
  DateTime startsAt;

  Map<String, Object?> toJson() => {
        'title': title,
        'startsAt': startsAt.toIso8601String(),
      };

  factory RoutineEvent.fromJson(Map<String, dynamic> json) => RoutineEvent(
        json['title'] as String,
        DateTime.parse(json['startsAt'] as String),
      );
}

class DebtItem {
  DebtItem(this.name, this.total, {this.paid = 0});
  String name;
  double total;
  double paid;
  double get remaining => (total - paid).clamp(0, total).toDouble();

  Map<String, Object?> toJson() => {
        'name': name,
        'total': total,
        'paid': paid,
      };

  factory DebtItem.fromJson(Map<String, dynamic> json) => DebtItem(
        json['name'] as String,
        (json['total'] as num).toDouble(),
        paid: (json['paid'] as num? ?? 0).toDouble(),
      );
}

class SavingsGoal {
  SavingsGoal(this.name, this.target, {this.saved = 0});
  String name;
  double target;
  double saved;
  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();

  Map<String, Object?> toJson() => {
        'name': name,
        'target': target,
        'saved': saved,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        json['name'] as String,
        (json['target'] as num).toDouble(),
        saved: (json['saved'] as num? ?? 0).toDouble(),
      );
}

class ProjectItem {
  ProjectItem(this.name, this.description, {this.isIdea = false});
  String name;
  String description;
  bool isIdea;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'isIdea': isIdea,
      };

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
        json['name'] as String,
        json['description'] as String? ?? '',
        isIdea: json['isIdea'] as bool? ?? false,
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  int financeSection = 0;
  bool showIdeas = false;
  final _storage = SharedPreferencesAsync();
  late final String? _accountId = cloudStorageEnabled
      ? Supabase.instance.client.auth.currentUser?.id
      : null;

  // Isolated offline cache for each signed-in account.
  String _storageKey(String field) => _accountId == null
      ? 'mindart.$field'
      : 'mindart.user.$_accountId.$field';

  bool _ready = false;
  final tasks = <TaskItem>[];
  final expenses = <ExpenseItem>[];
  final events = <RoutineEvent>[];
  final debts = <DebtItem>[];
  final savingsGoals = <SavingsGoal>[];
  final projects = <ProjectItem>[];
  bool _cloudReady = false;
  bool _cloudWarningShown = false;
  RealtimeChannel? _cloudChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    Map<String, dynamic>? cloudPayload;
    var cloudLoadSucceeded = !cloudStorageEnabled;
    if (cloudStorageEnabled) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final row = await Supabase.instance.client
              .from('mindart_user_data')
              .select('payload')
              .eq('user_id', user.id)
              .maybeSingle();
          if (row != null) {
            cloudPayload = Map<String, dynamic>.from(row['payload'] as Map);
          }
        }
        cloudLoadSucceeded = true;
      } catch (_) {
        _cloudWarningShown = true;
      }
    }
    try {
      var savedTasks = await _storage.getString(_storageKey('tasks'));
      var savedExpenses = await _storage.getString(_storageKey('expenses'));
      var savedEvents = await _storage.getString(_storageKey('events'));
      var savedDebts = await _storage.getString(_storageKey('debts'));
      var savedGoals = await _storage.getString(_storageKey('savingsGoals'));
      var savedProjects = await _storage.getString(_storageKey('projects'));
      // Explicit, one-time import for data created before account login.
      // Legacy data is never automatically assigned to another account.
      if (_accountId != null &&
          cloudPayload == null &&
          [savedTasks, savedExpenses, savedEvents, savedDebts, savedGoals,
                  savedProjects]
              .every((value) => value == null)) {
        final legacyOwner = await _storage.getString('mindart.legacy.owner');
        if (legacyOwner == null || legacyOwner == _accountId) {
          final legacy = <String, String?>{};
          for (final field in const [
            'tasks', 'expenses', 'events', 'debts', 'savingsGoals', 'projects'
          ]) {
            legacy[field] = await _storage.getString('mindart.$field');
          }
          if (legacy.values.any((value) => value != null) && mounted) {
            final consent = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Dados antigos encontrados'),
                content: const Text(
                  'Este navegador tem registros da versão sem login. '
                  'Deseja vinculá-los à sua conta atual?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Não importar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Importar dados'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            if (consent == true) {
              await _storage.setString('mindart.legacy.owner', _accountId);
              savedTasks = legacy['tasks'];
              savedExpenses = legacy['expenses'];
              savedEvents = legacy['events'];
              savedDebts = legacy['debts'];
              savedGoals = legacy['savingsGoals'];
              savedProjects = legacy['projects'];
            }
          }
        }
      }
      if (cloudPayload != null) {
        savedTasks = jsonEncode(cloudPayload['tasks'] ?? []);
        savedExpenses = jsonEncode(cloudPayload['expenses'] ?? []);
        savedEvents = jsonEncode(cloudPayload['events'] ?? []);
        savedDebts = jsonEncode(cloudPayload['debts'] ?? []);
        savedGoals = jsonEncode(cloudPayload['savingsGoals'] ?? []);
        savedProjects = jsonEncode(cloudPayload['projects'] ?? []);
      }
      if (savedTasks != null) {
        tasks
          ..clear()
          ..addAll(
            (jsonDecode(savedTasks) as List<dynamic>).map(
              (item) => TaskItem.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
      if (savedExpenses != null) {
        expenses
          ..clear()
          ..addAll(
            (jsonDecode(savedExpenses) as List<dynamic>).map(
              (item) => ExpenseItem.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
      if (savedEvents != null) {
        events
          ..clear()
          ..addAll(
            (jsonDecode(savedEvents) as List<dynamic>).map(
              (item) => RoutineEvent.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
      if (savedDebts != null) {
        debts
          ..clear()
          ..addAll(
            (jsonDecode(savedDebts) as List<dynamic>).map(
              (item) => DebtItem.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
      if (savedGoals != null) {
        savingsGoals
          ..clear()
          ..addAll(
            (jsonDecode(savedGoals) as List<dynamic>).map(
              (item) => SavingsGoal.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
      if (savedProjects != null) {
        projects
          ..clear()
          ..addAll(
            (jsonDecode(savedProjects) as List<dynamic>).map(
              (item) => ProjectItem.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
      for (final task in tasks) {
        if (task.project != 'Pessoal' &&
            !projects.any((project) => project.name == task.project)) {
          projects.add(ProjectItem(task.project, ''));
        }
      }
    } catch (_) {
      // Keep the starter examples if saved data is incomplete or unreadable.
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await _saveTasks();
    await _saveExpenses();
    await _saveEvents();
    await _saveDebts();
    await _saveGoals();
    await _saveProjects();
    _cloudReady = cloudStorageEnabled && cloudLoadSucceeded;
    if (_cloudReady && cloudPayload == null) await _saveCloudSnapshot();
    if (_cloudReady) {
      _listenForCloudChanges();
      await _syncReminderSchedule();
    }
    if (cloudStorageEnabled && !cloudLoadSucceeded && mounted) {
      _message(context,
          'Sem conexão com a nuvem. Você pode continuar usando os dados deste aparelho.');
    }
  }

  void _listenForCloudChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    _cloudChannel = client
        .channel('mindart-data-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mindart_user_data',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final raw = record['payload'];
            if (raw is Map) _applyCloudSnapshot(Map<String, dynamic>.from(raw));
          },
        )
        .subscribe();
  }

  Future<void> _applyCloudSnapshot(Map<String, dynamic> payload) async {
    try {
      tasks
        ..clear()
        ..addAll(((payload['tasks'] ?? []) as List<dynamic>).map(
          (item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      expenses
        ..clear()
        ..addAll(((payload['expenses'] ?? []) as List<dynamic>).map(
          (item) =>
              ExpenseItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      events
        ..clear()
        ..addAll(((payload['events'] ?? []) as List<dynamic>).map(
          (item) =>
              RoutineEvent.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      debts
        ..clear()
        ..addAll(((payload['debts'] ?? []) as List<dynamic>).map(
          (item) => DebtItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      savingsGoals
        ..clear()
        ..addAll(((payload['savingsGoals'] ?? []) as List<dynamic>).map(
          (item) =>
              SavingsGoal.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      projects
        ..clear()
        ..addAll(((payload['projects'] ?? []) as List<dynamic>).map(
          (item) =>
              ProjectItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      if (!mounted) return;
      setState(() {});
      await _storage.setString(_storageKey('tasks'),
          jsonEncode(tasks.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('expenses'),
          jsonEncode(expenses.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('events'),
          jsonEncode(events.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('debts'),
          jsonEncode(debts.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('savingsGoals'),
          jsonEncode(savingsGoals.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('projects'),
          jsonEncode(projects.map((item) => item.toJson()).toList()));
    } catch (_) {
      if (mounted && !_cloudWarningShown) {
        _cloudWarningShown = true;
        _message(context,
            'Não consegui atualizar os dados vindos de outro aparelho.');
      }
    }
  }

  @override
  void dispose() {
    final channel = _cloudChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _saveTasks() async {
    await _storage.setString(
      _storageKey('tasks'),
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
    await _syncCloudIfReady();
  }

  Future<void> _saveExpenses() async {
    await _storage.setString(
      _storageKey('expenses'),
      jsonEncode(expenses.map((expense) => expense.toJson()).toList()),
    );
    await _syncCloudIfReady();
  }

  Future<void> _saveEvents() async {
    await _storage.setString(
      _storageKey('events'),
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
    await _syncCloudIfReady();
    await _syncReminderSchedule();
  }

  Future<void> _saveDebts() async {
    await _storage.setString(
      _storageKey('debts'),
      jsonEncode(debts.map((debt) => debt.toJson()).toList()),
    );
    await _syncCloudIfReady();
  }

  Future<void> _saveGoals() async {
    await _storage.setString(
      _storageKey('savingsGoals'),
      jsonEncode(savingsGoals.map((goal) => goal.toJson()).toList()),
    );
    await _syncCloudIfReady();
  }

  Future<void> _saveProjects() async {
    await _storage.setString(
      _storageKey('projects'),
      jsonEncode(projects.map((project) => project.toJson()).toList()),
    );
    await _syncCloudIfReady();
  }

  Map<String, Object?> _cloudSnapshot() => {
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'expenses': expenses.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
        'debts': debts.map((item) => item.toJson()).toList(),
        'savingsGoals': savingsGoals.map((item) => item.toJson()).toList(),
        'projects': projects.map((item) => item.toJson()).toList(),
      };

  Future<void> _syncCloudIfReady() async {
    if (_cloudReady) await _saveCloudSnapshot();
  }

  Future<void> _saveCloudSnapshot() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id != _accountId) return;
    try {
      await Supabase.instance.client.from('mindart_user_data').upsert(
        {'user_id': user.id, 'payload': _cloudSnapshot()},
        onConflict: 'user_id',
      );
    } catch (_) {
      if (mounted && !_cloudWarningShown) {
        _cloudWarningShown = true;
        _message(context,
            'Salvei neste aparelho, mas não consegui atualizar a nuvem. Confira sua conexão.');
      }
    }
  }




  Future<void> _disableNotifications() async {
    if (!cloudStorageEnabled || vapidPublicKey.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id != _accountId) return;
    try {
      final endpoint = await notifications.unsubscribeFromWebPush();
      if (endpoint.isNotEmpty) {
        await Supabase.instance.client.from('mindart_push_subscriptions')
            .delete()
            .eq('user_id', user.id)
            .eq('endpoint', endpoint);
      }
      if (mounted) _message(context, 'Notificações desativadas neste dispositivo.');
    } catch (_) {
      if (mounted) {
        _message(context, 'Não consegui desativar todas as notificações.');
      }
    }
  }

  Future<void> _signOutSafely() async {
    // Prevent an old account's subscriptions from remaining active
    // in a browser subsequently used by another account.
    if (vapidPublicKey.isNotEmpty) {
      await _disableNotifications();
    }
    await Supabase.instance.client.auth.signOut();
  }

  // User-initiated gesture. Required by Safari for iPhone web push.
  Future<void> _enableNotifications() async {
    if (!cloudStorageEnabled || vapidPublicKey.isEmpty) {
      _message(context,
          'Notificações aguardam a configuração do servidor (VAPID).');
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id != _accountId) return;
    try {
      final raw = await notifications.subscribeToWebPush(vapidPublicKey);
      final subscription = Map<String, dynamic>.from(
          jsonDecode(raw) as Map);
      final keys = Map<String, dynamic>.from(
          subscription['keys'] as Map);
      final endpoint = subscription['endpoint'] as String;
      if (!endpoint.startsWith('https://')) {
        throw const FormatException('Endpoint de push inválido');
      }
      await Supabase.instance.client.from('mindart_push_subscriptions').upsert({
        'user_id': user.id,
        'endpoint': endpoint,
        'p256dh': keys['p256dh'],
        'auth': keys['auth'],
        'timezone': subscription['timezone'] ?? 'UTC',
      }, onConflict: 'endpoint');
      await _syncReminderSchedule();
      if (mounted) {
        _message(context,
            'Notificações ativadas para este dispositivo.');
      }
    } catch (_) {
      if (mounted) {
        _message(context,
            'Não foi possível ativar. Instale o MindArt na Tela de Início '
            'do iPhone e confira as permissões e a configuração do servidor.');
      }
    }
  }

  Future<void> _syncReminderSchedule() async {
    if (!_cloudReady || _accountId == null || vapidPublicKey.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final activeKeys = <String>{};
      for (final event in events) {
        if (!event.startsAt.isAfter(now)) continue;
        final key = 'event:${event.title}:${event.startsAt.toIso8601String()}';
        activeKeys.add(key);
        final remindAt = event.startsAt.subtract(const Duration(minutes: 15));
        await client.from('mindart_reminders').upsert({
          'user_id': _accountId,
          'item_key': key,
          'remind_at': remindAt.toUtc().toIso8601String(),
        }, onConflict: 'user_id,item_key');
      }
      final pending = await client.from('mindart_reminders')
          .select('id,item_key')
          .eq('user_id', _accountId)
          .isFilter('sent_at', null);
      for (final record in pending) {
        final key = record['item_key'] as String;
        if (!activeKeys.contains(key)) {
          await client.from('mindart_reminders')
              .delete().eq('id', record['id']);
        }
      }
    } catch (_) {
      // The local agenda remains available when the server is unreachable.
      if (mounted && !_cloudWarningShown) {
        _cloudWarningShown = true;
        _message(context,
            'Agenda salva, mas os lembretes não foram sincronizados.');
      }
    }
  }

  Future<void> _copyBackup() async {
    if (!_ready) return;
    final data = jsonEncode({
      'format': 'mindart-backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'data': _cloudSnapshot(),
    });
    await Clipboard.setData(ClipboardData(text: data));
    if (mounted) {
      _message(context,
          'Backup copiado. Salve o texto em um arquivo privado e seguro.');
    }
  }

  void _validateBackup(Map<String, dynamic> data) {
    for (final name in const [
      'tasks', 'expenses', 'events', 'debts', 'savingsGoals', 'projects'
    ]) {
      if (data[name] is! List) {
        throw const FormatException('Backup incompleto.');
      }
    }
    for (final item in (data['tasks'] as List)) {
      TaskItem.fromJson(Map<String, dynamic>.from(item as Map));
    }
    for (final item in (data['expenses'] as List)) {
      ExpenseItem.fromJson(Map<String, dynamic>.from(item as Map));
    }
    for (final item in (data['events'] as List)) {
      RoutineEvent.fromJson(Map<String, dynamic>.from(item as Map));
    }
    for (final item in (data['debts'] as List)) {
      DebtItem.fromJson(Map<String, dynamic>.from(item as Map));
    }
    for (final item in (data['savingsGoals'] as List)) {
      SavingsGoal.fromJson(Map<String, dynamic>.from(item as Map));
    }
    for (final item in (data['projects'] as List)) {
      ProjectItem.fromJson(Map<String, dynamic>.from(item as Map));
    }
  }

  Future<void> _restoreBackup() async {
    if (!_ready) return;
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cole o backup MindArt. A restauração substitui os '
                'registros deste dispositivo e, quando conectado, da nuvem.'
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Cole aqui o backup JSON',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restaurar e substituir'),
          ),
        ],
      ),
    );
    final raw = controller.text;
    controller.dispose();
    if (submitted != true) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != 'mindart-backup' ||
          decoded['version'] != 1 ||
          decoded['data'] is! Map) {
        throw const FormatException('Formato de backup inválido.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      _validateBackup(data);
      await _applyCloudSnapshot(data);
      if (_cloudReady) await _saveCloudSnapshot();
      if (mounted) _message(context, 'Backup restaurado neste dispositivo.');
    } catch (_) {
      if (mounted) {
        _message(context,
            'Backup inválido ou danificado. Nenhum dado foi restaurado.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboard(), _projects(), _finances(), _routine()];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MindArt',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Backup dos dados',
                icon: const Icon(Icons.more_vert),
                onSelected: (option) {
                  if (option == 'push') {
                    _enableNotifications();
                  } else if (option == 'disable-push') {
                    _disableNotifications();
                  } else if (option == 'export') {
                    _copyBackup();
                  } else if (option == 'restore') {
                    _restoreBackup();
                  }
                },
                itemBuilder: (context) => [
                  if (cloudStorageEnabled)
                    const PopupMenuItem(
                      value: 'push',
                      child: Text('Ativar notificações'),
                    ),
                  if (cloudStorageEnabled)
                    const PopupMenuItem(
                      value: 'disable-push',
                      child: Text('Desativar notificações'),
                    ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Copiar backup'),
                  ),
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Restaurar backup'),
                  ),
                ],
              ),
              if (cloudStorageEnabled)
                IconButton(
                  tooltip: 'Sair da conta',
                  onPressed: _signOutSafely,
                  icon: const Icon(Icons.logout),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 20),
                child: CircleAvatar(
                  backgroundColor: Color(0xFFDCEBE8),
                  child: Icon(Icons.person_outline, color: teal),
                ),
              ),
            ],
          ),
          body: !_ready
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    if (wide)
                      NavigationRail(
                        selectedIndex: selected,
                        onDestinationSelected: (value) =>
                            setState(() => selected = value),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            label: Text('Meu dia'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.folder_outlined),
                            label: Text('Projetos'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.wallet_outlined),
                            label: Text('Finanças'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            label: Text('Rotina'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: IndexedStack(index: selected, children: pages),
                    ),
                  ],
                ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (value) =>
                      setState(() => selected = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      label: 'Meu dia',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_outlined),
                      label: 'Projetos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.wallet_outlined),
                      label: 'Finanças',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: 'Rotina',
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addItem(context),
            backgroundColor: teal,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _page(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
            child: child,
          ),
        ),
      );

  Widget _dashboard() {
    final done = tasks.where((task) => task.done).length;
    return _page(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Vamos cuidar do que importa.',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Tarefas concluídas',
                  '$done/${tasks.length}',
                  Icons.check_circle_outline,
                  teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  'Gastos no mês',
                  _money(monthTotal),
                  Icons.trending_down,
                  const Color(0xFFB76C42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _sectionTitle(
            'Prioridades',
            'Ver tarefas',
            () => setState(() => selected = 1),
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            _empty('Tudo em dia por aqui.', 'Adicione uma tarefa para começar.')
          else
            ...tasks.take(4).map(_taskTile),
          const SizedBox(height: 22),
          _sectionTitle('Seu espaço', null, null),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _quickLink(
                'Projetos',
                'Ideias e próximos passos',
                Icons.lightbulb_outline,
                1,
              ),
              _quickLink(
                'Finanças',
                'Acompanhe seu dinheiro',
                Icons.savings_outlined,
                2,
              ),
              _quickLink(
                'Rotina',
                'Compromissos e hábitos',
                Icons.event_note_outlined,
                3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projects() => _page(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Projetos e ideias',
                'Guarde ideias e organize o que quer tirar do papel.'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Projetos')),
                  ButtonSegment(value: true, label: Text('Ideias')),
                ],
                selected: {showIdeas},
                onSelectionChanged: (value) =>
                    setState(() => showIdeas = value.first),
              ),
            ),
            const SizedBox(height: 14),
            if (projects
                    .where((project) => project.isIdea == showIdeas)
                    .isEmpty &&
                (showIdeas || tasks.every((task) => task.project != 'Pessoal')))
              _empty(
                showIdeas ? 'Nenhuma ideia salva' : 'Nenhum projeto criado',
                'Toque em + para adicionar ${showIdeas ? 'uma ideia' : 'um projeto'}.',
              ),
            if (!showIdeas &&
                tasks.any((task) => task.project == 'Pessoal')) ...[
              _sectionTitle('Pessoal', null, null),
              ...tasks
                  .where((task) => task.project == 'Pessoal')
                  .map(_taskTile),
            ],
            ...projects
                .where((project) => project.isIdea == showIdeas)
                .map(_projectTile),
          ],
        ),
      );

  Widget _projectTile(ProjectItem project) {
    final projectTasks = tasks.where((task) => task.project == project.name);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(project.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800))),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  onSelected: (action) {
                    if (action == 'edit') _editProject(project);
                    if (action == 'remove') _removeProject(project);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'remove', child: Text('Remover')),
                  ],
                ),
              ],
            ),
            if (project.description.isNotEmpty)
              Text(project.description,
                  style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text('${projectTasks.length} tarefa(s)',
                style: const TextStyle(
                    color: teal, fontSize: 12, fontWeight: FontWeight.w700)),
            if (projectTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...projectTasks.map(_taskTile),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editTask(null, projectName: project.name),
                icon: const Icon(Icons.add_task),
                label: const Text('Adicionar tarefa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finances() => _page(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Finanças', 'Cuide do seu dinheiro com clareza.'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Gastos')),
                  ButtonSegment(value: 1, label: Text('Dívidas')),
                  ButtonSegment(value: 2, label: Text('Metas')),
                ],
                selected: {financeSection},
                onSelectionChanged: (value) =>
                    setState(() => financeSection = value.first),
              ),
            ),
            const SizedBox(height: 20),
            if (financeSection == 0) _expensesPanel(),
            if (financeSection == 1) _debtsPanel(),
            if (financeSection == 2) _goalsPanel(),
          ],
        ),
      );

  Widget _expensesPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gastos registrados',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(_money(monthTotal),
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: ink)),
                  const Text('Total registrado',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Lançamentos', null, null),
          const SizedBox(height: 10),
          if (expenses.isEmpty)
            _empty('Nenhum gasto registrado',
                'Toque em + para adicionar uma despesa.'),
          ...expenses.map((expense) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE5F1EF),
                      child: Icon(Icons.receipt_long, color: teal)),
                  title: Text(expense.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(expense.category),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_money(expense.value),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      PopupMenuButton<String>(
                        tooltip: 'Opções do gasto',
                        onSelected: (action) async {
                          if (action == 'edit') await _editExpense(expense);
                          if (action == 'delete') await _deleteExpense(expense);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Apagar')),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      );

  Widget _debtsPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Dívidas em aberto', null, null),
          const SizedBox(height: 10),
          if (debts.isEmpty)
            _empty('Sem dívidas registradas',
                'Toque em + para adicionar uma dívida.'),
          ...debts.map(_debtTile),
        ],
      );

  Widget _debtTile(DebtItem debt) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(debt.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16))),
                PopupMenuButton<String>(
                  tooltip: 'Opções da dívida',
                  onSelected: (action) async {
                    if (action == 'edit') await _editDebt(debt);
                    if (action == 'delete') await _deleteDebt(debt);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Apagar')),
                  ],
                ),
              ]),
              Text(
                  'Falta pagar ${_money(debt.remaining)} de ${_money(debt.total)}'),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                  value: debt.total == 0 ? 0 : debt.paid / debt.total,
                  color: teal,
                  backgroundColor: const Color(0xFFE4ECE9)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      debt.remaining <= 0 ? null : () => _addDebtPayment(debt),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(
                      debt.remaining <= 0 ? 'Quitada' : 'Registrar pagamento'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _goalsPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Metas de economia', null, null),
          const SizedBox(height: 10),
          if (savingsGoals.isEmpty)
            _empty('Crie sua primeira meta',
                'Toque em + para definir um objetivo de economia.'),
          ...savingsGoals.map(_goalTile),
        ],
      );

  Widget _goalTile(SavingsGoal goal) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(goal.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16))),
                PopupMenuButton<String>(
                  tooltip: 'Opções da meta',
                  onSelected: (action) async {
                    if (action == 'edit') await _editGoal(goal);
                    if (action == 'delete') await _deleteGoal(goal);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Apagar')),
                  ],
                ),
              ]),
              Text('${_money(goal.saved)} guardados de ${_money(goal.target)}'),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                  value: goal.progress,
                  color: teal,
                  backgroundColor: const Color(0xFFE4ECE9)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: goal.progress >= 1
                      ? null
                      : () => _addGoalContribution(goal),
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(goal.progress >= 1
                      ? 'Meta alcançada'
                      : 'Adicionar economia'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _routine() => _page(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
                'Rotina', 'Organize compromissos e crie espaço para você.'),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: teal,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _todayLabel(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Sua agenda começa com pequenos passos.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Compromissos', null, null),
            const SizedBox(height: 10),
            if (events.isEmpty)
              _empty(
                'Sua agenda está livre',
                'Use o botão + para adicionar um compromisso.',
              ),
            ..._sortedEvents.map(_eventTile),
          ],
        ),
      );

  Widget _heading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ],
      );

  Widget _metric(String title, String value, IconData icon, Color color) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: ink,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title, String? action, VoidCallback? onTap) =>
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          if (action != null) TextButton(onPressed: onTap, child: Text(action)),
        ],
      );

  Widget _taskTile(TaskItem task) => Card(
        child: CheckboxListTile(
          value: task.done,
          onChanged: (value) async {
            setState(() => task.done = value ?? false);
            await _saveTasks();
          },
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration: task.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text('${task.project}  ·  ${task.date}'),
          activeColor: teal,
          secondary: PopupMenuButton<String>(
            tooltip: 'Opções da tarefa',
            onSelected: (action) async {
              if (action == 'edit') {
                await _editTask(task);
              } else if (action == 'delete') {
                await _deleteTask(task);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Apagar'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _eventTile(RoutineEvent event) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE5F1EF),
            child: Icon(Icons.event_outlined, color: teal),
          ),
          title: Text(
            event.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(_eventDate(event.startsAt)),
          trailing: PopupMenuButton<String>(
            tooltip: 'Opções do compromisso',
            onSelected: (action) async {
              if (action == 'edit') await _editEvent(event);
              if (action == 'delete') await _deleteEvent(event);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Apagar')),
            ],
          ),
        ),
      );

  Widget _quickLink(String title, String sub, IconData icon, int index) =>
      SizedBox(
        width: 260,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => selected = index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE5F1EF),
                    child: Icon(icon, color: teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _empty(String title, String subtitle) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.spa_outlined, color: teal, size: 30),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _addItem(BuildContext context) async {
    if (selected == 2) {
      if (financeSection == 1) {
        await _createDebt();
        return;
      }
      if (financeSection == 2) {
        await _createGoal();
        return;
      }
      await _editExpense(null);
      return;
    }
    if (selected == 3) {
      await _addEvent();
      return;
    }
    if (selected == 1) {
      await _editProject(null);
      return;
    }
    await _editTask(null);
  }

  Future<void> _editProject(ProjectItem? project) async {
    final nameController = TextEditingController(text: project?.name ?? '');
    final descriptionController =
        TextEditingController(text: project?.description ?? '');
    var isIdea = project?.isIdea ?? showIdeas;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(project == null
              ? (isIdea ? 'Nova ideia' : 'Novo projeto')
              : 'Editar ${isIdea ? 'ideia' : 'projeto'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Descrição ou anotação'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Projeto')),
                    ButtonSegment(value: true, label: Text('Ideia')),
                  ],
                  selected: {isIdea},
                  onSelectionChanged: (value) =>
                      updateDialog(() => isIdea = value.first),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Salvar')),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();
    if (saved != true || name.isEmpty) return;
    if (projects.any(
      (item) =>
          item != project && item.name.toLowerCase() == name.toLowerCase(),
    )) {
      _message(context, 'Já existe um projeto ou ideia com esse nome.');
      return;
    }
    setState(() {
      if (project == null) {
        projects.insert(0, ProjectItem(name, description, isIdea: isIdea));
      } else {
        final oldName = project.name;
        project
          ..name = name
          ..description = description
          ..isIdea = isIdea;
        for (final task in tasks.where((task) => task.project == oldName)) {
          task.project = name;
        }
      }
    });
    await _saveProjects();
    if (project != null) await _saveTasks();
  }

  Future<void> _removeProject(ProjectItem project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover item?'),
        content:
            Text('As tarefas de "${project.name}" serão mantidas em Pessoal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      projects.remove(project);
      for (final task in tasks.where((task) => task.project == project.name)) {
        task.project = 'Pessoal';
      }
    });
    await _saveProjects();
    await _saveTasks();
  }

  Future<void> _editExpense(ExpenseItem? expense) async {
    final titleController = TextEditingController(text: expense?.title ?? '');
    final categoryController =
        TextEditingController(text: expense?.category ?? 'Outros');
    final valueController = TextEditingController(
      text: expense == null ? '' : expense.value.toStringAsFixed(2),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(expense == null ? 'Novo gasto' : 'Editar gasto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              TextField(
                controller: valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    final title = titleController.text.trim();
    final category = categoryController.text.trim();
    final value = _parseMoney(valueController.text);
    titleController.dispose();
    categoryController.dispose();
    valueController.dispose();
    if (saved != true) return;
    if (title.isEmpty || value == null || value <= 0) {
      _message(context, 'Informe uma descrição e um valor válido.');
      return;
    }
    setState(() {
      if (expense == null) {
        expenses.insert(0,
            ExpenseItem(title, category.isEmpty ? 'Outros' : category, value));
      } else {
        expense
          ..title = title
          ..category = category.isEmpty ? 'Outros' : category
          ..value = value;
      }
    });
    await _saveExpenses();
  }

  Future<void> _editDebt(DebtItem? debt) async {
    final nameController = TextEditingController(text: debt?.name ?? '');
    final totalController = TextEditingController(
      text: debt == null ? '' : debt.total.toStringAsFixed(2),
    );
    final paidController = TextEditingController(
      text: debt == null ? '0,00' : debt.paid.toStringAsFixed(2),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(debt == null ? 'Nova dívida' : 'Editar dívida'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: totalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor total'),
              ),
              TextField(
                controller: paidController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Já pago'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    final name = nameController.text.trim();
    final total = _parseMoney(totalController.text);
    final paid = _parseMoney(paidController.text);
    nameController.dispose();
    totalController.dispose();
    paidController.dispose();
    if (saved != true) return;
    if (name.isEmpty ||
        total == null ||
        total <= 0 ||
        paid == null ||
        paid < 0 ||
        paid > total) {
      _message(context,
          'Confira os valores: o total deve ser maior que zero e o já pago não pode ultrapassá-lo.');
      return;
    }
    setState(() {
      if (debt == null) {
        debts.insert(0, DebtItem(name, total, paid: paid));
      } else {
        debt
          ..name = name
          ..total = total
          ..paid = paid;
      }
    });
    await _saveDebts();
  }

  Future<void> _editGoal(SavingsGoal? goal) async {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final targetController = TextEditingController(
      text: goal == null ? '' : goal.target.toStringAsFixed(2),
    );
    final savedController = TextEditingController(
      text: goal == null ? '0,00' : goal.saved.toStringAsFixed(2),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(goal == null ? 'Nova meta' : 'Editar meta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome da meta'),
              ),
              TextField(
                controller: targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor desejado'),
              ),
              TextField(
                controller: savedController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Já guardado'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    final name = nameController.text.trim();
    final target = _parseMoney(targetController.text);
    final alreadySaved = _parseMoney(savedController.text);
    nameController.dispose();
    targetController.dispose();
    savedController.dispose();
    if (saved != true) return;
    if (name.isEmpty ||
        target == null ||
        target <= 0 ||
        alreadySaved == null ||
        alreadySaved < 0) {
      _message(context, 'Informe um nome e valores válidos para a meta.');
      return;
    }
    setState(() {
      if (goal == null) {
        savingsGoals.insert(0, SavingsGoal(name, target, saved: alreadySaved));
      } else {
        goal
          ..name = name
          ..target = target
          ..saved = alreadySaved;
      }
    });
    await _saveGoals();
  }

  Future<void> _createDebt() => _editDebt(null);

  Future<void> _createGoal() => _editGoal(null);

  Future<bool> _confirmDelete(String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Apagar registro?'),
          content: Text('"$name" será removido permanentemente.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Apagar')),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteTask(TaskItem task) async {
    if (!await _confirmDelete(task.title)) return;
    setState(() => tasks.remove(task));
    await _saveTasks();
  }

  Future<void> _deleteExpense(ExpenseItem expense) async {
    if (!await _confirmDelete(expense.title)) return;
    setState(() => expenses.remove(expense));
    await _saveExpenses();
  }

  Future<void> _deleteDebt(DebtItem debt) async {
    if (!await _confirmDelete(debt.name)) return;
    setState(() => debts.remove(debt));
    await _saveDebts();
  }

  Future<void> _deleteGoal(SavingsGoal goal) async {
    if (!await _confirmDelete(goal.name)) return;
    setState(() => savingsGoals.remove(goal));
    await _saveGoals();
  }

  Future<void> _deleteEvent(RoutineEvent event) async {
    if (!await _confirmDelete(event.title)) return;
    setState(() => events.remove(event));
    await _saveEvents();
  }

  Future<void> _addDebtPayment(DebtItem debt) async {
    final amount = await _askAmount('Valor do pagamento');
    if (amount == null) return;
    if (amount > debt.remaining) {
      _message(context, 'O pagamento não pode passar do saldo da dívida.');
      return;
    }
    setState(() => debt.paid += amount);
    await _saveDebts();
  }

  Future<void> _addGoalContribution(SavingsGoal goal) async {
    final amount = await _askAmount('Valor que você guardou');
    if (amount == null) return;
    setState(() => goal.saved += amount);
    await _saveGoals();
  }

  Future<double?> _askAmount(String title) async {
    final text =
        await _textDialog(context, title, 'Ex.: 150,00', numeric: true);
    if (text == null) return null;
    final amount = _parseMoney(text);
    if (amount == null || amount <= 0) {
      _message(context, 'Informe um valor maior que zero.');
      return null;
    }
    return amount;
  }

  double? _parseMoney(String text) => double.tryParse(
        text.contains(',')
            ? text.replaceAll('.', '').replaceAll(',', '.').trim()
            : text.trim(),
      );

  Future<void> _editTask(TaskItem? task, {String? projectName}) async {
    final titleController = TextEditingController(text: task?.title ?? '');
    final projectController = TextEditingController(
      text: task?.project ?? projectName ?? 'Pessoal',
    );
    var deadline = _parseTaskDate(task?.date) ?? DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(task == null ? 'Nova tarefa' : 'Editar tarefa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tarefa'),
              ),
              TextField(
                controller: projectController,
                decoration: const InputDecoration(labelText: 'Projeto'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Prazo: ${_dateLabel(deadline)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: deadline,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) updateDialog(() => deadline = picked);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    final project = projectController.text.trim();
    titleController.dispose();
    projectController.dispose();
    if (saved != true || title.isEmpty) return;
    final date = _dateLabel(deadline);
    setState(() {
      if (task == null) {
        tasks.insert(
          0,
          TaskItem(title, project.isEmpty ? 'Pessoal' : project, date),
        );
      } else {
        task
          ..title = title
          ..project = project.isEmpty ? 'Pessoal' : project
          ..date = date;
      }
    });
    await _saveTasks();
  }

  Future<void> _addEvent() => _editEvent(null);

  Future<void> _editEvent(RoutineEvent? event) async {
    final titleController = TextEditingController(text: event?.title ?? '');
    final now = DateTime.now();
    var startsAt =
        event?.startsAt ?? DateTime(now.year, now.month, now.day, now.hour + 1);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title:
              Text(event == null ? 'Novo compromisso' : 'Editar compromisso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Compromisso'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_dateLabel(startsAt)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: startsAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        updateDialog(
                          () => startsAt = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            startsAt.hour,
                            startsAt.minute,
                          ),
                        );
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_timeLabel(startsAt)),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(startsAt),
                      );
                      if (picked != null) {
                        updateDialog(
                          () => startsAt = DateTime(
                            startsAt.year,
                            startsAt.month,
                            startsAt.day,
                            picked.hour,
                            picked.minute,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    if (saved != true) return;
    if (title.isEmpty) {
      _message(context, 'Informe o nome do compromisso.');
      return;
    }
    setState(() {
      if (event == null) {
        events.add(RoutineEvent(title, startsAt));
      } else {
        event
          ..title = title
          ..startsAt = startsAt;
      }
    });
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    await _saveEvents();
  }

  List<RoutineEvent> get _sortedEvents =>
      [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  DateTime? _parseTaskDate(String? value) {
    if (value == null || value == 'Hoje') return DateTime.now();
    if (value == 'Amanhã') return DateTime.now().add(const Duration(days: 1));
    final parts = value.split('/');
    if (parts.length != 3) return null;
    return DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _eventDate(DateTime date) =>
      '${_dateLabel(date)} · ${_timeLabel(date)}';

  Future<String?> _textDialog(
    BuildContext context,
    String title,
    String hint, {
    bool numeric = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  double get monthTotal => expenses.fold(0, (sum, item) => sum + item.value);
  String _money(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';
  }

  String _todayLabel() {
    const weekdays = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1].capitalize()} · ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
