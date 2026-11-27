import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

String mergeVoiceTranscript(String current, String recognizedSegment) {
  final existing = current.trim();
  final segment = recognizedSegment.trim();
  if (existing.isEmpty) return segment;
  if (segment.isEmpty) return existing;
  if (segment.toLowerCase().startsWith(existing.toLowerCase())) {
    return segment;
  }

  final previousWords = existing.split(RegExp(r'\s+'));
  final nextWords = segment.split(RegExp(r'\s+'));
  final maxOverlap = previousWords.length < nextWords.length
      ? previousWords.length
      : nextWords.length;
  var overlap = 0;
  for (var length = maxOverlap; length > 0; length--) {
    final previousTail = previousWords.skip(previousWords.length - length);
    final nextHead = nextWords.take(length);
    final matches = previousTail
        .map((word) => word.toLowerCase().replaceAll(RegExp(r'^[,.;:!?]+|[,.;:!?]+$'), ''))
        .join(' ');
    final candidate = nextHead
        .map((word) => word.toLowerCase().replaceAll(RegExp(r'^[,.;:!?]+|[,.;:!?]+$'), ''))
        .join(' ');
    if (matches == candidate) {
      overlap = length;
      break;
    }
  }
  return '$existing ${nextWords.skip(overlap).join(' ')}'.trim();
}

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

class VoiceIntent {
  const VoiceIntent({
    required this.category,
    required this.title,
    this.dueDate,
    this.scheduledAt,
    this.expenseAmount,
  });

  final String category;
  final String title;
  final DateTime? dueDate;
  final DateTime? scheduledAt;
  final double? expenseAmount;
}

