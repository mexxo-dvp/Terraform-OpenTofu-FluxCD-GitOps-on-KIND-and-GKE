# Flux Bootstrap on GKE

> Цей README фіксує **робочу** послідовність, що ми виконали, щоб підняти Flux v2 у GKE через Terraform.

---

## 1) Вихідні умови

* **GKE кластер**: `gke-flux` (зональний `europe-west1-b`).
* Доступ до GCP через `gcloud` (аутентифіковано).
* **GitHub**: приватний репозиторій `mexxo-dvp/gitops` — під GitOps.
* Локальне середовище: Codespaces/DevContainer (IP динамічна).

---

## 2) Kubernetes доступ (kubeconfig + context)

### 2.1. Правильний kubeconfig-файл

```bash
export KUBECONFIG=/home/codespace/.kube/config
mkdir -p "$(dirname "$KUBECONFIG")" && touch "$KUBECONFIG"
```

### 2.2. Отримати креденшіали **зонального** кластера

```bash
gcloud config set project civil-pattern-466501-m8
gcloud container clusters get-credentials gke-flux \
  --zone europe-west1-b \
  --project civil-pattern-466501-m8

kubectl config use-context \
  gke_civil-pattern-466501-m8_europe-west1-b_gke-flux
```

### 2.3. Смок-тести до API

```bash
kubectl get --raw=/version | head -n1
kubectl get ns
```
---

## 3) Доступ до API GKE (Master Authorized Networks)

Коли з Codespaces з’являвся `i/o timeout` — відкривали доступ до control plane.

### 3.1. Поточна публічна IP

```bash
MYIP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org)
echo "$MYIP"
```

### 3.2. Endpoint control plane

```bash
EP=$(gcloud container clusters describe gke-flux \
  --zone europe-west1-b --project civil-pattern-466501-m8 \
  --format='value(endpoint)'); echo "$EP"
```

### 3.3. Додати свою IP у MAN

```bash
gcloud container clusters update gke-flux \
  --zone europe-west1-b \
  --project civil-pattern-466501-m8 \
  --enable-master-authorized-networks \
  --master-authorized-networks "${MYIP}/32"
```

### 3.4. TCP‑перевірка

```bash
timeout 5 bash -c "cat </dev/null >/dev/tcp/$EP/443" && echo open || echo closed
```

Повторна перевірка `kubectl get ns` має спрацювати миттєво.

---

## 4) Terraform модуль для Flux (infra/flux-bootstrap)

Структура файлів:

```
infra/flux-bootstrap/
  main.tf
  providers.tf
  variables.tf
  versions.tf
  # опційно: .terraform.lock.hcl
```

### 4.1. `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    github = { source = "integrations/github", version = "~> 6.6" }
    flux   = { source = "fluxcd/flux",         version = "~> 1.6.4" }
    tls    = { source = "hashicorp/tls",       version = "~> 4.0" }
  }
}
```

### 4.2. `providers.tf`

```hcl
provider "github" {
  owner = var.github_owner
}

