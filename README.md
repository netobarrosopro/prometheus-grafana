# 📊 Stack de Monitoramento (Prometheus + Grafana) na AWS com Terraform

Este projeto provisiona uma stack de monitoramento completa e "pronta para produção" em uma única instância EC2 na AWS. A infraestrutura é gerenciada 100% como código (IaC) usando Terraform, e os serviços são orquestrados via Docker Compose.

O objetivo é criar uma base de observabilidade robusta, escalável e de fácil manutenção, seguindo as melhores práticas SRE de separação de responsabilidades e infraestrutura imutável.

## 🚀 Arquitetura e Componentes

O Terraform é responsável por provisionar toda a infraestrutura base:
* **Rede:** Uma VPC customizada, Sub-rede pública, Internet Gateway e Route Table.
* **Segurança:** Um Security Group dedicado que libera as portas (SSH, Grafana, Prometheus, Alertmanager) apenas para seu IP.
* **Computação:** Uma instância EC2 (t3.medium) que hospedará os serviços.
* **IAM:** Uma Role e Instance Profile que concede à EC2 permissão de leitura (`ReadOnly`) no CloudWatch, permitindo ao Prometheus descobrir e coletar métricas de outros serviços AWS.
* **Armazenamento:** Um Volume EBS dedicado (montado em `/data`) para persistir os dados do Prometheus, Grafana e Alertmanager, garantindo que os dados não sejam perdidos se a instância for recriada.

A instância EC2, ao ser criada, executa um script (`user_data.sh.tpl`) que:
1.  Instala o Docker e o Docker Compose.
2.  Formata e monta o volume EBS em `/data`.
3.  Gera dinamicamente todos os arquivos de configuração em `/opt/monitoring`.
4.  Inicia toda a stack de serviços usando `docker-compose up -d`.

---

## 🛠️ Stack de Serviços (Docker Compose)

* **Prometheus:** O cérebro do sistema. Coleta e armazena métricas (TSDB).
* **Grafana:** A interface de visualização. Cria dashboards e painéis.
* **Alertmanager:** Gerencia e roteia os alertas definidos no Prometheus para canais de notificação (ex: Slack, PagerDuty).
* **CloudWatch Exporter:** Um *exporter* que busca métricas de serviços AWS (como EC2, RDS, ELB) via API do CloudWatch e as expõe no formato que o Prometheus entende.

---

## 📋 Passo a Passo da Implementação

Siga estes passos para provisionar a infraestrutura.

### 1. Pré-requisitos

Antes de começar, garanta que você tenha:
* O [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) instalado (v1.0.0+).
* O [AWS CLI](https://aws.amazon.com/cli/) instalado e configurado com credenciais de administrador (`aws configure`).
* Um **Key Pair (chave SSH)** já existente na sua conta AWS.
* **(Opcional)** Uma URL de Webhook do Slack para receber os alertas.

### 2. Configuração

1.  **Clone este repositório** (ou salve todos os arquivos .tf em um diretório).

2.  **Crie o arquivo `terraform.tfvars`:**
    Este é o arquivo principal para suas variáveis locais. Crie um arquivo chamado `terraform.tfvars` no mesmo diretório e adicione o seguinte conteúdo, substituindo pelos seus valores:

    ```hcl
    # (Exemplo de terraform.tfvars)

    # Seu endereço IP público. O Security Group usará isso para liberar
    # o acesso SSH (22), Grafana (3000) e Prometheus (9090).
    # Para descobrir seu IP: curl ifconfig.me
    my_ip = "SEU_IP_AQUI/32"

    # O nome exato da sua chave Key Pair existente na AWS.
    aws_key_pair_name = "nome-da-sua-chave-aws"

    # (Opcional) Região da AWS onde os recursos serão criados.
    aws_region = "us-east-1"
    ```

3.  **(Opcional) Configure o Alertmanager (Slack):**
    Se você deseja receber alertas no Slack, edite o arquivo `user_data.sh.tpl` e modifique a seção `alertmanager.yml`:

    * Altere `global.slack_api_url` para a sua URL de Webhook.
    * Altere `receivers.slack_configs.channel` para o seu canal (ex: `#alertas-sre`).

### 3. Execução (Deploy)

Com os arquivos de configuração prontos, execute o Terraform.

1.  **Inicialize o Terraform:**
    Este comando baixa o provedor da AWS.
    ```bash
    terraform init
    ```

2.  **Planeje a Execução:**
    O Terraform irá mostrar todos os recursos que serão criados.
    ```bash
    terraform plan
    ```

3.  **Aplique a Configuração:**
    Este comando provisionará a infraestrutura na AWS. Digite `yes` quando solicitado.
    ```bash
    terraform apply
    ```

Ao final, o Terraform exibirá os `outputs`, incluindo o IP público da sua nova instância.

### 4. Acesso Pós-Deploy

Aguarde cerca de **2 a 3 minutos** após o `terraform apply` ser concluído para que o script `user_data` termine de instalar tudo e iniciar os contêineres.

Você pode acessar as interfaces pelos seguintes endereços:

* **Grafana (Dashboard):**
    * URL: `http://<SEU_IP_PUBLICO>:3000`
    * Login: `admin` / `admin` (será solicitado que você troque a senha no primeiro acesso)

* **Prometheus (Querying):**
    * URL: `http://<SEU_IP_PUBLICO>:9090`
    * (Verifique a aba `Status > Targets` para ver se o Prometheus está coletando métricas dele mesmo e do CloudWatch Exporter).

* **Alertmanager (Alertas):**
    * URL: `http://<SEU_IP_PUBLICO>:9093`

---

## ⚙️ Guia Rápido Pós-Deploy: Configurando o Grafana

Para começar a ver seus dados, você precisa conectar o Grafana ao Prometheus.

1.  Acesse o Grafana (`http://<SEU_IP_PUBLICO>:3000`).
2.  No menu lateral (ícone ⚙️), vá em **Data Sources**.
3.  Clique em **Add data source** e escolha **Prometheus**.
4.  No campo **URL**, insira: `http://prometheus:9090`
    * *(Não use o IP público. Como eles estão na mesma rede Docker Compose, o Grafana pode encontrar o Prometheus pelo nome do serviço).*
5.  Clique em **Save & Test**. Você deve ver uma mensagem verde de sucesso.

**Para importar um dashboard:**
1.  No menu lateral (ícone 🪟), vá em **Dashboards**.
2.  Clique em **Import**.
3.  Cole o ID `9579` (Dashboard: AWS CloudWatch Exporter) e clique em **Load**.
4.  Selecione o Data Source "Prometheus" que você acabou de criar e clique em **Import**.

Pronto! Você estará vendo as métricas da sua conta AWS.