String _normalizeVoiceText(String text) => text.toLowerCase()
    .replaceAll(RegExp('[áàãâ]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll(RegExp('[í]'), 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll(RegExp('[ú]'), 'u')
    .replaceAll('ç', 'c');

/// Extracts only clear actions, amounts and times. Ambiguous speech remains a
/// categorized note instead of creating a guessed financial value or schedule.
VoiceIntent classifyVoiceIntent(String text, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final normalized = _normalizeVoiceText(text);
  final foodWords = RegExp(r'\b(almoco|almocar|jantar|cafe da manha|lanche|refeicao|alimentacao|comer)\b');
  final spendingWords = RegExp(r'\b(gastei|paguei|comprei|compra|despesa|custou|pagar|gasto)\b');
  final healthWords = RegExp(r'\b(remedio|medicamento|consulta|medico|saude|exame|alimentacao|refeicao|almoco|jantar|lanche)\b');
  final hasExplicitMoney = RegExp(r'r\$\s*\d|\d+[,.]?\d*\s*reais?\b').hasMatch(normalized) ||
      (spendingWords.hasMatch(normalized) && RegExp(r'\b\d+[,.]?\d*\b').hasMatch(normalized));

  double? amount;
  final moneyMatch = RegExp(r'r\$\s*(\d+(?:[.,]\d{1,2})?)|\b(\d+(?:[.,]\d{1,2})?)\s*reais?\b').firstMatch(normalized);
  final genericAmount = moneyMatch == null && hasExplicitMoney
      ? RegExp(r'\b(\d+(?:[.,]\d{1,2})?)\b').firstMatch(normalized)
      : null;
  final rawAmount = moneyMatch?.group(1) ?? moneyMatch?.group(2) ?? genericAmount?.group(1);
  if (rawAmount != null) amount = double.tryParse(rawAmount.replaceAll(',', '.'));

  DateTime? date;
  if (RegExp(r'\bamanha\b').hasMatch(normalized)) {
    date = DateTime(reference.year, reference.month, reference.day + 1);
  } else if (RegExp(r'\bhoje\b').hasMatch(normalized)) {
    date = DateTime(reference.year, reference.month, reference.day);
  } else {
    final explicitDate = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b').firstMatch(normalized);
    if (explicitDate != null) {
      final yearText = explicitDate.group(3);
      final year = yearText == null
          ? reference.year
          : int.parse(yearText.length == 2 ? '20$yearText' : yearText);
      final month = int.parse(explicitDate.group(2)!);
      final day = int.parse(explicitDate.group(1)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        date = DateTime(year, month, day);
        if (date.month != month || date.day != day) date = null;
      }
    }
  }
  final timeMatch = RegExp(r'(?:\b(?:as|pelas|por volta das)\s+)?(\d{1,2})(?::(\d{2})|h(\d{2})?|\s*horas?)?\b').firstMatch(normalized);
  final hasTime = timeMatch != null && RegExp(
    r'\b(?:as|pelas|por volta das)\s+\d{1,2}|\d{1,2}:\d{2}|\d{1,2}\s*h|\d{1,2}\s*horas?\b|\bamanha\s+\d{1,2}\b',
  ).hasMatch(normalized);
  DateTime? scheduledAt;
  if (hasTime) {
    var hour = int.parse(timeMatch!.group(1)!);
    final minute = int.tryParse(timeMatch.group(2) ?? timeMatch.group(3) ?? '') ?? 0;
    if (hour < 12 && RegExp(r'\b(tarde|noite)\b').hasMatch(normalized)) {
      hour += 12;
    }
    if (hour <= 23 && minute <= 59) {
      final day = date ?? DateTime(reference.year, reference.month, reference.day);
      scheduledAt = DateTime(day.year, day.month, day.day, hour, minute);
      if (scheduledAt.isBefore(reference) && date == null) {
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }
    }
  }

  final isTask = RegExp(r'\b(fazer|preciso|tarefa|lembrar|entregar|resolver|ir|marcar|agendar|tenho que|vou|academia|treino)\b').hasMatch(normalized);
  final category = spendingWords.hasMatch(normalized) || hasExplicitMoney
      ? 'Finanças'
      : healthWords.hasMatch(normalized) || foodWords.hasMatch(normalized)
          ? 'Saúde'
          : RegExp(r'\b(ideia|projeto|pensei|imagino|criar)\b').hasMatch(normalized)
              ? 'Ideia'
              : isTask
                  ? 'Tarefa'
                  : 'Nota';
  final title = text.trim().replaceFirst(
    RegExp(r'^(?:eu\s+)?(?:preciso\s+)?(?:lembrar\s+de\s+|tenho\s+que\s+|vou\s+|quero\s+)?', caseSensitive: false),
    '',
  );
  return VoiceIntent(
    category: category,
    title: title.isEmpty ? text.trim() : title,
    dueDate: date,
    scheduledAt: scheduledAt,
    expenseAmount: category == 'Finanças' ? amount : null,
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
    required this.onVoiceEntryCreated,
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
  final Future<void> Function(VoiceEntry entry, VoiceIntent intent)
      onVoiceEntryCreated;
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
  final ValueNotifier<String?> _voiceError = ValueNotifier(null);
  Completer<void>? _speechStopped;
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
        finalTimeout: const Duration(seconds: 5),
        onStatus: (status) {
          if (!mounted) return;
          _listening.value = status == 'listening';
          if (status == 'done' || status == 'notListening') {
            final stopped = _speechStopped;
            if (stopped != null && !stopped.isCompleted) stopped.complete();
          }
        },
        onError: (_) {
          if (!mounted) return;
          _listening.value = false;
          _voiceError.value =
              'A fala não foi reconhecida. Confira a permissão do microfone e tente novamente.';
          final stopped = _speechStopped;
          if (stopped != null && !stopped.isCompleted) stopped.complete();
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

  Future<String?> _portugueseLocaleId() async {
    try {
      final locales = await _speech.locales();
      final brazilian = locales.where((locale) {
        final id = locale.localeId.toLowerCase().replaceAll('_', '-');
        return id == 'pt-br';
      });
      if (brazilian.isNotEmpty) return brazilian.first.localeId;
      final portuguese = locales.where(
        (locale) => locale.localeId.toLowerCase().startsWith('pt'),
      );
      if (portuguese.isNotEmpty) return portuguese.first.localeId;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _stopVoiceAndWaitForResult() async {
    if (!_listening.value && !_speech.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return;
    }
    final stopped = Completer<void>();
    _speechStopped = stopped;
    try {
      await _speech.stop();
    } catch (_) {
      // Still wait briefly for a final recognition callback from the platform.
    }
    try {
      await stopped.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Some browser recognizers stop without sending a final status event.
    } finally {
      if (identical(_speechStopped, stopped)) _speechStopped = null;
    }
    // Let the final onResult callback update the text field before saving it.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  String _classify(String text) {
    return classifyVoiceIntent(text).category;
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
                              await _stopVoiceAndWaitForResult();
                              return;
                            }
                            try {
                              setDialogState(() => saving = true);
                              _voiceError.value = null;
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
                              final localeId = await _portugueseLocaleId();
                              final prefixAtSessionStart = controller.text.trim();
                              await _speech.listen(
                                onResult: (result) {
                                  final recognized = result.recognizedWords.trim();
                                  if (recognized.isEmpty) return;
                                  final transcript = mergeVoiceTranscript(
                                    prefixAtSessionStart,
                                    recognized,
                                  );
                                  controller.value = TextEditingValue(
                                    text: transcript,
                                    selection: TextSelection.collapsed(
                                      offset: transcript.length,
                                    ),
                                  );
                                  category = _classify(controller.text);
                                  if (context.mounted) setDialogState(() {});
                                },
                                listenOptions: SpeechListenOptions(
                                  localeId: localeId,
                                  listenFor: const Duration(seconds: 60),
                                  pauseFor: const Duration(seconds: 8),
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
                        : 'Falar por até 1 minuto'),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: _voiceError,
                  builder: (context, error, _) => Text(
                    error ??
                        (_speechAvailable
                            ? 'Toque em Parar gravação ou Salvar registro para finalizar. A voz pode ser processada pelo aparelho ou navegador; não diga dados sensíveis.'
                            : 'Prefira a digitação do teclado para manter informações sensíveis fora do reconhecimento de fala.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: error == null
                              ? null
                              : Theme.of(context).colorScheme.error,
                        ),
                  ),
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
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving || controller.text.trim().isEmpty
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setDialogState(() => saving = true);
                      await _stopVoiceAndWaitForResult();
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext, true);
                    },
              child: Text(saving ? 'Finalizando fala…' : 'Salvar registro'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      await _speech.cancel();
    }
    if (result == true && controller.text.trim().isNotEmpty) {
      final intent = classifyVoiceIntent(controller.text);
      final entry = VoiceEntry(controller.text.trim(), category ?? intent.category);
      await widget.onVoiceEntryCreated(entry, intent);
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
    _speech.cancel();
    _listening.dispose();
    _voiceError.dispose();
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
