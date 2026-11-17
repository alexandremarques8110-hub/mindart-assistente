# Ativação do Web Push do MindArt (iPhone e desktop)

**Status:** código pronto para integração, **não implantado** nesta branch. A publicação atual do GitHub Pages continuará sem push até compilar/publicar novamente com as chaves e implantar as peças Supabase.

## Requisitos
- iPhone com iOS 16.4+; o usuário deve instalar a PWA em **Safari → Compartilhar → Adicionar à Tela de Início** e abrir pelo ícone. A permissão exige um toque direto em **Ativar notificações** dentro do app.
- Supabase Auth e tabela `mindart_user_data` já operacionais.
- Flutter 3.44.6, CLI Supabase e Node instalados no ambiente de desenvolvimento.
- Uma agenda do app com compromissos com data e horário.

## 1. Banco de dados
No Supabase do MindArt, faça backup e **revise** o SQL `supabase/mindart_notifications.sql` antes de executá-lo no SQL Editor. Ele cria:
- `mindart_push_subscriptions`: uma inscrição de push por dispositivo; RLS por usuário.
- `mindart_reminders`: lembretes de compromissos; RLS por usuário.
- `mindart_claim_reminders()`: função disponível **somente para service_role**, para evitar envios duplicados quando cron concorre.

Não altere tabelas do PDV Mercado Progresso.

## 2. Chaves VAPID
Em seu computador, gere um par com `npx web-push generate-vapid-keys`.
- **VAPID PUBLIC KEY**: vai na compilação Flutter (dado público).
- **VAPID PRIVATE KEY**: vai apenas no Supabase Edge Functions Secrets, nunca no GitHub ou no app.

Configurar no ambiente do servidor:
- `MINDART_VAPID_PUBLIC_KEY`: mesma chave pública usada no build Flutter.
- `MINDART_VAPID_PRIVATE_KEY`: chave privada VAPID.
- `MINDART_VAPID_SUBJECT`: ex. `mailto:suporte@seu-dominio.com` (use um e-mail real).
- `MINDART_CRON_SECRET`: cadeia aleatória e longa para autenticar a execução agendada.

Os segredos nativos `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são injetados pelo Supabase no backend. Confirme no ambiente. Nunca copie a service-role key para o app.

## 3. Implantar a função segura
```sh
supabase login
supabase link --project-ref uexogtqyobfuuzserqpp
supabase functions deploy mindart-dispatch-reminders --no-verify-jwt
```
Use `supabase secrets set` ou o Dashboard para cadastrar os segredos acima sem incluí-los em comandos compartilhados, prints ou repositório.

Configure um Cron Job de **1 em 1 minuto** no Supabase (com `pg_cron` + `pg_net` ou opção de agendamento na interface) para enviar um `POST` à URL:
```
https://uexogtqyobfuuzserqpp.supabase.co/functions/v1/mindart-dispatch-reminders
```
Com header `x-mindart-cron-secret` igual ao segredo definido no servidor. Guarde esse segredo em Supabase Vault/ambiente protegido, não dentro de SQL em texto puro. A função rejeita chamadas sem esse header.

## 4. Build do aplicativo e publicação
```powershell
flutter pub get
flutter test
flutter analyze
flutter build web --release --base-href /mindart-assistente/ `
  --dart-define=SUPABASE_URL=https://uexogtqyobfuuzserqpp.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL `
  --dart-define=VAPID_PUBLIC_KEY=SUA_CHAVE_PUBLICA_VAPID
```
Confirme que `build/web/mindart-push-sw.js` e `build/web/notifications_bridge.js` existem. Copie **todos** os arquivos de `build/web` para `docs/` e faça commit em `main`. O GitHub Pages publica `docs`.

## 5. Teste no iPhone
1. Abra o site no Safari, instale a PWA e abra pelo ícone MindArt.
2. Entre na conta Supabase correta.
3. No menu de três pontos do app, selecione **Ativar notificações**; autorize.
4. Crie um compromisso com horário 20 minutos no futuro. O agendamento terá lembrete 15 minutos antes, portanto o aviso deve chegar em aproximadamente 5 minutos.
5. Verifique recebimento com app fechado, toque para abrir e o estado da permissão em Ajustes → Notificações → MindArt.
6. Teste o mesmo usuário em outro navegador; testando duas contas, não compartilhe nenhuma inscrição de push.

**Limitações conhecidas:** eventos que já passaram não são notificados; o app só cria lembretes para compromissos futuros. O envio depende de conexão e da execução do Cron. A implementação é preparada para teste, não há confirmação de entrega real até concluir todas essas etapas.

## Futuras melhorias
Preferências do usuário, horários silenciosos, cancelamento de inscrição, tela de histórico, auditoria/observabilidade e gestão de limites para assinaturas comerciais.
