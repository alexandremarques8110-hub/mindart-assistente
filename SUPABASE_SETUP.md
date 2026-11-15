# Conectar o MindArt ao Supabase

O repositório contém o fluxo de conta, a migração do armazenamento local para a nuvem, a sincronização de alterações e a tabela protegida por usuário. Para ativar a nuvem na versão publicada:

1. Crie um projeto no [Supabase](https://supabase.com/dashboard).
2. No projeto, abra **SQL Editor** e execute o conteúdo de `supabase_schema.sql`.
3. Em **Project Settings → API**, copie o **Project URL** e a **publishable key**. Não use nem compartilhe a chave `service_role`/secret no app.
4. Em **Authentication → URL Configuration**, defina como Site URL:
   `https://alexandremarques8110-hub.github.io/mindart-assistente/`
5. Gere a versão web com os valores do seu próprio projeto:

   ```powershell
   $env:FLUTTER_ROOT='C:\Src\flutter'
   & 'C:\Src\flutter\bin\cache\dart-sdk\bin\dart.exe' pub get
   & 'C:\Src\flutter\bin\flutter.bat' build web --release --base-href /mindart-assistente/ --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL
   ```

6. Copie o conteúdo de `build/web` para `docs/` e envie essa atualização para a branch `main`. O GitHub Pages publica a pasta `docs`.

Na primeira conta, se ainda não existir uma cópia na nuvem, o app envia os dados locais atuais para a conta. Se já houver dados na nuvem, eles são carregados e passam a ser a cópia principal. Cada conta só pode acessar seus próprios dados, conforme a política RLS no SQL.

O login usa e-mail e senha. Se a confirmação de e-mail estiver ativa no Supabase, a pessoa precisa confirmar o endereço antes de entrar. O fluxo de recuperação de senha também está incluído.
