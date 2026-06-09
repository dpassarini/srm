# Registro de Decisões de Arquitetura (ADR - Architecture Decision Records)

Este documento centraliza as decisões de arquitetura de software adotadas no desenvolvimento do **SRM Credit Engine**, justificando as escolhas de tecnologia, padrões de projeto e estratégias de escalabilidade financeira.

---

## 1. Escolha do Framework Backend: Ruby on Rails 8 (API Mode)

### Status
Aceito

### Contexto
O ecossistema financeiro demanda alta confiabilidade, segurança e integridade transacional. Ao mesmo tempo, o tempo de entrega (Time to Market) de um produto viável e testado é crucial. Precisávamos de um framework robusto de backend que oferecesse suporte de primeira classe a testes e bancos de dados relacionais.

### Decisão
Optou-se por utilizar o **Ruby on Rails 8** configurado em modo API (`--api`). 
As principais motivações incluem:
1. **Maturidade e Convenções (Convention over Configuration):** O Rails é extremamente maduro e adota convenções rígidas que aceleram a produtividade, reduzem a necessidade de tomadas de decisão triviais e evitam erros comuns de setup.
2. **Ecossistema Financeiro:** O ecossistema Ruby possui excelente tratamento numérico nativo (`BigDecimal`) e ORM robusto (`ActiveRecord`), sendo muito utilizado e testado em diversas fintechs renomadas (ex: Nubank, Stripe).
3. **Desenvolvimento Apoiado por IA (Co-pilot Friendly):** Devido ao seu caráter altamente opinativo, estrutura previsível e documentação abundante, o Rails é uma tecnologia ideal para desenvolvimento colaborativo auxiliado por ferramentas de IA, pois a IA alucina menos e segue padrões claros de código.
4. **Modo API Nativo:** Remove bibliotecas desnecessárias para renderização de telas no backend (Action View, Asset Pipeline legado), resultando em um serviço leve, rápido e focado puramente em requisições RESTful JSON.

### Consequências
*   **Positivas:** Inicialização extremamente ágil do backend; facilidade de onboarding no código; suíte de testes idiomática e robusta com RSpec; desacoplamento total em relação ao frontend React.
*   **Negativas:** Menor flexibilidade arquitetural no fluxo MVC padrão, porém mitigada pela organização de regras complexas em Service Objects.

---

## 2. Precisão Monetária e Numérica

### Status
Aceito

### Contexto
Sistemas financeiros não podem tolerar imprecisões no cálculo de valores decimais. O uso de representações numéricas baseadas em binário (como o tipo `Float` ou `Double`) apresenta erros acumulativos de arredondamento inerentes à representação em ponto flutuante.

### Decisão
1. **No Backend (Ruby):** Todos os cálculos matemáticos do motor de precificação e conversões de moedas utilizam estritamente a classe `BigDecimal` em vez de floats.
2. **No Banco de Dados (Postgres):** Todas as colunas financeiras foram modeladas com tipos decimais de precisão exata:
   - Valores de face, líquido e deságio: `decimal(18, 4)` (capacidade de representar até trilhões de unidades com 4 casas decimais de precisão centesimal).
   - Taxas cambiais e fatores multiplicativos: `decimal(18, 8)` (8 casas decimais para suportar conversões cambiais de alta fidelidade).

### Consequências
*   **Positivas:** Exatidão absoluta nas operações de simulação e liquidação, sem perda ou acúmulo de centavos. Aderência estrita a regras contábeis e auditorias financeiras.
*   **Negativas:** Pequeno custo computacional extra para manipulação de `BigDecimal` em comparação com floats nativos do processador, o que é irrelevante frente ao volume esperado e ao requisito de precisão.

---

## 3. Padrão de Projeto para Motor de Precificação: Strategy Pattern

### Status
Aceito

### Contexto
O SRM Credit Engine precisa dar suporte a múltiplos tipos de recebíveis (atualmente Duplicatas Mercantis e Cheques Pré-datados), cada um com políticas de spreads e regras de cálculo diferentes. Acoplar todas essas fórmulas dentro de um único controlador ou classe violaria o princípio de Responsabilidade Única (SRP) e Open/Closed (OCP) do SOLID.

