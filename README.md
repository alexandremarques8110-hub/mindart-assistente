# MindArt — assistente pessoal

Aplicativo pessoal para organizar projetos, finanças e rotina, priorizando o uso no iPhone. A primeira entrega será uma web app instalável pela tela inicial do Safari; uma versão nativa para App Store pode vir depois.

## Escopo do MVP

- **Hoje:** resumo das tarefas, próximos prazos, rotina e visão financeira.
- **Projetos:** ideias, tarefas, prazos, status e prioridade.
- **Finanças:** lançamentos de gastos, dívidas e metas de economia.
- **Rotina:** compromissos e hábitos com visão diária e semanal.
- **Privacidade:** conta individual, sincronização na nuvem e políticas de acesso por usuário via Supabase.
- **Custo:** priorizar ferramentas gratuitas e evitar serviços pagos obrigatórios.

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
