# MindArt 000 — Founder Edition

## Escopo entregue na branch

- Identidade preto, dourado e branco no tema claro/escuro, ícone PWA e metadados do app.
- **MindArt Voice:** captura de fala iniciada pelo usuário, limite curto de 30 segundos, transcrição editável, classificação heurística sugerida (Saúde, Finanças, Ideia, Tarefa ou Nota), lista de registros e exclusão individual.
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

O reconhecimento de voz pode usar os serviços de fala do dispositivo/navegador e não deve receber senhas, dados financeiros ou informações de saúde. A permissão é pedida apenas depois da confirmação da pessoa. O plugin funciona em iOS/Android e navegadores compatíveis; nem todo navegador oferece Web Speech. A digitação normal e a ditagem do teclado continuam disponíveis como alternativa.

MindPoints não têm valor monetário e não podem ser comprados. Não há contador de sequência nem perda de pontos por inatividade, seguindo a diretriz de facilitar a vida sem incentivar dependência digital.

## Validação

- Branch de preservação: `backup/main-2026-11-27`.
- Branch de desenvolvimento: `feature/mindart-000-founder-edition`.
- Comandos do workflow: `flutter pub get`, `flutter analyze`, `flutter test` e `flutter build web --release --base-href /mindart-assistente/`.
- Estado dos testes e do build: pendente da execução do workflow de CI nesta branch.
- A página de produção existente não foi substituída por esta alteração. A prévia do código e o resultado do CI ficam no pull request de validação.

## Próximas etapas para uso

1. Validar o fluxo Voice no Safari/iPhone e num navegador Chromium com reconhecimento de fala.
2. Revisar os novos campos com dados de teste e confirmar a sincronização em dois dispositivos da conta Usuário 000.
3. Depois da validação, publicar a web app de teste pelo fluxo autorizado de release. A versão iOS da App Store requer assinatura e compilação num Mac com Xcode.