### Decisão
Aplicou-se o padrão de projeto comportamental **Strategy**. Criou-se uma estrutura de classes de precificação sob o namespace `PricingEngine::Strategies`:
- `Base`: Define o contrato básico e realiza os cálculos de valor presente base.
- `Duplicata`: Estende a classe base implementando regras de spreads de 1.5% a.m.
- `Cheque`: Estende a classe base implementando regras de spreads de 2.5% a.m.

O `Calculator` resolve dinamicamente qual estratégia instanciar baseado no código do tipo de recebível cadastrado no banco de dados.

### Consequências
*   **Positivas:** Facilidade para expandir o portfólio de recebíveis do fundo (ex: adicionar Contratos ou Notas Promissórias requer apenas a criação de uma nova classe strategy). Testes unitários isolados para cada estratégia.
*   **Negativas:** Ligeiro aumento do número de arquivos no projeto, justificado pelo ganho substancial em manutenção e legibilidade.

---

## 4. Liquidação Assíncrona de Lotes (Sidekiq + Redis)

### Status
Aceito

### Contexto
A liquidação de um lote de recebíveis pode envolver múltiplos passos (cálculo de deságio de cada item, busca por taxas cambiais históricas, persistência ACID no banco de dados e disparo de notificações ou integrações). Executar essa operação de forma síncrona na mesma thread que atende a requisição HTTP do operador gera latência, bloqueia o servidor e pode levar a timeouts, especialmente em lotes grandes.

### Decisão
Adotou-se o modelo de **Liquidação Assíncrona**. 
1. Ao enviar um lote para liquidação, o controller do Rails cria a transação de cabeçalho no banco de dados com o status `pending` e responde imediatamente ao frontend (`201 Created`).
2. O processamento pesado de precificação de cada recebível do lote é empacotado e enfileirado no **Sidekiq** (apoiado pelo **Redis** como broker).
3. O Sidekiq processa o lote de recebíveis assincronamente em transações ACID isoladas. Se tudo for bem-sucedido, o status muda para `completed`. Se houver qualquer falha ou erro cambial, a transação sofre rollback total e a operação é marcada como `failed`.

### Consequências
*   **Positivas:** A API permanece leve, rápida e com baixíssimo tempo de resposta. As conexões do servidor de aplicação não ficam travadas. Facilidade no tratamento de concorrência e *race conditions* usando filas ordenadas.
*   **Negativas:** O operador não recebe o resultado instantaneamente na resposta do HTTP POST. Contudo, o frontend reativo do sistema monitora ou aguarda a conclusão da fila para atualizar as tabelas do usuário.

---

## 5. Relatórios Analíticos Assíncronos e Escalabilidade Futura (Data Lake)

### Status
Aceito

### Contexto
A geração de relatórios consolidados (extratos de liquidação) para fins de auditoria pode abranger milhões de registros acumulados ao longo do tempo. Executar queries analíticas pesadas (com agregações e agrupamentos) diretamente na base de dados de produção (PostgreSQL) degrada a performance do sistema principal (OLTP), prejudicando a operação de liquidação em tempo real.

### Decisão
Decidiu-se isolar a geração de extratos analíticos da thread principal de execução e projetar a arquitetura para suportar descentralização analítica futura:
1. **Processamento Assíncrono Local (Sidekiq):** O extrato não é montado em tempo real pelo controller. O usuário solicita o extrato informando os filtros, o backend cria um registro pendente e delega a compilação do arquivo CSV para um Worker assíncrono. O usuário faz o download do arquivo assim que o Sidekiq notifica sua conclusão.
2. **Desacoplamento para Data Lake / Banco Analítico (Escalabilidade Futura):** 
   - A arquitetura de geração de relatórios foi estruturada em duas camadas simples (Application e Persistence), sem necessidade de passar pelas regras complexas de negócio da precificação.
   - Isso permite que, no futuro, a leitura do histórico de operações para geração de extratos seja redirecionada para réplicas de leitura ou para um **Data Lake** (ex: AWS Athena, Snowflake ou ClickHouse). Os dados do banco transacional podem ser exportados via jobs ETL periódicos, poupando a base primária de qualquer estresse analítico.

### Consequências
*   **Positivas:** Proteção contra lentidão ou indisponibilidade da base de dados principal. Ausência de timeouts causados por downloads de arquivos volumosos. Arquitetura preparada desde o início para estratégias modernas de Big Data e Business Intelligence (BI).
*   **Negativas:** Pequena complexidade de experiência do usuário (UX), pois este precisa esperar o relatório ficar disponível para efetuar o download, mitigada pela fila rápida e interface amigável.
