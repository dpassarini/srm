# SRM Credit Engine 🪙

Uma plataforma corporativa moderna e de alta fidelidade para **simulação e antecipação de lotes de recebíveis multimoeda** (BRL / USD). O sistema calcula o valor presente líquido (VPL) de recebíveis (como duplicatas e cheques) utilizando fórmulas de deságio composto ajustadas por prazo (dias corridos), taxas básicas e spreads operacionais cadastrados por tipo de recebível.

O projeto dispõe de um backend robusto em **Ruby on Rails 8** rodando em modo API, um banco de dados **Postgres 18**, cache em **Redis**, e um frontend reativo de alta fidelidade desenvolvido em **React (Vite + TypeScript)** com estilo premium (Dark Mode & Glassmorphism) usando **Tailwind CSS v4**.

---

## 🚀 Requisito Obrigatório: Docker

> [!IMPORTANT]  
> **O único requisito do sistema é ter o Docker e o Docker Compose instalados.**  
> Toda a infraestrutura, incluindo bancos de dados, cache, dependências de pacotes (Ruby e Node), compilação de assets e servidores de desenvolvimento, é orquestrada e executada de forma isolada em containers Docker.

---

## 🛠️ Como Rodar a Aplicação

Siga os passos abaixo para subir todo o ambiente de desenvolvimento:

### 1. Inicializar os Containers
Na raiz do projeto (onde está localizado o arquivo `docker-compose.yml`), execute o comando abaixo para construir as imagens e iniciar os serviços em segundo plano:

```bash
docker compose up --build -d
```

Este comando inicializará os seguintes serviços:
- **db** (PostgreSQL 18.4 na porta `5432`)
- **redis** (Redis 7 na porta `6379`)
- **web** (API Ruby on Rails 8 na porta `3000`)
- **frontend** (SPA React 19 na porta `5173`)

### 2. Inicialização Automática e Banco de Dados (Seeds)
Durante o primeiro boot do container de backend (`web`), o script de entrada roda automaticamente os seguintes passos:
1. `bundle install` para garantir a instalação de dependências.
2. `rails db:prepare` que cria as bases de desenvolvimento e teste, roda as migrações de banco e carrega os dados iniciais (**seeds**).

Os **seeds** incluem:
- **Moedas**: Real Brasileiro (`BRL`, R$) e Dólar Americano (`USD`, $).
- **Taxas de Câmbio**: Cotação inicial BRL ↔ USD para a data atual.
- **Tipos de Recebíveis & Spreads**:
  - *Duplicata Mercantil* (Spread base: 1.50% a.m.)
  - *Cheque Pré-datado* (Spread base: 2.50% a.m.)

### 3. Acessar as Aplicações
Após os containers estarem saudáveis (`status: healthy` ou `Up`), acesse nos navegadores:

- **Painel do Operador (Frontend)**: [http://localhost:5173](http://localhost:5173)
- **API Playground/Health Check (Backend)**: [http://localhost:3000](http://localhost:3000)

---

## 🧪 Como Rodar a Suíte de Testes

Os testes da aplicação backend foram construídos utilizando o **RSpec** para garantir alta confiabilidade das regras financeiras e endpoints da API. 

Para executar a suíte completa de testes no ambiente isolado do Docker, execute os comandos a seguir:

### 1. Preparar o Banco de Testes (Primeira Execução)
Caso precise redefinir ou preparar a base de dados de testes pela primeira vez:

```bash
docker compose exec -e RAILS_ENV=test web bundle exec rails db:test:prepare
```

### 2. Rodar a Suíte RSpec
Execute todos os testes unitários e de integração com o comando:

```bash
docker compose exec -e RAILS_ENV=test web bundle exec rspec
```

*Nota: É necessário passar explicitamente a variável `-e RAILS_ENV=test` para que o RSpec execute usando as configurações e base de testes isolada de forma limpa.*

### 🌐 Integração Contínua (CI)
O projeto conta com um workflow do GitHub Actions configurado em [ci.yml](file:///home/dpassarini/Prototipos/srm/.github/workflows/ci.yml) que executa automaticamente as seguintes verificações em paralelo a cada push ou pull request para as branches `main`, `master` e `development`:

1. **RuboCop Lint**: Validação estática de estilo e padronização do código Ruby.
2. **RSpec Tests**: Execução de toda a suíte de testes unitários e de integração, utilizando serviços ativos do PostgreSQL 18 e Redis 7 no runner do GitHub.

---



## 📁 Estrutura de Diretórios e Documentação

- [/credit_engine](file:///home/dpassarini/Prototipos/srm/credit_engine) — Código-fonte do backend em Ruby on Rails 8.1.
- [/frontend](file:///home/dpassarini/Prototipos/srm/frontend) — Código-fonte do frontend em React/TypeScript com Tailwind CSS v4.
- [docker-compose.yml](file:///home/dpassarini/Prototipos/srm/docker-compose.yml) — Arquivo de orquestração do ambiente.
- [modelagem.md](file:///home/dpassarini/Prototipos/srm/modelagem.md) — Diagrama e documentação detalhada da modelagem do banco de dados (Entidade-Relacionamento em Mermaid).
- [AI_USAGE.md](file:///home/dpassarini/Prototipos/srm/AI_USAGE.md) — Relatório de uso de Inteligência Artificial como co-piloto de desenvolvimento, detalhando decisões de engenharia e mitigações aplicadas.
