import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'founder_features.dart';
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

// Capture the email redirect BEFORE Supabase parses and consumes the URL.
// The default email recovery flow includes a fragment with type=recovery.
bool recoveryLinkOpened = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final savedMode = await SharedPreferencesAsync().getString(_themeSettingKey);
    mindArtTheme.value =
        savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {
    // Default to the accessible light theme when device storage is unavailable.
  }
  final incomingUrl = Uri.base;
  recoveryLinkOpened =
      incomingUrl.queryParameters['type'] == 'recovery' ||
      incomingUrl.fragment.contains('type=recovery');
  if (cloudStorageEnabled) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
  runApp(const MindArtApp());
}

const deepGold = Color(0xFF745A00);
const gold = Color(0xFFC5A347);
const paper = Color(0xFFFFFEFA);
const _themeSettingKey = 'mindart.ui.theme';
final ValueNotifier<ThemeMode> mindArtTheme = ValueNotifier(ThemeMode.light);

ThemeData mindArtThemeData(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: gold,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFFE2C56B) : deepGold,
    onPrimary: dark ? const Color(0xFF17140A) : Colors.white,
    secondary: dark ? const Color(0xFFC5A347) : deepGold,
    surface: dark ? const Color(0xFF111111) : paper,
  );
  final surface = dark ? const Color(0xFF101010) : paper;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1C1C1C) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
    ),
  );
}

Future<void> setMindArtTheme(ThemeMode mode) async {
  mindArtTheme.value = mode;
  try {
    await SharedPreferencesAsync().setString(
      _themeSettingKey, mode == ThemeMode.dark ? 'dark' : 'light',
    );
  } catch (_) {
    // A theme preference failing to persist must never block the app.
  }
}

