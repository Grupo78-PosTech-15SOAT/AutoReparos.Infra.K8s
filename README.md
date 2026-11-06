# AutoReparos.Infra.K8s - Infraestrutura Kubernetes AWS EKS e API Gateway v2 (Terraform & Helm)

> **Projeto:** AutoReparos - Sistema Integrado de Oficina Mecânica  
> **Fase:** Fase 3 Tech Challenge (13SOAT / 15SOAT FIAP)  
> **Componente Obrigatório:** Repositório 2/4 da Arquitetura Multi-Repo  
> **Tecnologias:** Terraform >= 1.10, AWS EKS, AWS API Gateway HTTP API v2, Helm 3, AWS Load Balancer Controller, HPA, OpenTelemetry.
> **Repositório Oficial:** [Grupo78-PosTech-15SOAT/AutoReparos.Infra.K8s](https://github.com/Grupo78-PosTech-15SOAT/AutoReparos.Infra.K8s)

---

## 1. Visão Geral e Responsabilidades

Este repositório contém a definição completa de **Infraestrutura como Código (Terraform)** e **Empacotamento de Aplicações Kubernetes (Helm)** para a plataforma AutoReparos.

Ele atende integralmente aos requisitos da Fase 3 do Tech Challenge FIAP SOAT:
1. **Cluster Kubernetes Gerenciado (AWS EKS):** Provisionamento de cluster EKS com Managed Node Groups distribuídos em subnets privadas multi-AZ e auto-scaling configurado via Horizontal Pod Autoscaler (HPA).
2. **AWS API Gateway v2 (HTTP API):** Ponto de entrada unificado que implementa:
   - Rota `POST /auth/cliente` integrada diretamente com a **AWS Lambda** serverless (`AutoReparos.AuthLambda`).
   - Rota `ANY /api/{proxy+}` configurada como proxy HTTP reverso para o Network Load Balancer (NLB) e Ingress Controller do EKS.
3. **Rede VPC Segura:** Subnets públicas (NAT Gateways, Load Balancers) e subnets privadas (Node Groups do EKS e RDS) com isolamento estrito.
4. **Registro de Contêineres (AWS ECR):** Repositório privado com escaneamento de vulnerabilidades ativado para imagens Docker da aplicação.
5. **Helm Charts Modulares:** Empacotamento para API backend, Frontend Web Angular, Ingress Controller e stack de observabilidade (Jaeger, Prometheus, Loki, Otel Collector).

---

## 2. Diagrama de Roteamento e Arquitetura de Nuvem (Zero-Trust)

```mermaid
flowchart TD
    Client["Cliente / Dispositivo Externo"]
    
    subgraph APIGW["AWS API Gateway HTTP API v2"]
        RouteAuth["POST /auth/cliente"]
        RouteAPI["ANY /api/{proxy+}"]
        RouteHealth["GET /health"]
    end

    subgraph Lambda["Serverless (AutoReparos.AuthLambda)"]
        AuthFunc["Lambda Function .NET 10<br/>Validação CPF & Emissão JWT"]
    end

    subgraph VPCLinkArea ["Camada de Conectividade Privada"]
        VPCLink["aws_apigatewayv2_vpc_link<br/>(Subnets Privadas K8s)"]
    end

    subgraph EKS["AWS EKS Cluster (Subnets Privadas)"]
        NLB["AWS NLB Interno / Ingress NGINX"]
        API["Pods AutoReparos.API (.NET 10)<br/>HPA: 2 a 10 réplicas"]
        Web["Pods AutoReparos.Web (Angular 19)"]
        Otel["Otel Collector / Observability"]
    end

    Client --> APIGW
    RouteAuth --> AuthFunc
    RouteAPI --> VPCLink
    RouteHealth --> VPCLink
    VPCLink --> NLB
    NLB --> API
    NLB --> Web
    API -.->|Traces/Métricas| Otel
```

---

## 3. Estrutura de Arquivos

```
AutoReparos.Infra.K8s/
├── .github/
│   └── workflows/
│       └── ci.yml                     # CI: Terraform fmt/validate + Helm lint
├── terraform/
│   ├── modules/
│   │   ├── vpc/                       # Topologia VPC, Subnets Públicas/Privadas, NAT GW
│   │   ├── eks/                       # EKS Cluster, OIDC, Managed Node Groups, HPA
│   │   ├── ecr/                       # AWS ECR para imagens da API e Web
│   │   ├── addons/                    # Metrics Server, VPC CNI, CoreDNS, EBS CSI
│   │   └── apigateway/                # AWS API Gateway HTTP v2 (/auth/cliente e /api/*)
│   ├── main.tf                        # Orquestração dos módulos Terraform
│   ├── variables.tf                   # Declaração de variáveis
│   ├── outputs.tf                     # Endpoints e identificadores exportados
│   ├── providers.tf                   # Configuração dos provedores AWS
│   └── terraform.tfvars.example       # Exemplo de parametrização
├── k8s/
│   ├── charts/
│   │   ├── api/                       # Deployment, Service, HPA da API .NET 10
│   │   ├── web/                       # Deployment, Service do Frontend Angular 19
│   │   ├── ingress/                   # Ingress NGINX com regras de roteamento
│   │   └── observability/             # Jaeger, Prometheus, Grafana, Loki
│   ├── Chart.yaml                     # Metadados do Helm Umbrella Chart
│   ├── values.yaml                    # Configurações padrão e desenvolvimento
│   └── values-production.yaml         # Configurações de produção na nuvem
├── .gitignore                         # Ignora .terraform/, *.tfstate, *.tgz
└── README.md                          # Este documento
```

---

## 4. Tabela de Variáveis Principais (Terraform)

| Variável | Tipo | Padrão | Descrição |
|---|---|---|---|
| `aws_region` | `string` | `"us-east-1"` | Região AWS |
| `cluster_name` | `string` | `"autoreparos-cluster"` | Nome do cluster Kubernetes EKS |
| `environment` | `string` | `"production"` | Ambiente de deploy |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | Bloco CIDR da VPC |
| `instance_types` | `list(string)` | `["t3.small"]` | Instâncias EC2 dos worker nodes |
| `desired_size` | `number` | `2` | Quantidade desejada de nós no Node Group |
| `max_size` | `number` | `4` | Limite máximo para escalonamento automático |
| `min_size` | `number` | `2` | Limite mínimo de nós |
| `lambda_function_arn` | `string` | `""` | ARN da Lambda para rota `/auth/cliente` |
| `lambda_function_name` | `string` | `""` | Nome da Lambda para concessão de permissão |
| `eks_ingress_url` | `string` | `""` | ARN do listener ALB interno, consumido apenas pelo state `gateway` |

---

## 5. Deploy e Operação

### Provisionamento da Infraestrutura com Terraform

O provisionamento AWS é executado pelos workflows do repositório pai. Não execute `terraform apply` nesta raiz legada: o state reúne recursos de vários proprietários e a migração exige inventário e transferência revisados. Consulte `terraform/stacks/{base,platform,gateway}` para os novos roots e o plano de migração antes de qualquer mudança.

```bash
cd terraform/
terraform init
cp terraform.tfvars.example terraform.tfvars
terraform plan -out=tfplan
terraform apply tfplan
```

### Conectar o `kubectl` ao Cluster EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name autoreparos-cluster
kubectl get nodes
```

### Deploy da Aplicação com Helm

```bash
cd ../k8s/
helm dependency update .
helm upgrade --install autoreparos . \
  -f values-production.yaml \
  --namespace autoreparos \
  --create-namespace
```

---

## 6. Testes Locais de Observabilidade com Docker Compose

Para validar os componentes da stack de telemetria (OpenTelemetry Collector, Prometheus, Jaeger, Loki e Grafana) antes do empacotamento com Helm, o repositório disponibiliza um `docker-compose.yml`:

```bash
# Iniciar a stack local de observabilidade
docker-compose up -d

# Acessar os painéis locais:
# - Grafana: http://localhost:3000 (admin / admin)
# - Jaeger UI: http://localhost:16686
# - Prometheus: http://localhost:9090
# - Loki: http://localhost:3100
# - OTLP Collector: gRPC na porta 4317 / HTTP na porta 4318

# Parar o ambiente
docker-compose down
```

---

## 7. Integração Contínua (CI/CD)

O repositório conta com pipeline automatizada no GitHub Actions (`.github/workflows/ci.yml`) com controle de concorrência e actions com commit SHA fixados:
- `Terraform Format & Validate`: Verifica padrões de formatação HCL e integridade sintática dos módulos de forma recursiva.
- `Helm Lint`: Executa análise estática de todos os templates Helm garantindo validação de schemas e dependências.
- Não há workflow neste submódulo que aplique ou destrua infraestrutura. Os workflows do repositório pai são os únicos escritores dos states de produção.

---

## 8. Governança e Arquitetura Multi-Repo

### Provisionamento centralizado pelo repositório pai

Este repositório mantém Terraform e Helm; ele não executa mais `apply`, `destroy` nem bootstrap por GitHub Actions. O workflow de CI valida Terraform e Helm sem credenciais AWS. Os workflows com credenciais vivem no pai `AutoReparos` e usam estes states:

- `network/production/terraform.tfstate`: VPC, EKS, ECR API/Web e SG compartilhado da Lambda.
- `platform/production/terraform.tfstate`: addons EKS, storage class e AWS Load Balancer Controller.
- `gateway/production/terraform.tfstate`: API Gateway HTTP API, VPC Link, integrações e rotas.

O state legado `terraform/` contém recursos misturados. Ele fica congelado até que o inventário e a transferência descritos em [`migracao-states-aws.md`](../../../../docs/specs/fase3/cloud-iac/migracao-states-aws.md) sejam concluídos. Não inicialize os novos states sobre recursos que ainda estejam no legado. O parent workflow bloqueia se ainda encontrar recursos no state legado ou recursos homônimos sem state proprietário.

EKS usa versão 1.35; a versão PostgreSQL é mantida pelo state Database. O chart usa namespace informado pelo release (`autoreparos` em produção), um ALB interno gerenciado por AWS Load Balancer Controller e integração HTTP API com payload 1.0 para o handler Lambda `APIGatewayProxyRequest`. Web/API têm health checks próprios. Grafana é ClusterIP; o secret `autoreparos-grafana-admin` é criado em runtime e o acesso inicial é via port-forward.

Os workflows `Provision AWS`, `Deploy application` e `Teardown AWS` no pai têm Environment `production`, OIDC, aprovação do GitHub e grupo de concorrência único. Alterações no submódulo devem ser publicadas na branch de trabalho correspondente e depois incorporadas pelo ponteiro do pai antes de executar Actions; o checkout usa os commits registrados no pai.

### Validação local

```bash
terraform -chdir=terraform/stacks/base init -backend=false
terraform -chdir=terraform/stacks/base validate
terraform -chdir=terraform/stacks/platform init -backend=false
terraform -chdir=terraform/stacks/platform validate
terraform -chdir=terraform/stacks/gateway init -backend=false
terraform -chdir=terraform/stacks/gateway validate
helm lint k8s/
helm template autoreparos k8s/ --namespace autoreparos -f k8s/values-production.yaml
```

- **Isolamento Multi-Repo:** Repositório autônomo e focado em orquestração Kubernetes, provisionamento EKS e Gateway de roteamento de nuvem, exportando parâmetros de rede via AWS SSM Parameter Store (`/autoreparos/{environment}/vpc_id`, `/autoreparos/{environment}/subnets/private`, `/autoreparos/{environment}/security-groups/eks-nodes` e `/autoreparos/{environment}/apigateway/endpoint`).
- **Proteção de Branch:** Branch `main` protegida com obrigatoriedade de Pull Request, aprovação e status checks verdes antes do merge.
