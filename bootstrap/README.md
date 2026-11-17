# Bootstrap do backend do Terraform

> Cria o **bucket S3** e a **tabela DynamoDB** que guardam e travam todos os states do Terraform do AutoReparos: plataforma, banco, Lambda e os quatro microsserviços.

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.7-844FBA?logo=terraform&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon%20S3-state-569A31?logo=amazons3&logoColor=white)
![DynamoDB](https://img.shields.io/badge/DynamoDB-lock-4053D6?logo=amazondynamodb&logoColor=white)

Parte do [AutoReparos.Infra.K8s](../README.md) · repositório pai: [Grupo78-PosTech-15SOAT/AutoReparos](https://github.com/Grupo78-PosTech-15SOAT/AutoReparos)

---

## 1. Por que um módulo separado

O Terraform guarda o state num bucket S3 e usa uma tabela DynamoDB para impedir duas execuções simultâneas. Esse bucket e essa tabela não podem ser criados por um Terraform que já depende deles. O `bootstrap/` resolve o problema do ovo e da galinha:

1. na primeira execução, roda com **state local**, cria o bucket e a tabela;
2. em seguida **migra o próprio state** para dentro do bucket recém-criado (`bootstrap/terraform.tfstate`);
3. nas execuções seguintes, já usa o backend remoto como qualquer outro stack.

---

## 2. Recursos provisionados

| Recurso | Nome em produção | Configuração |
|---|---|---|
| `aws_s3_bucket.terraform_state` | `autoreparos-tfstate-198903849859` (variável `TF_STATE_BUCKET`) | `force_destroy = false` e `prevent_destroy` |
| `aws_s3_bucket_versioning` | — | Versionamento ligado: histórico e recuperação de states |
| `aws_s3_bucket_server_side_encryption_configuration` | — | SSE-S3 (`AES256`) |
| `aws_s3_bucket_public_access_block` | — | Os quatro bloqueios de acesso público ligados |
| `aws_s3_bucket_ownership_controls` | — | `BucketOwnerEnforced` (sem ACLs) |
| `aws_s3_bucket_policy.enforce_tls` | — | Nega qualquer `s3:*` sem TLS (`aws:SecureTransport = false`) |
| `aws_dynamodb_table.terraform_locks` | `autoreparos-terraform-locks` (variável `TF_LOCK_TABLE`) | Chave `LockID` (String), `PAY_PER_REQUEST`, PITR e criptografia ligados, `prevent_destroy` |

Tags padrão: `Project = AutoReparos`, `Component = TerraformBootstrap`, `Environment`, `ManagedBy = Terraform`, `Repository`.

---

## 3. Quem usa o backend

```mermaid
flowchart LR
    subgraph Backend["Backend criado por este módulo"]
        direction TB
        Bucket[("S3 autoreparos-tfstate-198903849859<br/>versionado, cifrado, só TLS")]
        Lock[("DynamoDB autoreparos-terraform-locks<br/>LockID")]
    end

    subgraph Pai["Workflows do pai - role da plataforma"]
        direction TB
        P1["bootstrap/terraform.tfstate"]
        P2["network/production<br/>platform/production<br/>gateway/production"]
        P3["database/terraform.tfstate<br/>lambda-auth/terraform.tfstate"]
    end

    subgraph Servicos["Pipeline de cada serviço - role autoreparos-deploy-servico"]
        S1["servicos/servico/production.tfstate"]
    end

    P1 --> Bucket
    P2 --> Bucket
    P3 --> Bucket
    S1 -->|"só o próprio prefixo"| Bucket
    Pai -.->|"lock"| Lock
    Servicos -.->|"lock só das próprias chaves"| Lock

    classDef back fill:#ede9fe,stroke:#7c3aed,color:#3b0764
    classDef pai fill:#e0f2fe,stroke:#0284c7,color:#0c4a6e
    classDef svc fill:#dcfce7,stroke:#16a34a,color:#14532d
    class Bucket,Lock back
    class P1,P2,P3 pai
    class S1 svc
```

| Chave do state | Stack | Repositório |
|---|---|---|
| `bootstrap/terraform.tfstate` | este módulo | AutoReparos.Infra.K8s |
| `network/production/terraform.tfstate` | `terraform/stacks/base` | AutoReparos.Infra.K8s |
| `platform/production/terraform.tfstate` | `terraform/stacks/platform` | AutoReparos.Infra.K8s |
| `gateway/production/terraform.tfstate` | `terraform/stacks/gateway` | AutoReparos.Infra.K8s |
| `database/terraform.tfstate` | `terraform/` | AutoReparos.Infra.Database |
| `lambda-auth/terraform.tfstate` | `infra/` | AutoReparos.AuthLambda |
| `servicos/<servico>/production.tfstate` | `infra/terraform` | OS, Cobrança, Execução e Cadastros |
| `k8s/terraform.tfstate` | raiz legada da Fase 3 (congelada) | AutoReparos.Infra.K8s |

As roles `autoreparos-deploy-<servico>` só leem e gravam objetos em `servicos/<servico>/*` e só travam chaves desse prefixo (condição `dynamodb:LeadingKeys`), conforme a política em [`../terraform/stacks/base/politicas/deploy-servico.json.tftpl`](../terraform/stacks/base/politicas/deploy-servico.json.tftpl).

---

## 4. Como executar

### 4.1 Pelo GitHub Actions (caminho oficial)

Workflow `Bootstrap AWS Terraform backend` ([`bootstrap-aws.yml`](https://github.com/Grupo78-PosTech-15SOAT/AutoReparos/blob/main/.github/workflows/bootstrap-aws.yml)) no repositório pai:

| Item | Valor |
|---|---|
| Disparo | `workflow_dispatch`, só na `main` |
| Entradas | `confirmation = CONFIRMAR-BOOTSTRAP` e `existing_resources_reviewed = true` |
| Environment | `aws-bootstrap` |
| Credencial | OIDC com o secret `AWS_ROLE_ARN` do Environment |
| Variáveis | `AWS_REGION`, `AWS_ACCOUNT_ID`, `TF_STATE_BUCKET`, `TF_LOCK_TABLE` |
| Concorrência | Mesmo grupo dos workflows de provisionamento, deploy e teardown |

```mermaid
sequenceDiagram
    autonumber
    actor Op as Operador
    participant WF as bootstrap-aws.yml
    participant STS as AWS STS
    participant S3 as S3
    participant TF as Terraform

    Op->>WF: CONFIRMAR-BOOTSTRAP + inventário revisado
    WF->>STS: get-caller-identity
    alt conta diferente de AWS_ACCOUNT_ID
        WF-->>Op: falha, nada é criado
    end
    WF->>S3: existe bootstrap/terraform.tfstate?

    alt state remoto já existe
        rect rgb(224, 242, 254)
            WF->>TF: init com o backend S3
            WF->>TF: plan e apply (reconcilia)
        end
    else primeira execução ou execução interrompida
        rect rgb(255, 244, 229)
            WF->>WF: copia o módulo para uma pasta temporária<br/>e remove o bloco backend da cópia
            WF->>TF: init -backend=false
            WF->>S3: bucket e tabela já existem na conta?
            WF->>TF: import do que já existir<br/>bucket, versionamento, criptografia,<br/>bloqueio público, ownership, política e tabela
            WF->>TF: plan e apply com state local
            WF->>WF: restaura o main.tf original
            WF->>TF: init -migrate-state -force-copy
            TF->>S3: grava bootstrap/terraform.tfstate
        end
    end
```

Os imports só adotam recursos da conta configurada (`--expected-bucket-owner`) e com os nomes exatos configurados. Um nome igual não prova propriedade: por isso a entrada `existing_resources_reviewed` exige que o inventário tenha sido revisado antes.

### 4.2 Localmente (só validação)

```bash
cd bootstrap
terraform fmt -check
terraform init -backend=false
terraform validate
```

O `main.tf` declara o backend S3 de forma parcial (bucket e região chegam por `-backend-config`), então um `apply` local só funciona repetindo o procedimento do workflow. Use o workflow.

---

## 5. Variáveis e outputs

| Variável | Padrão | Produção |
|---|---|---|
| `aws_region` | `us-east-1` | `AWS_REGION` |
| `environment` | `production` | padrão |
| `project_name` | `AutoReparos` | padrão |
| `state_bucket_name` | `autoreparos-terraform-state-backend` | `TF_STATE_BUCKET` = `autoreparos-tfstate-198903849859` |
| `lock_table_name` | `autoreparos-terraform-locks` | `TF_LOCK_TABLE` = `autoreparos-terraform-locks` |

| Output | Descrição |
|---|---|
| `state_bucket_name` · `state_bucket_arn` · `state_bucket_region` | Bucket do state |
| `lock_table_name` · `lock_table_arn` | Tabela de lock |

Os valores de `TF_STATE_BUCKET` e `TF_LOCK_TABLE` são definidos pelo `scripts/infra/configurar-github.sh` do pai, no pai e em cada repositório de serviço.

---

## 6. Ciclo de vida

- **`prevent_destroy`** no bucket e na tabela: um `terraform destroy` acidental falha.
- O workflow `Teardown AWS` do pai **não** remove o backend: o resumo do job registra que o bucket e o histórico de states foram mantidos.
- O CI do [Infra.K8s](../.github/workflows/ci.yml) valida este módulo (`fmt`, `init -backend=false`, `validate`) a cada mudança em `bootstrap/**`.
