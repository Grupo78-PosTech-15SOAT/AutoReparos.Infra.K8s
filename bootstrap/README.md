# AutoReparos - Bootstrap do Backend Remoto Terraform (S3 + DynamoDB)

Este módulo é responsável por criar a infraestrutura fundamental de **Remote State** e **Distributed State Locking** utilizada por todos os subprojetos de infraestrutura do AutoReparos (`AutoReparos.Infra.K8s`, `AutoReparos.Infra.Database` e `AutoReparos.AuthLambda`).

---

## 🎯 Por que um módulo isolado com Backend Local?

Para evitar **dependência circular** (o problema do *ovo e da galinha*):
- O Terraform precisa de um bucket S3 e uma tabela DynamoDB para armazenar e travar o state remoto.
- O módulo que cria esse bucket e tabela **não pode** depender deles próprios antes que existam.
- Portanto, este módulo `bootstrap` utiliza **backend local** intencionalmente e é executado uma única vez (ou via workflow manual idempotente).

---

## 📦 Recursos Provisionados

1. **Bucket S3** (`autoreparos-terraform-state-backend`):
   - Versionamento habilitado (histórico completo de revisões de state e rollback);
   - Criptografia em repouso SSE-S3 (AES256);
   - Bloqueio total de acesso público (`aws_s3_bucket_public_access_block`);
   - Controle estrito de propriedade de objetos (`BucketOwnerEnforced`);
   - Política obrigatória de transporte seguro HTTPS/TLS (`aws:SecureTransport = true`);
   - Proteção contra destruição acidental (`prevent_destroy = true`).

2. **Tabela DynamoDB** (`autoreparos-terraform-locks`):
   - Chave primária de partição: `LockID` (tipo String);
   - Modo de cobrança sob demanda (`PAY_PER_REQUEST`);
   - Point-in-Time Recovery (PITR) ativado;
   - Criptografia em repouso ativada;
   - Proteção contra destruição acidental (`prevent_destroy = true`).

---

## 🚀 Como Executar

### Via GitHub Actions (Recomendado)
Execute a action manual:
- **Workflow:** `.github/workflows/bootstrap-backend.yml`
- **Parâmetro de confirmação:** `CONFIRMAR-BOOTSTRAP`

Se os recursos já existirem na AWS e precisarem ser integrados ao state:
- **Workflow:** `.github/workflows/import-bootstrap-state.yml`
- **Parâmetro de confirmação:** `CONFIRMAR-IMPORT`

### Execução Local (Opcional)
```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```
