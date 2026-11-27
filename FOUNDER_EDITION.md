# MindArt 000 — Founder Edition

## Escopo entregue na branch

- Identidade preto, dourado e branco no tema claro/escuro, ícone PWA e metadados do app.
- **MindArt Voice:** captura de fala iniciada pelo usuário por até 60 segundos, transcrição editável, classificação heurística sugerida (Saúde, Finanças, Ideia, Tarefa ou Nota), lista de registros e exclusão individual.
- Ajuste do fluxo de voz: seleção do locale português disponível no aparelho, pausas de até 8 segundos, preservação do texto ao retomar uma sessão interrompida e espera pelo resultado final antes de salvar.
- **MindArt One Touch:** botões de ação rápida para tarefa, gasto, compromisso e abertura do Voice.
- **MindArt Academy:** quatro microaulas agrupadas em três trilhas, quiz por aula e progresso persistido.
- **MindArt Rewards:** MindPoints derivados das aulas e quizzes concluídos; conquistas simbólicas, sem compras, sequências, punição por pausa ou notificações.
- **MindArt Saúde:** registros editáveis para alimentação, medicamentos, consultas e procedimentos, com data/hora e observações.
- Restauração de dados atômica para snapshots recebidos; escritas em nuvem serializadas e agrupadas para reduzir conflitos entre salvamentos rápidos.
- Permissões do microfone justificadas em iOS e Android; consentimento de privacidade antes da primeira sessão de fala.
- Testes de serialização dos modelos Voice e Saúde.

## Dados, segurança e compatibilidade

As novas listas são campos opcionais no payload existente de `mindart_user_data`. O RLS por `auth.uid()` e o isolamento por usuário continuam sendo os controles Supabase; esta alteração não cria tabelas, políticas nem migrações. Campos ausentes em registros e backups antigos são lidos como vazios, e os seis conjuntos de dados anteriores continuam no mesmo snapshot. Escritas rápidas feitas no mesmo aparelho agora são agrupadas e serializadas. Edições simultâneas em vários aparelhos ainda dependem do comportamento Realtime existente e podem exigir que o Usuário 000 escolha a cópia correta.

Os registros continuam armazenados no cache local existente do app e, quando a conta está configurada, na linha Supabase do próprio usuário. O cache local usa `SharedPreferences`, que não fornece criptografia em repouso. Os detalhes de Saúde são dados pessoais: use somente em dispositivo e conta protegidos. Nenhum conteúdo de saúde é enviado nas notificações do app.

A prévia web de validação está em uma rota separada, mas usa o projeto Supabase de produção existente. A tela de entrada foi verificada; após entrar, qualquer registro criado pelo Usuário 000 será persistido na conta real e sincronizado como de costume. A URL deixa a tela de login publicamente carregável; o acesso aos dados continua sob Supabase Auth e RLS. Nenhum registro de teste foi inserido ou removido durante esta publicação.

O reconhecimento de voz pode usar os serviços de fala do dispositivo/navegador e não deve receber senhas, dados financeiros ou informações de saúde. A permissão é pedida apenas depois da confirmação da pessoa. O plugin funciona em iOS/Android e navegadores compatíveis; nem todo navegador oferece Web Speech. O sistema operacional ou o navegador ainda pode encerrar a escuta antes do limite solicitado. A digitação normal e a ditagem do teclado continuam disponíveis como alternativa.

MindPoints não têm valor monetário e não podem ser comprados. Não há contador de sequência nem perda de pontos por inatividade, seguindo a diretriz de facilitar a vida sem incentivar dependência digital.

## Validação

- Branch de preservação: `backup/main-2026-11-27`.
- Branch de desenvolvimento: `feature/mindart-000-founder-edition`.
- Comandos do workflow: `flutter pub get`, `flutter analyze`, `flutter test`, checagem dos scripts JavaScript e `flutter build web --release --base-href /mindart-assistente/preview/`.
- Estado dos testes e do build: aprovado no workflow `MindArt quality` #47 (commit `2017a74`): análise estática, testes unitários (incluindo retomada/união de segmentos Voice), JavaScript, build PWA e verificação dos assets. O job de verificação da Edge Function Supabase também passou. A prévia foi recompilada e publicada.
- Link de validação do Usuário 000: https://alexandremarques8110-hub.github.io/mindart-assistente/preview/ (tela de entrada verificada; autenticação necessária para abrir o app).
- PR para revisão do Usuário 000: https://github.com/alexandremarques8110-hub/mindart-assistente/pull/4.
- A página existente na raiz permaneceu no lugar. O workflow acrescentou apenas o build compilado em `docs/preview`; o código da aplicação continua na branch de desenvolvimento, sem merge no `main`.

## Próximas etapas para uso

1. Validar o fluxo Voice no Safari/iPhone e num navegador Chromium com reconhecimento de fala.
2. Revisar os novos campos com dados de teste e confirmar a sincronização em dois dispositivos da conta Usuário 000.
3. Após validar, planejar o fluxo de release aprovado pelo idealizador. A versão iOS nativa da App Store requer assinatura e compilação num Mac com Xcode.

## Ajuste de roteamento do MindArt Voice — 27/11/2026

- A classificação agora transforma falas claras em registros funcionais: tarefas vão para as prioridades, gastos com valor explícito para os lançamentos de Finanças, registros de saúde para MindArt Saúde e falas com data/hora para a agenda.
- Uma fala classificada como Finanças sem valor aparece como anotação na área de Finanças e em “Registros recentes”, sem alterar totais nem inventar um valor.
- O “Meu dia” passou a mostrar as três falas recentes. Tarefas ditadas recebem prioridade; quando a pessoa diz o horário, a agenda recebe o compromisso e usa esse horário para o lembrete. O aviso depende das notificações estarem ativadas no dispositivo.
- O agendamento existente foi otimizado em lote. A persistência local acontece primeiro e a sincronização de rede continua em segundo plano; as leituras do cache local são paralelas.
- Testes novos cobrem academia como tarefa, almoço com valor declarado, finanças sem valor e datas/horários falados, incluindo dia da semana.
