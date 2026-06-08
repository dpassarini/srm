# Documentação de Uso de IA (AI as a Co-Pilot)

Este documento descreve como a inteligência artificial foi utilizada como co-piloto no desenvolvimento da plataforma **SRM Credit Engine**, relatando prompts, decisões técnicas mitigadas e análise crítica de produtividade.

---

## 1. Prompts Estratégicos Utilizados

*   **Scaffolding e Setup Inicial:**
    *   *Prompt:* "Gere comandos de migrations e models do Rails para uma plataforma de crédito multimoeda que registre moedas, taxas cambiais diárias, tipos de recebíveis ( spreads distintos), operações consolidadas e recebíveis individuais."
*   **Design Pattern (Strategy):**
    *   *Prompt:* "Como implementar o padrão de projeto Strategy em Ruby on Rails de forma que possamos calcular o deságio composto de recebíveis com spreads cadastrados de forma flexível no banco de dados e resolver taxas cross-currency de forma resiliente?"
*   **Refatoração de Configurações do Docker:**
    *   *Prompt:* "Corrija o erro 'Error: in 18+, these Docker images are configured to store database data in a format which is compatible with pg_ctlcluster' no PostgreSQL 18 ao usar o Docker Compose."
*   **Processamento Assíncrono com Sidekiq:**
    *   *Prompt:* "Configure o Sidekiq no Docker Compose junto com o Rails para que a liquidação de lotes de recebíveis aconteça de forma assíncrona, definindo os serviços web e worker de forma isolada."

---

## 2. Mitigações e Correção de Alucinações

Durante a codificação, o co-piloto cometeu alguns deslizes importantes que exigiram intervenção técnica direta:

1.  **Divergência de Atributos Calculadora vs ActiveRecord:**
    *   *Problema:* A IA recomendou retornar chaves como `net_value_payment` e omitiu o `identifier` no retorno do módulo `PricingEngine::Calculator`. Ao tentar instanciar o model `Receivable` com o hash completo, a aplicação disparava `ActiveModel::UnknownAttributeError` e falhava a validação de presença do `identifier`.
    *   *Correção:* Adicionada a propagação do `identifier` e limpeza das chaves de exibição do hash (usando `.except(:net_value_original)`) antes de enviar ao ActiveRecord.
2.  **Ambiente de Execução do RSpec no Docker Compose:**
    *   *Problema:* Ao executar testes do RSpec dentro do container, as requisições de request specs falhavam com `403 Forbidden` devido a `Blocked Host: www.example.com`.
    *   *Correção:* O container do Docker Compose roda sob `RAILS_ENV=development` por padrão. Isso fez com que o RSpec herdasse o ambiente de desenvolvimento onde o middleware de `HostAuthorization` está ativo. Foi corrigido limpando e permitindo o host no arquivo `config/environments/test.rb` e executando o RSpec com o prefixo de ambiente explícito: `env RAILS_ENV=test bundle exec rspec`.
3.  **Gotcha de Autosave de Associações do ActiveRecord em Transações/Savepoints:**
    *   *Problema:* Ao rodar os testes da liquidação assíncrona, se um recebível inválido causasse a falha da liquidação e o rollback da transação (SAVEPOINT), a cache em memória da associação `operation.receivables` continuava populada com os recebíveis válidos processados antes do erro. Ao executar `operation.update!(status: 'failed')` no bloco de captura de erros, o Rails tentava salvar novamente os recebíveis em memória, reinserindo-os no banco de dados.
    *   *Correção:* Atualização do tratamento de erro no job para utilizar `operation.update_column(:status, "failed")`, que realiza uma alteração SQL direta no banco de dados, evitando callbacks de autosave do ActiveRecord.
4.  **Integração de Fila no Ambiente de Testes:**
    *   *Problema:* Configurar o Active Job globalmente para usar o Sidekiq fez com que os testes de integração do RSpec tentassem se conectar ao Redis real para executar os jobs, quebrando os blocos de teste com `perform_enqueued_jobs`.
    *   *Correção:* Definição explícita de `config.active_job.queue_adapter = :test` em `config/environments/test.rb`.


---

## 3. Análise Crítica

*   **Onde a IA economizou tempo?**
    *   Forte aceleração na criação das cascas físicas do HTML e componentes em Tailwind v4 + React (Vite). Mapear classes de CSS com design Glassmorphism e Dark Mode direto no código de React economizou várias horas de escrita manual.
    *   Aceleração no mapeamento de migrations e tabelas normalizadas do ActiveRecord.
*   **Onde a IA atrapalhou ou exigiu cuidado extra?**
    *   Problemas de consistência nas chaves de hashes de serviços acopladas ao banco de dados.
    *   Erros em relação ao ciclo de vida e concorrência de inicialização do Docker/Postgres (como o erro de pasta de dados da versão 18+ do Postgres e concorrência de banco no rails).
    *   A IA tendeu a gerar testes em frameworks mistos, exigindo intervenção explícita para focar apenas em RSpec idiomático e limpo.