# v1.6: nested blocks as map arguments, no merge()
provider "flux" {
  kubernetes = {
    # important: revealing ~
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubeconfig_context
  }

  git = {
    url    = "ssh://git@github.com/${var.github_owner}/${var.github_repo}.git"
    branch = var.github_branch
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}
```

### 4.3. `variables.tf`

```hcl
variable "github_owner" {
  type        = string
  description = "GitHub owner/org"
  validation {
    condition     = length(var.github_owner) > 0
    error_message = "github_owner cannot be empty."
  }
}

variable "github_repo" {
  type        = string
  description = "name of a private GitOps repo, e.g.: gitops"
  validation {
    condition     = length(var.github_repo) > 0
    error_message = "github_repo cannot be empty."
  }
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "GitOps repo branch"
}

variable "gitops_path" {
  type        = string
  default     = "./apps"
  description = "Subdirectory in the GitOps repo where Flux manifests are committed"
}

variable "kubeconfig_path" {
  type        = string
  description = <<EOT
The path to kubeconfig GKE, for example.:
~/.kube/config або /workspaces/sentinel-bot/infra/gke/.kube/gke-gke-flux.kubeconfig
EOT
  validation {
    condition     = length(var.kubeconfig_path) > 0
    error_message = "kubeconfig_path is required."
  }
}

# Explicitly fix the correct context (zone europe-west1-b)
variable "kubeconfig_context" {
  type        = string
  default     = "gke_civil-pattern-466501-m8_europe-west1-b_gke-flux"
  description = "Kube-context for connecting to the cluster"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "Classic PAT from scope: repo"
  validation {
    condition     = length(var.github_token) > 0
    error_message = "github_token is required (add as a variable or in tfvars)."
  }
}
```

### 4.4. `main.tf`

```hcl
# --- Key for accessing private GitOps repo via SSH (deploy key) ---
resource "tls_private_key" "flux" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "flux" {
  repository = var.github_repo
  title      = "gitops:flux"
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}

# --- Bootstrap Flux in cluster + commit manifests to GitOps repo ---
resource "flux_bootstrap_git" "this" {
# where in the repository the cluster manifests are stored
  path = var.gitops_path

# where to install Flux in the cluster
  namespace            = "flux-system"
  keep_namespace       = false
  network_policy       = true
  watch_all_namespaces = true

# version of Flux components that will be pushed to the cluster and committed to the repo
  version = "v2.6.4"

# Flux components
  components = [
    "source-controller",
    "kustomize-controller",
    "helm-controller",
    "notification-controller",
  ]

  # housekeeping
  interval       = "1m0s"
  log_level      = "info"
  cluster_domain = "cluster.local"

# Git manifests with Flux (will commit to your GitOps repo via SSH)
  delete_git_manifests = true
  embedded_manifests   = false

  depends_on = [
    github_repository_deploy_key.flux
  ]
}
```

---

## 5) Запуск Terraform (з каталогу модуля або через `-chdir`)

> Варіант із `-chdir` (з кореня репо):

```bash
export GITHUB_TOKEN="<PAT>"  # або TF_VAR_github_token

terraform -chdir=infra/flux-bootstrap init -upgrade -reconfigure
terraform -chdir=infra/flux-bootstrap apply -auto-approve \
  -var='kubeconfig_path=/home/codespace/.kube/config' \
  -var='kubeconfig_context=gke_civil-pattern-466501-m8_europe-west1-b_gke-flux' \
  -var='github_owner=mexxo-dvp' \
  -var='github_repo=gitops' \
  -var='github_branch=main' \
  -var='gitops_path=./apps'
```

Очікуваний результат — створений ресурс `flux_bootstrap_git.this` та `Ready=True` стан у Flux.

---

## 6) Верифікація Flux у кластері

```bash
kubectl -n flux-system get deploy -owide
kubectl -n flux-system get pods -owide
kubectl get crd | grep -i toolkit.fluxcd.io

kubectl -n flux-system get gitrepositories.source.toolkit.fluxcd.io
kubectl -n flux-system get kustomizations.kustomize.toolkit.fluxcd.io
kubectl -n flux-system get kustomization flux-system -o jsonpath='{.spec.path}{"\n"}'
# має бути: ./apps

kubectl -n flux-system get events --sort-by=.lastTimestamp | tail -n 30
```

**Ready-сигнали**:

* `kustomization/flux-system` → `ReconciliationSucceeded`, `Applied revision: main@sha1:...`.
* Всі контролери `Running`.

---

## 7) Тріадж типових проблем

* **`context "..." does not exist`** — Terraform читав не той kubeconfig/контекст. Виправили через `pathexpand(var.kubeconfig_path)` та явний `kubeconfig_context`.
* **`i/o timeout ...:443`** — немає доступу до API GKE. Рішення: додали `MYIP/32` у **Master Authorized Networks**.
* **`sync path ... would overwrite ...`** — розбіжність між шляхом у кластері та в Terraform. Вирішили, поставивши `gitops_path = "./apps"`.
* **Git/GitHub**: 401 по deploy key → виставили **GITHUB\_TOKEN**/PAT і перевипустили deploy key через Terraform.
* **`gcloud --kubeconfig`** — такого прапорця нема. Працюємо через `KUBECONFIG` env.

---

## 8) Корисна інформація

**Перевстановити Flux:**

```bash
flux uninstall --namespace flux-system --silent || true
# або видалити тільки GitRepository/Kustomization (CRD залишаться)
kubectl -n flux-system delete kustomization flux-system || true
kubectl -n flux-system delete gitrepository flux-system || true
```

**Перевірити джерело Git у кластері:**

```bash
kubectl -n flux-system get gitrepository flux-system -o jsonpath='{.spec.url}{"\n"}'
# очікуємо: ssh://git@github.com/mexxo-dvp/gitops.git
```

**Перезапустити reconcile:**

```bash
flux reconcile kustomization flux-system -n flux-system --with-source
```

---

## 9) Підсумок

* Доступ до кластера налагоджено (зональний контекст).
* MAN відкрито на твою поточну IP → `kubectl` та Terraform працюють.
* Flux v2 розгорнуто через Terraform, синхронізація з приватного `mexxo-dvp/gitops`.
* Узгоджений корінь GitOps: `./apps` (у кластері та в Terraform).
