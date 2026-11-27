# MindArt 000 — Founder Edition

Aplicativo pessoal para organizar tarefas, projetos, finanças, saúde e rotina, priorizando o uso no iPhone e no computador. A entrega atual é uma web app instalável pela tela inicial do Safari; uma versão nativa para App Store depende de assinatura e compilação em macOS/Xcode.

## Escopo do MVP

- **Hoje:** resumo das tarefas, próximos prazos, rotina e visão financeira.
- **Projetos:** ideias, tarefas, prazos, status e prioridade.
- **Finanças:** lançamentos de gastos, dívidas e metas de economia.
- **Rotina:** compromissos e hábitos com visão diária e semanal.
- **Privacidade:** conta individual, sincronização na nuvem e políticas de acesso por usuário via Supabase.
- **Custo:** priorizar ferramentas gratuitas e evitar serviços pagos obrigatórios.
- **MindArt Voice:** captura manual de até 30 segundos, classificação sugerida e alternativa por teclado.
- **MindArt One Touch:** atalhos para tarefas, gastos, compromissos e MindArt Voice.
- **MindArt Academy:** microaulas curtas com quizzes e progresso salvo.
- **MindArt Rewards:** MindPoints e marcos simbólicos sem compra, sequência diária ou perda de pontos.
- **MindArt Saúde:** registros pessoais de alimentação, horários, medicamentos, consultas e procedimentos.

## Plano de entrega

1. Criar o esqueleto Flutter e preparar a web app instalável para iPhone.
2. Entregar navegação e telas MVP com dados locais.
3. Persistir dados localmente e oferecer edição e remoção dos registros.
4. Integrar autenticação, sincronização e segurança por usuário no Supabase.
5. Publicar a versão web instalável no iPhone; preparar iOS nativo quando houver ambiente Apple.

## Estado atual

O espelho original não continha código-fonte nem os anexos mencionados na conversa. Foi criado um projeto Flutter com plataformas web, Android e iOS, além de uma primeira interface navegável. O painel e as áreas de projetos, finanças e rotina já aceitam tarefas e gastos durante a sessão.

Tarefas, projetos, ideias, gastos, dívidas, metas e compromissos podem ser editados e apagados dentro do app. As exclusões pedem confirmação. No modo local, os registros permanecem no armazenamento do aparelho ou navegador.

O código já inclui o fluxo opcional de conta Supabase, migração dos dados locais no primeiro acesso e sincronização entre aparelhos com proteção de acesso por usuário. Para habilitá-lo, crie e configure um projeto Supabase conforme [SUPABASE_SETUP.md](SUPABASE_SETUP.md), depois gere a compilação web com os dados públicos do projeto. Não inclua uma chave `service_role` no app.

**Entrega priorizada para iPhone:** a compilação web de produção fica em `build/web` e é publicada pelo GitHub Pages a partir de `docs/`. A página e o manifesto têm nome e ícone próprios. O app inclui tarefas com prazos, projetos e ideias com descrição, registro de gastos, acompanhamento de dívidas e metas de economia, além de compromissos com data e horário. A versão publicada fica em modo local até a configuração do projeto Supabase e da chave publicável, conforme [SUPABASE_SETUP.md](SUPABASE_SETUP.md). Para instalar, abra o link no Safari, toque em Compartilhar e escolha **Adicionar à Tela de Início**.

O app precisa de internet para carregar; o armazenamento local permite continuar registrando dados temporariamente sem conexão, e a sincronização volta quando a conexão retorna e um registro é salvo. Esta entrega é uma web app e não aparece na App Store. Uma versão nativa para a App Store requer acesso a macOS e Xcode.

Veja [BACKLOG.md](BACKLOG.md) para as etapas detalhadas.

## MindArt 000 — Founder Edition

A identidade da interface usa preto, dourado e branco. Os módulos novos são aditivos ao snapshot JSON já protegido por RLS e sincronizado por conta; os backups antigos continuam válidos. Nenhuma tabela ou registro Supabase existente foi removido ou alterado. Para detalhes técnicos, privacidade e validação, consulte [FOUNDER_EDITION.md](FOUNDER_EDITION.md).

O Voice só solicita acesso ao reconhecimento de fala após a pessoa tocar em **Continuar com voz**. A fala pode ser processada pelo serviço do aparelho/navegador; por isso o app recomenda não ditar informações financeiras, de saúde ou senhas. O reconhecimento depende do navegador/dispositivo. Se ele não estiver disponível, use a ditagem do teclado ou digite o registro.
