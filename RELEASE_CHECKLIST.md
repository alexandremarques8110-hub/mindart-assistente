# MindArt — gate de lançamento pessoal e comercial

## Entrega atual da branch (não publicada)
- Cache offline separado pelo UID do usuário autenticado.
- Dados antigos sem conta exigem consentimento explícito antes da importação.
- Backup manual do conteúdo do app no menu superior: `Copiar backup`.
- Restauração de backup JSON versão 1, com verificação de todos os modelos.
- Testes de serialização e pipeline de CI: `flutter analyze`, `flutter test`, `flutter build web`.

## Como testar antes de fazer merge
1. Conferir a execução **MindArt quality** na aba GitHub Actions. Não mesclar caso falhe.
2. Validar login no iPhone e desktop, criação/edição/exclusão de tarefas, dívidas, despesas e compromissos.
3. Testar duas contas diferentes no mesmo navegador. A segunda nunca deve enxergar dados locais da primeira.
4. Exportar backup, guardar em arquivo seguro, alterar um registro e restaurar; conferir todos os dados.
5. Criar registro offline, reconectar e verificar que foi enviado à mesma conta; repetir após logout/login.
6. Verificar no painel Supabase as regras RLS para `mindart_user_data`.
7. Compilar com `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` e publicar `build/web` em `docs` somente após testes. Não usar `service_role` em código do cliente.
8. Testar no Safari do iPhone, instalação por Compartilhar → Adicionar à Tela de Início e inicialização no ícone.

## Notificações push (código na branch; ativação pendente)
- [x] Service worker e ponte navegador/Flutter, com ativação e desativação pelo menu.
- [x] Assinaturas e lembretes em tabelas isoladas por usuário, com RLS.
- [x] Função Edge para envio via VAPID e processamento por cron com segredo.
- [ ] Executar o SQL revisado, configurar e implantar função e agendamento Supabase.
- [ ] Gerar VAPID, compilar o Flutter com chaves públicas e publicar os arquivos web.
- [ ] Testar no iPhone permissão, recebimento em segundo plano, abertura e revogação.
- [ ] Revisar confiabilidade do cron e observabilidade de envios antes de vender.
Veja PUSH_SETUP.md. Não incluir segredo VAPID, credenciais administrativas ou dados financeiros nas notificações.

## Exigências para comercialização
- Separar ambientes desenvolvimento / homologação / produção e revisar tenant isolation.
- Política de privacidade, termos, exclusão/exportação de dados e adequação à LGPD.
- Modelo de assinatura e bloqueio de funcionalidades definidos e aplicados no servidor.
- Backups automatizados, recuperação, observabilidade, limites de custo e proteção contra abuso.
- Testes E2E em vários navegadores e iPhone, métricas de disponibilidade e política de suporte.
- Revisão de licença e dependências antes da distribuição comercial.

A implantação já existente em `main` permanece inalterada até o merge e um novo build da pasta `docs`.
