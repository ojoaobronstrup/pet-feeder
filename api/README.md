# API do protótipo

Requer .NET 10 e PostgreSQL. Configure `api/.env` a partir de `api/.env.example` com `DB_NAME`, `DB_USER` e `DB_PASSWORD`; `DB_HOST` e `DB_PORT` são opcionais e usam `localhost` e `5432` por padrão. Para iniciar um banco local com as mesmas credenciais, execute na raiz do projeto:

```powershell
docker compose --env-file api/.env up -d
```

O serviço expõe a porta somente em `127.0.0.1`. O volume `postgres_data` mantém os dados entre reinicializações; `docker compose down -v` apaga o volume e todo o histórico. Alterar usuário, senha ou banco no `.env` depois de inicializado o volume não altera as credenciais existentes no PostgreSQL.

Para senhas com `$`, use aspas simples no arquivo (por exemplo, `DB_PASSWORD='senha$local'`) para evitar interpolação pelo Docker Compose.

Configure o ID de cliente Google usado pelo aplicativo, o e-mail Google autorizado e uma chave aleatória para o ESP32. A API carrega `api/.env` independentemente do diretório de execução e cria o esquema na inicialização. Variáveis de ambiente `DB_*` têm prioridade sobre o arquivo; uma connection string `ConnectionStrings__Postgres` configurada tem prioridade sobre ambas. O arquivo aceita valores simples ou entre aspas, sem expansão de variáveis. Exemplo no PowerShell:

```powershell
$env:Google__ClientId = 'CLIENT_ID.apps.googleusercontent.com'
$env:Google__AllowedEmail = 'seu-email@gmail.com'
$env:Device__ApiKey = 'chave-longa-aleatoria'
dotnet run --project api --launch-profile http
```

A API valida cada ID token com o Google; requer acesso à internet. Use o mesmo client ID no aplicativo e a mesma chave no firmware. O dispositivo acessa a API pelo IP do computador na rede local, porta 5087. HTTP e chave compartilhada servem somente à rede de teste: não exponha esta configuração à internet. Não há isolamento de múltiplas contas/dispositivos nesta etapa.

O ESP32 consulta `POST /api/device/poll` com a chave. A aplicação usa o ID token Bearer em `/api/feeder`, `/api/feeder/power`, `POST /api/feeder/feed`, `/api/feeder/schedules` e `GET /api/feeder/history`. O histórico aceita filtros `from`, `to`, `origin` e `status`. Agendamentos são pontuais e registrados em UTC no PostgreSQL. Na primeira inicialização com banco vazio, dados existentes em `api/prototype-data.json` (ou no caminho configurado em `Prototype__DataFile`) são importados sem alterar o arquivo original. Os agendamentos existentes são preservados, mas o histórico anterior não é fabricado, pois o arquivo não registra as datas das transições. A ação manual de alimentação solicita um pulso de 10 segundos. No horário, um pulso de 10 segundos é solicitado se o dispositivo estiver online e desligado; caso contrário, o evento é marcado como perdido. O envio só é marcado como executado após confirmação no heartbeat. A API precisa estar em execução; agendamentos não rodam no ESP32 sem ela.
