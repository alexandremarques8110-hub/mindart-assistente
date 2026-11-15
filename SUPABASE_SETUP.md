# Conectar o MindArt ao Supabase

O MindArt usa uma tabela própria no projeto Supabase existente **mercado progresso**. A tabela `mindart_user_data` já foi criada com acesso separado por usuário; os dados e tabelas existentes do Mercado Progresso não foram alterados. Não crie outro projeto nem execute novamente o SQL já aplicado.

1. Em **Project Settings → API**, use o Project URL `https://uexogtqyobfuuzserqpp.supabase.co` e a **publishable key**. Não use nem compartilhe a chave `service_role`/secret no app.
2. Em **Authentication → URL Configuration**, mantenha a Site URL atual para preservar os outros apps e adicione aos Redirect URLs permitidos:
   `https://alexandremarques8110-hub.github.io/mindart-assistente/`
3. Gere a versão web com o Project URL e a chave publishable:

   ```powershell
   $env:FLUTTER_ROOT='C:\Src\flutter'
   & 'C:\Src\flutter\bin\cache\dart-sdk\bin\dart.exe' pub get
   & 'C:\Src\flutter\bin\flutter.bat' build web --release --base-href /mindart-assistente/ --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL
   ```

4. Copie o conteúdo de `build/web` para `docs/` e envie essa atualização para a branch `main`. O GitHub Pages publica a pasta `docs`.

Na primeira conta, se ainda não existir uma cópia na nuvem, o app envia os dados locais atuais para a conta. Se já houver dados na nuvem, eles são carregados e passam a ser a cópia principal. Cada conta só pode acessar seus próprios dados, conforme a política RLS no SQL.

O login usa e-mail e senha. Se a confirmação de e-mail estiver ativa no Supabase, a pessoa precisa confirmar o endereço antes de entrar. O fluxo de recuperação de senha também está incluído.
