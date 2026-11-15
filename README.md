# MindArt — assistente pessoal

Aplicativo pessoal para organizar projetos, finanças e rotina, priorizando o uso no iPhone. A primeira entrega será uma web app instalável pela tela inicial do Safari; uma versão nativa para App Store pode vir depois.

## Escopo do MVP

- **Hoje:** resumo das tarefas, próximos prazos, rotina e visão financeira.
- **Projetos:** ideias, tarefas, prazos, status e prioridade.
- **Finanças:** lançamentos de gastos, dívidas e metas de economia.
- **Rotina:** compromissos e hábitos com visão diária e semanal.
- **Privacidade:** começar com dados locais; integrações e sincronização serão decididas depois.
- **Custo:** priorizar ferramentas gratuitas e evitar serviços pagos obrigatórios.

## Plano de entrega

1. Criar o esqueleto Flutter e preparar a web app instalável para iPhone.
2. Entregar navegação e telas MVP com dados locais.
3. Persistir dados no dispositivo e tratar estados vazios/erros.
4. Validar build web e Android; preparar iOS quando houver ambiente Apple.
5. Decidir autenticação, sincronização e publicação após o MVP estar utilizável.

## Estado atual

O espelho original não continha código-fonte nem os anexos mencionados na conversa. Foi criado um projeto Flutter com plataformas web, Android e iOS, além de uma primeira interface navegável. O painel e as áreas de projetos, finanças e rotina já aceitam tarefas e gastos durante a sessão.

Tarefas, gastos, dívidas, metas de economia e compromissos são gravados no armazenamento local do aparelho ou navegador. Tarefas podem ser editadas e receber prazo; pagamentos e aportes atualizam os saldos; compromissos têm data e horário próprios. Os dados não sincronizam entre dispositivos.

**Entrega priorizada para iPhone:** a compilação web de produção é gerada em `build/web` e empacotada em `MindArt-iphone-web.zip`. A página e o manifesto têm nome e ícone próprios. O app inclui tarefas com prazos, projetos e ideias com descrição, registro de gastos, acompanhamento de dívidas e metas de economia, além de compromissos com data e horário. Para instalar, os arquivos precisam ser publicados em um endereço HTTPS; então abra o link no Safari, toque em Compartilhar e escolha **Adicionar à Tela de Início**. Os dados ficam no navegador do iPhone e não sincronizam com outros aparelhos.

O app precisa de internet para carregar; ainda não foi preparado para uso offline. Esta entrega é uma web app e não aparece na App Store. Uma versão nativa para a App Store requer acesso a macOS e Xcode.

Veja [BACKLOG.md](BACKLOG.md) para as etapas detalhadas.
