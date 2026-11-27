import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceEntry {
  VoiceEntry(this.text, this.category, {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  final String text;
  final String category;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'text': text,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VoiceEntry.fromJson(Map<String, dynamic> json) => VoiceEntry(
        json['text'] as String,
        json['category'] as String? ?? 'Nota',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class HealthEntry {
  HealthEntry(this.title, this.kind, this.details, this.scheduledAt);

  final String title;
  final String kind;
  final String details;
  final DateTime scheduledAt;

  Map<String, Object?> toJson() => {
        'title': title,
        'kind': kind,
        'details': details,
        'scheduledAt': scheduledAt.toIso8601String(),
      };

  factory HealthEntry.fromJson(Map<String, dynamic> json) => HealthEntry(
        json['title'] as String,
        json['kind'] as String? ?? 'Nota de saúde',
        json['details'] as String? ?? '',
        DateTime.tryParse(json['scheduledAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class MindArtHub extends StatefulWidget {
  const MindArtHub({
    required this.voiceEntries,
    required this.healthEntries,
    required this.completedLessons,
    required this.passedQuizzes,
    required this.onVoiceEntriesChanged,
    required this.onHealthEntriesChanged,
    required this.onCompletedLessonsChanged,
    required this.onPassedQuizzesChanged,
    super.key,
  });

  final List<VoiceEntry> voiceEntries;
  final List<HealthEntry> healthEntries;
  final Set<String> completedLessons;
  final Set<String> passedQuizzes;
  final ValueChanged<List<VoiceEntry>> onVoiceEntriesChanged;
  final ValueChanged<List<HealthEntry>> onHealthEntriesChanged;
  final ValueChanged<Set<String>> onCompletedLessonsChanged;
  final ValueChanged<Set<String>> onPassedQuizzesChanged;

  @override
  State<MindArtHub> createState() => _MindArtHubState();
}

class _MindArtHubState extends State<MindArtHub> {
  static const _gold = Color(0xFFC5A347);
  static const _tracks = <_Lesson>[
    _Lesson(
      id: 'focus-1',
      track: 'Foco leve',
      title: 'Escolha o próximo passo',
      body:
          'Quando tudo parece urgente, escolha uma única ação pequena que '
          'destrava o restante. Dê a ela um começo claro e um tempo curto.',
      question: 'O que ajuda quando tudo parece urgente?',
      answers: ['Começar por uma ação pequena', 'Fazer tudo ao mesmo tempo'],
      correct: 0,
    ),
    _Lesson(
      id: 'focus-2',
      track: 'Foco leve',
      title: 'Faça uma pausa consciente',
      body:
          'Uma pausa breve pode ajudar a recuperar clareza. Afaste-se da tela, '
          'respire com tranquilidade e retome quando estiver pronto.',
      question: 'Qual é uma opção simples de pausa?',
      answers: ['Continuar sem parar', 'Afastar-se da tela por um momento'],
      correct: 1,
    ),
    _Lesson(
      id: 'money-1',
      track: 'Dinheiro com clareza',
      title: 'Registre antes de decidir',
      body:
          'Anotar uma entrada ou saída cria uma visão mais clara do mês. '
          'O registro é uma ferramenta de informação, sem julgamento.',
      question: 'Para que serve registrar um gasto?',
      answers: ['Para entender melhor o mês', 'Para criar uma obrigação de compra'],
      correct: 0,
    ),
    _Lesson(
      id: 'habits-1',
      track: 'Rotina possível',
      title: 'Comece pequeno',
      body:
          'Um hábito pode começar com uma ação que caiba no dia de hoje. '
          'Se a rotina mudar, ajuste a ação para que ela continue possível.',
      question: 'Como começar uma rotina nova?',
      answers: ['Com um passo possível', 'Esperando o dia perfeito'],
      correct: 0,
    ),
  ];

  final SpeechToText _speech = SpeechToText();
  final ValueNotifier<bool> _listening = ValueNotifier(false);
  bool _speechAvailable = false;
  bool _speechInitialized = false;
  bool _voicePrivacyConfirmed = false;

  int get _points =>
      widget.completedLessons.length * 15 + widget.passedQuizzes.length * 10;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _initializeSpeech() async {
    if (_speechInitialized) return _speechAvailable;
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          _listening.value = status == 'listening';
        },
        onError: (_) {
          if (!mounted) return;
          _listening.value = false;
        },
      );
      _speechInitialized = true;
      _speechAvailable = available;
      if (mounted) setState(() {});
      return available;
    } catch (_) {
      _speechInitialized = true;
      _speechAvailable = false;
      if (mounted) setState(() {});
      return false;
    }
  }

  String _classify(String text) {
    final normalized = text.toLowerCase()
        .replaceAll(RegExp('[áàãâ]'), 'a')
        .replaceAll(RegExp('[éê]'), 'e')
        .replaceAll(RegExp('[í]'), 'i')
        .replaceAll(RegExp('[óôõ]'), 'o')
        .replaceAll(RegExp('[ú]'), 'u')
        .replaceAll('ç', 'c');
    if (RegExp(r'\b(remedio|medicamento|consulta|medico|saude|refeicao|alimentacao|exame)\b')
        .hasMatch(normalized)) return 'Saúde';
    if (RegExp(r'\b(gastei|paguei|comprar|compra|conta|reais|dinheiro|despesa)\b')
        .hasMatch(normalized)) return 'Finanças';
    if (RegExp(r'\b(ideia|projeto|pensei|imagino|criar)\b').hasMatch(normalized)) {
      return 'Ideia';
    }
    if (RegExp(r'\b(fazer|preciso|tarefa|lembrar|entregar|resolver)\b')
        .hasMatch(normalized)) return 'Tarefa';
    return 'Nota';
  }

  Future<bool> _confirmVoicePrivacy() async {
    if (_voicePrivacyConfirmed) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Antes de usar a voz'),
        content: const Text(
          'O reconhecimento pode ser processado pelo serviço de fala do aparelho ou navegador. Evite dizer senhas e informações de saúde ou financeiras. Para conteúdo sensível, use a digitação do teclado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Usar teclado'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar com voz'),
          ),
        ],
      ),
    );
    _voicePrivacyConfirmed = confirmed == true;
    return _voicePrivacyConfirmed;
  }

  Future<void> _newVoiceEntry() async {
    final controller = TextEditingController();
    String? category;
    var saving = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('MindArt Voice'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'O que você quer registrar?',
                    hintText: 'Ex.: lembrar de marcar uma consulta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: _listening,
                  builder: (context, isListening, _) => FilledButton.tonalIcon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (isListening) {
                              await _speech.stop();
                              return;
                            }
                            try {
                              setDialogState(() => saving = true);
                              if (!await _confirmVoicePrivacy()) return;
                              final available = await _initializeSpeech();
                              if (!available) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('O reconhecimento de voz não está disponível neste navegador. Use a ditagem do teclado.'),
                                    ),
                                  );
                                }
                                return;
                              }
                              await _speech.listen(
                                onResult: (result) {
                                  controller.text = result.recognizedWords;
                                  category = _classify(controller.text);
                                  setDialogState(() {});
                                },
                                listenOptions: SpeechListenOptions(
                                  localeId: 'pt_BR',
                                  listenFor: const Duration(seconds: 30),
                                  pauseFor: const Duration(seconds: 3),
                                  listenMode: ListenMode.dictation,
                                ),
                              );
                            } finally {
                              if (context.mounted) setDialogState(() => saving = false);
                            }
                          },
                    icon: Icon(isListening ? Icons.stop : Icons.mic_none),
                    label: Text(isListening
                        ? 'Parar gravação'
                        : 'Falar por até 30 segundos'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _speechAvailable
                      ? 'A voz pode ser processada pelo serviço do aparelho ou navegador. Não diga informações sensíveis.'
                      : 'Prefira a digitação do teclado para manter informações sensíveis fora do reconhecimento de fala.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (controller.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InputChip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: Text('Classificação sugerida: ${_classify(controller.text)}'),
                    onPressed: () => setDialogState(
                      () => category = _classify(controller.text),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Salvar registro'),
            ),
          ],
        ),
      ),
    );
    await _speech.stop();
    if (result == true && controller.text.trim().isNotEmpty) {
      final entry = VoiceEntry(
        controller.text.trim(),
        category ?? _classify(controller.text),
      );
      widget.onVoiceEntriesChanged([entry, ...widget.voiceEntries]);
    }
    controller.dispose();
  }

  Future<void> _editHealthEntry([HealthEntry? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final details = TextEditingController(text: existing?.details ?? '');
    var kind = existing?.kind ?? 'Alimentação';
    var scheduledAt = existing?.scheduledAt ?? DateTime.now();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Novo registro de saúde' : 'Editar registro'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const ['Alimentação', 'Medicamento', 'Procedimento', 'Consulta', 'Nota de saúde']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => kind = value ?? kind),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Nome ou descrição',
                      hintText: 'Ex.: almoço, medicamento, exame',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextField(
                    controller: details,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Detalhes (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: scheduledAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(scheduledAt),
                      );
                      if (time != null) {
                        setDialogState(() => scheduledAt = DateTime(
                          date.year, date.month, date.day, time.hour, time.minute,
                        ));
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(_formatDate(scheduledAt)),
                  ),
                ],
              ),
            ),
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
    if (result == true && title.text.trim().isNotEmpty) {
      final updated = HealthEntry(title.text.trim(), kind, details.text.trim(), scheduledAt);
      final next = [...widget.healthEntries];
      if (existing != null) next.remove(existing);
      next.add(updated);
      next.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      widget.onHealthEntriesChanged(next);
    }
    title.dispose();
    details.dispose();
  }

  Future<void> _openLesson(_Lesson lesson) async {
    var selected = -1;
    var answered = widget.passedQuizzes.contains(lesson.id);
    var quizMessage = '';
    final passed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(lesson.title),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lesson.body),
                  const SizedBox(height: 20),
                  Text(lesson.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  RadioGroup<int>(
                    groupValue: selected,
                    onChanged: answered
                        ? (_) {}
                        : (value) => setDialogState(() => selected = value ?? -1),
                    child: Column(
                      children: List.generate(
                        lesson.answers.length,
                        (index) => RadioListTile<int>(
                          value: index,
                          title: Text(lesson.answers[index]),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  if (quizMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(quizMessage),
                    ),
                  if (answered)
                    const Text('Aula concluída. Você pode rever este conteúdo quando quiser.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: answered
                  ? () => Navigator.pop(dialogContext, true)
                  : selected < 0
                      ? null
                      : () {
                          if (selected == lesson.correct) {
                            Navigator.pop(dialogContext, true);
                          } else {
                            setDialogState(() => quizMessage =
                                'Quase. Revise a microaula e tente outra vez.');
                          }
                        },
              child: Text(answered ? 'Concluído' : 'Conferir resposta'),
            ),
          ],
        ),
      ),
    );
    if (passed == true && !widget.passedQuizzes.contains(lesson.id)) {
      widget.onCompletedLessonsChanged({...widget.completedLessons, lesson.id});
      widget.onPassedQuizzesChanged({...widget.passedQuizzes, lesson.id});
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _listening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome, color: _gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MindArt 000', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Um lugar para cuidar do que importa', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.mic_none), text: 'Voice'),
                Tab(icon: Icon(Icons.school_outlined), text: 'Academy'),
                Tab(icon: Icon(Icons.favorite_border), text: 'Saúde'),
                Tab(icon: Icon(Icons.stars_outlined), text: 'Rewards'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_voicePage(), _academyPage(), _healthPage(), _rewardsPage()],
              ),
            ),
          ],
        ),
      );

  Widget _voicePage() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _intro('Registre uma ideia sem interromper o seu momento.', 'A captura é manual e você pode revisar tudo antes de salvar.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _newVoiceEntry,
            icon: const Icon(Icons.mic_none),
            label: const Text('Novo registro por voz ou texto'),
          ),
          const SizedBox(height: 20),
          if (widget.voiceEntries.isEmpty)
            _empty('Nenhum registro ainda', 'Se quiser, faça uma anotação rápida por voz ou texto.')
          else
            ...widget.voiceEntries.map((entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(entry.text),
                    subtitle: Text('${entry.category} · ${_formatDate(entry.createdAt)}'),
                    trailing: IconButton(
                      tooltip: 'Apagar registro',
                      onPressed: () => widget.onVoiceEntriesChanged(
                        widget.voiceEntries.where((item) => item != entry).toList(),
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                )),
        ],
      );

  Widget _academyPage() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _intro('Microaulas práticas e curtas.', 'Estude no seu ritmo. O progresso fica salvo e pode ser revisto.'),
          const SizedBox(height: 18),
          ..._tracks.map((lesson) => Card(
                child: ListTile(
                  leading: Icon(
                    widget.completedLessons.contains(lesson.id)
                        ? Icons.check_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  title: Text(lesson.title),
                  subtitle: Text(lesson.track),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLesson(lesson),
                ),
              )),
        ],
      );

  Widget _healthPage() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _intro('Sua rotina de saúde, organizada por você.', 'Registre alimentação, medicamentos, consultas e procedimentos. Este espaço organiza seus registros e não substitui orientação profissional.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _editHealthEntry(),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar registro de saúde'),
          ),
          const SizedBox(height: 18),
          if (widget.healthEntries.isEmpty)
            _empty('Ainda não há registros', 'Adicione um horário de alimentação, medicamento ou procedimento se for útil para você.')
          else
            ...widget.healthEntries.map((entry) => Card(
                  child: ListTile(
                    onTap: () => _editHealthEntry(entry),
                    leading: Icon(_healthIcon(entry.kind)),
                    title: Text(entry.title),
                    subtitle: Text('${entry.kind} · ${_formatDate(entry.scheduledAt)}${entry.details.isEmpty ? '' : '\n${entry.details}'}'),
                    isThreeLine: entry.details.isNotEmpty,
                    trailing: IconButton(
                      tooltip: 'Apagar registro',
                      onPressed: () => widget.onHealthEntriesChanged(
                        widget.healthEntries.where((item) => item != entry).toList(),
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                )),
        ],
      );

  Widget _rewardsPage() {
    final nextReward = ((_points ~/ 50) + 1) * 50;
    final unlocked = _points ~/ 50;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _intro('Reconhecimento pelo seu aprendizado.', 'Pontos são apenas um registro simbólico. Sem sequência diária, pressão ou compra dentro do app.'),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.stars_outlined, size: 42, color: _gold),
                const SizedBox(height: 8),
                Text('$_points MindPoints', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('A próxima marca simbólica é em $nextReward pontos.'),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: (_points % 50) / 50),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Conquistas liberadas: $unlocked', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (unlocked == 0)
          _empty('Sem metas para correr atrás', 'As conquistas aparecem naturalmente ao concluir microaulas. Você não perde pontos por fazer uma pausa.'),
        for (var i = 0; i < unlocked; i++)
          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined, color: _gold),
              title: Text('Aprendizado ${i + 1}'),
              subtitle: const Text('Conquista simbólica, sem custo ou benefício financeiro.'),
            ),
          ),
      ],
    );
  }

  Widget _intro(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );

  Widget _empty(String title, String message) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.spa_outlined, size: 30),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  IconData _healthIcon(String kind) => switch (kind) {
        'Alimentação' => Icons.restaurant_outlined,
        'Medicamento' => Icons.medication_outlined,
        'Procedimento' => Icons.medical_services_outlined,
        'Consulta' => Icons.event_available_outlined,
        _ => Icons.favorite_border,
      };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _Lesson {
  const _Lesson({
    required this.id,
    required this.track,
    required this.title,
    required this.body,
    required this.question,
    required this.answers,
    required this.correct,
  });

  final String id;
  final String track;
  final String title;
  final String body;
  final String question;
  final List<String> answers;
  final int correct;
}