class MindArtApp extends StatelessWidget {
  const MindArtApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: mindArtTheme,
        builder: (context, selectedMode, _) => MaterialApp(
          title: 'MindArt',
          debugShowCheckedModeBanner: false,
          theme: mindArtThemeData(Brightness.light),
          darkTheme: mindArtThemeData(Brightness.dark),
          themeMode: selectedMode,
          home: cloudStorageEnabled ? const AccountGate() : const HomeShell(),
        ),
      );
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key});

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _recoveringPassword = recoveryLinkOpened;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _recoveringPassword = true;
          } else if (state.event == AuthChangeEvent.signedOut) {
            _recoveringPassword = false;
          }
        });
      },
      // Token refresh failures must not crash the entire Flutter web app.
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) setState(() {});
      },
    );
  }

  void _finishRecovery() {
    if (mounted) {
      setState(() {
        _recoveringPassword = false;
        recoveryLinkOpened = false;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AccountPage();
    if (_recoveringPassword) {
      return PasswordRecoveryPage(onComplete: _finishRecovery);
    }
    return HomeShell(key: ValueKey(session.user.id));
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _saved = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _savePassword() async {
    if (_busy) return;
    final password = _password.text;
    if (password.length < 8) {
      _message('Use uma senha com pelo menos 8 caracteres.');
      return;
    }
    if (password != _confirmation.text) {
      _message('As senhas digitadas são diferentes.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      setState(() => _saved = true);
    } on AuthException catch (error) {
      _message('Não foi possível salvar a senha: ${error.message}');
    } catch (_) {
      _message('Falha de conexão. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_reset,
                          color: Theme.of(context).colorScheme.primary, size: 44),
                      const SizedBox(height: 14),
                      Text(
                        _saved ? 'Senha alterada!' : 'Definir nova senha',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_saved) ...[
                        const Text(
                          'A nova senha foi salva. Você já pode acessar seus dados.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: widget.onComplete,
                          child: const Text('Abrir MindArt'),
                        ),
                      ] else ...[
                        const Text(
                          'Escolha uma senha nova com pelo menos 8 caracteres.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Nova senha',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmation,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Confirmar nova senha',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            if (!_busy) _savePassword();
                          },
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _savePassword,
                          child: Text(_busy ? 'Salvando...' : 'Salvar nova senha'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
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
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      _message('Digite seu e-mail para receber o link de recuperação.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: mindArtRedirectUrl,
      );
      _message(
        'Se o endereço estiver cadastrado e autorizado a receber e-mails, '
        'você receberá um link. Verifique também a pasta Spam.',
      );
    } on AuthException catch (error) {
      _message('Falha ao solicitar o link: ${error.message}');
    } catch (_) {
      _message('Não foi possível solicitar o link. Verifique sua conexão.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
                      Icon(Icons.auto_awesome,
                          color: Theme.of(context).colorScheme.primary, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _creatingAccount
                            ? 'Criar sua conta'
                            : 'Entrar no MindArt',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Acesse seus registros em seus aparelhos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  TaskItem(this.title, this.project, this.date,
      {this.done = false, this.priority = false});
  String title;
  String project;
  String date;
  bool done;
  bool priority;

  Map<String, Object?> toJson() => {
        'title': title,
        'project': project,
        'date': date,
        'done': done,
        'priority': priority,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        json['title'] as String,
        json['project'] as String,
        json['date'] as String,
        done: json['done'] as bool? ?? false,
        priority: json['priority'] as bool? ?? false,
      );
}

/// Incomplete starred tasks come first, followed by approaching deadlines.
/// Older saved tasks without a priority flag remain valid.
List<TaskItem> rankFocusTasks(Iterable<TaskItem> source, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  DateTime? dueDate(String date) {
    if (date == 'Hoje') {
      return DateTime(reference.year, reference.month, reference.day);
    }
    if (date == 'Amanhã') {
      return DateTime(reference.year, reference.month, reference.day + 1);
    }
    final parts = date.split('/');
    if (parts.length != 3) return null;
    return DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
  }

  final pending = source.where((task) => !task.done).toList();
  pending.sort((a, b) {
    if (a.priority != b.priority) return a.priority ? -1 : 1;
    final aDate = dueDate(a.date);
    final bDate = dueDate(b.date);
    if (aDate == null && bDate != null) return 1;
    if (bDate == null && aDate != null) return -1;
    final dateCompare = aDate == null || bDate == null
        ? 0
        : aDate.compareTo(bDate);
    return dateCompare != 0 ? dateCompare : a.title.compareTo(b.title);
  });
  return pending;
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
  final voiceEntries = <VoiceEntry>[];
  final healthEntries = <HealthEntry>[];
  final completedLessons = <String>{};
  final passedQuizzes = <String>{};
  bool _cloudReady = false;
  bool _loadingInitialData = true;
  bool _cloudWarningShown = false;
  bool _needsFeatureMigration = false;
  bool _syncInProgress = false;
  bool _syncPending = false;
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
      var savedVoice = await _storage.getString(_storageKey('voiceEntries'));
      var savedHealth = await _storage.getString(_storageKey('healthEntries'));
      var savedLessons = await _storage.getString(_storageKey('completedLessons'));
      var savedQuizzes = await _storage.getString(_storageKey('passedQuizzes'));
      final dirtyOffline = cloudStorageEnabled &&
          (await _storage.getBool(_storageKey('dirty')) ?? false);
      if (dirtyOffline && cloudPayload != null && mounted) {
        final preferLocal = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Alterações offline encontradas'),
            content: const Text(
              'Você alterou registros sem conexão. Deseja manter a versão '
              'deste aparelho e enviá-la para a nuvem, ou usar a versão '
              'que já está salva na nuvem?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Usar versão da nuvem'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Manter alterações offline'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (preferLocal == true) {
          cloudPayload = null;
        } else {
          await _storage.setBool(_storageKey('dirty'), false);
        }
      }
      // Explicit, one-time import for data created before account login.
      // Legacy data is never automatically assigned to another account.
      if (_accountId != null &&
          cloudPayload == null &&
          [savedTasks, savedExpenses, savedEvents, savedDebts, savedGoals,
                  savedProjects, savedVoice, savedHealth, savedLessons, savedQuizzes]
              .every((value) => value == null)) {
        final legacyOwner = await _storage.getString('mindart.legacy.owner');
        if (legacyOwner == null || legacyOwner == _accountId) {
          final legacy = <String, String?>{};
          for (final field in const [
            'tasks', 'expenses', 'events', 'debts', 'savingsGoals', 'projects',
            'voiceEntries', 'healthEntries', 'completedLessons', 'passedQuizzes'
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
              savedVoice = legacy['voiceEntries'];
              savedHealth = legacy['healthEntries'];
              savedLessons = legacy['completedLessons'];
              savedQuizzes = legacy['passedQuizzes'];
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
        _needsFeatureMigration = const [
          'voiceEntries', 'healthEntries', 'completedLessons', 'passedQuizzes'
        ].any((key) => !cloudPayload!.containsKey(key));
        if (cloudPayload.containsKey('voiceEntries')) {
          savedVoice = jsonEncode(cloudPayload['voiceEntries']);
        }
        if (cloudPayload.containsKey('healthEntries')) {
          savedHealth = jsonEncode(cloudPayload['healthEntries']);
        }
        if (cloudPayload.containsKey('completedLessons')) {
          savedLessons = jsonEncode(cloudPayload['completedLessons']);
        }
        if (cloudPayload.containsKey('passedQuizzes')) {
          savedQuizzes = jsonEncode(cloudPayload['passedQuizzes']);
        }
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
      if (savedVoice != null) {
        voiceEntries
          ..clear()
          ..addAll((jsonDecode(savedVoice) as List<dynamic>).map(
            (item) => VoiceEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          ));
      }
      if (savedHealth != null) {
        healthEntries
          ..clear()
          ..addAll((jsonDecode(savedHealth) as List<dynamic>).map(
            (item) => HealthEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          ));
      }
      if (savedLessons != null) {
        completedLessons
          ..clear()
          ..addAll((jsonDecode(savedLessons) as List<dynamic>).cast<String>());
      }
      if (savedQuizzes != null) {
        passedQuizzes
          ..clear()
          ..addAll((jsonDecode(savedQuizzes) as List<dynamic>).cast<String>());
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
    await _saveTasks();
    await _saveExpenses();
    await _saveEvents();
    await _saveDebts();
    await _saveGoals();
    await _saveProjects();
    _cloudReady = cloudStorageEnabled && cloudLoadSucceeded;
    if (_cloudReady && (cloudPayload == null || _needsFeatureMigration)) {
      await _saveCloudSnapshot();
    }
    if (_cloudReady) {
      _listenForCloudChanges();
      await _syncReminderSchedule();
    }
    _loadingInitialData = false;
    if (mounted) setState(() => _ready = true);
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

  Future<void> _applyCloudSnapshot(
    Map<String, dynamic> payload, {
    bool replaceOfflineChanges = false,
  }) async {
    try {
      if (!replaceOfflineChanges &&
          (_syncInProgress ||
              (await _storage.getBool(_storageKey('dirty')) ?? false))) {
        return;
      }
      List<dynamic> listFor(String key, [List<dynamic> fallback = const []]) {
        final value = payload[key] ?? fallback;
        if (value is! List) throw const FormatException('Snapshot inválido.');
        return value;
      }

      Map<String, dynamic> itemMap(Object? item) {
        if (item is! Map) throw const FormatException('Registro inválido.');
        return Map<String, dynamic>.from(item);
      }

      Set<String> stringSet(String key, [Set<String> fallback = const {}]) {
        final values = listFor(key, fallback.toList());
        if (values.any((value) => value is! String)) {
          throw const FormatException('Progresso inválido.');
        }
        return values.cast<String>().toSet();
      }

      final nextTasks = listFor('tasks')
          .map((item) => TaskItem.fromJson(itemMap(item))).toList();
      final nextExpenses = listFor('expenses')
          .map((item) => ExpenseItem.fromJson(itemMap(item))).toList();
      final nextEvents = listFor('events')
          .map((item) => RoutineEvent.fromJson(itemMap(item))).toList();
      final nextDebts = listFor('debts')
          .map((item) => DebtItem.fromJson(itemMap(item))).toList();
      final nextGoals = listFor('savingsGoals')
          .map((item) => SavingsGoal.fromJson(itemMap(item))).toList();
      final nextProjects = listFor('projects')
          .map((item) => ProjectItem.fromJson(itemMap(item))).toList();
      final nextVoice = listFor('voiceEntries', voiceEntries.map((item) => item.toJson()).toList())
          .map((item) => VoiceEntry.fromJson(itemMap(item))).toList();
      final nextHealth = listFor('healthEntries', healthEntries.map((item) => item.toJson()).toList())
          .map((item) => HealthEntry.fromJson(itemMap(item))).toList();
      final nextLessons = stringSet('completedLessons', completedLessons);
      final nextQuizzes = stringSet('passedQuizzes', passedQuizzes);
      tasks
        ..clear()
        ..addAll(nextTasks);
      expenses
        ..clear()
        ..addAll(nextExpenses);
      events
        ..clear()
        ..addAll(nextEvents);
      debts
        ..clear()
        ..addAll(nextDebts);
      savingsGoals
        ..clear()
        ..addAll(nextGoals);
      projects
        ..clear()
        ..addAll(nextProjects);
      voiceEntries
        ..clear()
        ..addAll(nextVoice);
      healthEntries
        ..clear()
        ..addAll(nextHealth);
      completedLessons
        ..clear()
        ..addAll(nextLessons);
      passedQuizzes
        ..clear()
        ..addAll(nextQuizzes);
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
      await _storage.setString(_storageKey('voiceEntries'),
          jsonEncode(voiceEntries.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('healthEntries'),
          jsonEncode(healthEntries.map((item) => item.toJson()).toList()));
      await _storage.setString(_storageKey('completedLessons'),
          jsonEncode(completedLessons.toList()));
      await _storage.setString(_storageKey('passedQuizzes'),
          jsonEncode(passedQuizzes.toList()));
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

  Future<void> _saveFounderFeatures() async {
    await _storage.setString(_storageKey('voiceEntries'),
        jsonEncode(voiceEntries.map((item) => item.toJson()).toList()));
    await _storage.setString(_storageKey('healthEntries'),
        jsonEncode(healthEntries.map((item) => item.toJson()).toList()));
    await _storage.setString(_storageKey('completedLessons'),
        jsonEncode(completedLessons.toList()));
    await _storage.setString(_storageKey('passedQuizzes'),
        jsonEncode(passedQuizzes.toList()));
    await _syncCloudIfReady();
  }

  Map<String, Object?> _cloudSnapshot() => {
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'expenses': expenses.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
        'debts': debts.map((item) => item.toJson()).toList(),
        'savingsGoals': savingsGoals.map((item) => item.toJson()).toList(),
        'projects': projects.map((item) => item.toJson()).toList(),
        'voiceEntries': voiceEntries.map((item) => item.toJson()).toList(),
        'healthEntries': healthEntries.map((item) => item.toJson()).toList(),
        'completedLessons': completedLessons.toList(),
        'passedQuizzes': passedQuizzes.toList(),
      };

  Future<void> _syncCloudIfReady() async {
    if (_loadingInitialData) return;
    if (_cloudReady) {
      await _saveCloudSnapshot();
    } else if (cloudStorageEnabled) {
      await _storage.setBool(_storageKey('dirty'), true);
    }
  }

  Future<void> _saveCloudSnapshot() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id != _accountId) return;
    if (_syncInProgress) {
      _syncPending = true;
      return;
    }
    _syncInProgress = true;
    try {
      do {
        _syncPending = false;
        await _storage.setBool(_storageKey('dirty'), true);
        try {
          await Supabase.instance.client.from('mindart_user_data').upsert(
            {'user_id': user.id, 'payload': _cloudSnapshot()},
            onConflict: 'user_id',
          );
          await _storage.setBool(_storageKey('dirty'), false);
        } catch (_) {
          await _storage.setBool(_storageKey('dirty'), true);
          if (mounted && !_cloudWarningShown) {
            _cloudWarningShown = true;
            _message(context,
                'Salvei neste aparelho, mas não consegui atualizar a nuvem. Confira sua conexão.');
          }
          return;
        }
      } while (_syncPending);
    } finally {
      _syncInProgress = false;
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
    for (final name in const ['voiceEntries', 'healthEntries']) {
      final value = data[name];
      if (value != null && value is! List) {
        throw const FormatException('Seção opcional inválida.');
      }
    }
    for (final name in const ['completedLessons', 'passedQuizzes']) {
      final value = data[name];
      if (value != null &&
          (value is! List || value.any((item) => item is! String))) {
        throw const FormatException('Progresso do Academy inválido.');
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
    for (final item in (data['voiceEntries'] as List? ?? const [])) {
      VoiceEntry.fromJson(Map<String, dynamic>.from(item as Map));
    }
    for (final item in (data['healthEntries'] as List? ?? const [])) {
      HealthEntry.fromJson(Map<String, dynamic>.from(item as Map));
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
      await _applyCloudSnapshot(data, replaceOfflineChanges: true);
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
    final pages = [
      _dashboard(),
      _projects(),
      _finances(),
      _routine(),
      MindArtHub(
        voiceEntries: voiceEntries,
        healthEntries: healthEntries,
        completedLessons: completedLessons,
        passedQuizzes: passedQuizzes,
        onVoiceEntriesChanged: (items) => setState(() {
          voiceEntries..clear()..addAll(items);
          unawaited(_saveFounderFeatures());
        }),
        onHealthEntriesChanged: (items) => setState(() {
          healthEntries..clear()..addAll(items);
          unawaited(_saveFounderFeatures());
        }),
        onCompletedLessonsChanged: (items) => setState(() {
          completedLessons..clear()..addAll(items);
          unawaited(_saveFounderFeatures());
        }),
        onPassedQuizzesChanged: (items) => setState(() {
          passedQuizzes..clear()..addAll(items);
          unawaited(_saveFounderFeatures());
        }),
      ),
    ];
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
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: gold,
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
              IconButton(
                tooltip: mindArtTheme.value == ThemeMode.dark
                    ? 'Ativar tema claro'
                    : 'Ativar tema escuro',
                onPressed: () => setMindArtTheme(
                  mindArtTheme.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
                icon: Icon(mindArtTheme.value == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções do aplicativo',
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
              Padding(
                padding: EdgeInsets.only(right: 20),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.person_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
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
                          NavigationRailDestination(
                            icon: Icon(Icons.auto_awesome_outlined),
                            label: Text('MindArt'),
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
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      label: 'MindArt',
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addItem(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
    final focus = rankFocusTasks(tasks).take(4).toList();
    final upcoming = events.where((item) => item.startsAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _page(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Vamos cuidar do que importa.',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 22),
          Text('Acesso rápido',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _oneTouch('Nova tarefa', Icons.add_task, () => _editTask(null)),
              _oneTouch('Registrar gasto', Icons.add_card_outlined,
                  () => _editExpense(null)),
              _oneTouch('Compromisso', Icons.event_available_outlined,
                  _addEvent),
              _oneTouch('MindArt Voice', Icons.mic_none,
                  () => setState(() => selected = 4)),
            ],
          ),
          const SizedBox(height: 22),
          _sectionTitle(
            'Suas prioridades',
            'Nova tarefa',
            () => _editTask(null),
          ),
          const SizedBox(height: 8),
          if (focus.isEmpty)
            _empty('Nenhuma tarefa pendente',
                'Toque em Nova tarefa e marque o que é prioridade.')
          else
            ...focus.map(_taskTile),
          const SizedBox(height: 12),
          Text(
            'Dica: abra as opções de uma tarefa para destacar ou retirar a estrela.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(
            'Próximos compromissos',
            'Ver agenda',
            () => setState(() => selected = 3),
          ),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            _empty('Nenhum compromisso próximo',
                'Use o botão + para cadastrar um novo compromisso.')
          else ...[
            _featuredEvent(upcoming.first),
            ...upcoming.skip(1).take(2).map(_upcomingEventTile),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Tarefas concluídas',
                  '${done}/${tasks.length}',
                  Icons.check_circle_outline,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  'Gastos no mês',
                  _money(monthTotal),
                  Icons.trending_down,
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
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

  Widget _featuredEvent(RoutineEvent event) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => selected = 3),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  color: colors.onPrimaryContainer, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRÓXIMO COMPROMISSO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: colors.onPrimaryContainer,
                        )),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _eventDate(event.startsAt),
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oneTouch(String label, IconData icon, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );

  Widget _upcomingEventTile(RoutineEvent event) => Card(
        child: ListTile(
          onTap: () => setState(() => selected = 3),
          leading: Icon(Icons.event_outlined,
              color: Theme.of(context).colorScheme.primary),
          title: Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(_eventDate(event.startsAt)),
          trailing: const Icon(Icons.chevron_right),
        ),
      );

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
                        style: TextStyle(
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('${projectTasks.length} tarefa(s)',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
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
                  Text('Gastos registrados',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(_money(monthTotal),
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Text('Total registrado',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                  leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.receipt_long,
                          color: Theme.of(context).colorScheme.primary)),
                  title: Text(expense.title,
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(expense.category),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_money(expense.value),
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
                        style: TextStyle(
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
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest),
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
                        style: TextStyle(
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
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest),
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
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _todayLabel(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Sua agenda começa com pequenos passos.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15),
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
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
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
          title: Row(
            children: [
              if (task.priority)
                Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.star_rounded,
                      color: Theme.of(context).colorScheme.secondary, size: 21),
                ),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: task.priority ? FontWeight.w800 : FontWeight.w700,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text('${task.project}  ·  ${task.date}'),
          activeColor: Theme.of(context).colorScheme.primary,
          secondary: PopupMenuButton<String>(
            tooltip: 'Opções da tarefa',
            onSelected: (action) async {
              if (action == 'edit') {
                await _editTask(task);
              } else if (action == 'delete') {
                await _deleteTask(task);
              } else if (action == 'priority') {
                setState(() => task.priority = !task.priority);
                await _saveTasks();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'priority',
                child: ListTile(
                  leading: Icon(task.priority
                      ? Icons.star_outline
                      : Icons.star_rounded),
                  title: Text(task.priority
                      ? 'Remover prioridade'
                      : 'Destacar prioridade'),
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              const PopupMenuItem(
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
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.event_outlined,
                color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(
            event.title,
            style: TextStyle(fontWeight: FontWeight.w700),
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(icon,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          sub,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                Icon(Icons.spa_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 30),
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    var priority = task?.priority ?? false;
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Marcar como prioridade'),
                value: priority,
                onChanged: (value) => updateDialog(() => priority = value),
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
          TaskItem(title, project.isEmpty ? 'Pessoal' : project, date,
              priority: priority),
        );
      } else {
        task
          ..title = title
          ..project = project.isEmpty ? 'Pessoal' : project
          ..date = date
          ..priority = priority;
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
