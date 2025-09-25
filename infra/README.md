# Terraform / OpenTofu + FluxCD GitOps на KIND та GKE — Повний звіт про виконання

## Мета

* Локальна розробка на **KIND** → продакшн-подібний деплой на **GKE**.
* Автоматизований **CI/CD (GitHub Actions → GHCR)** для контейнера й Helm-чарту.
* **FluxCD** для GitOps-синхронізації та автодеплою додатку (**sentinel-bot / kbot**) через **OCI Helm chart**.

---

## Передумови

* Інструменти: `git`, `gh` (GitHub CLI), `docker` (+ buildx), `kubectl`, `helm`, `terraform` або `opentofu`, `kind`, `yq`, `oras` (опц.).
* GitHub: створити **Personal Access Token (classic)** зі scope:

  * `repo`
  * `write:packages` (включає `read:packages`)
* Додати токен у репозиторій як секрет **`GHCR_PAT`**: `Settings → Secrets and variables → Actions → New repository secret`.
* Обліковки / імена образів:

  * Контейнер: `ghcr.io/<owner>/sentinel-bot`
  * Helm-чарти (OCI): `oci://ghcr.io/<owner>/charts`

---

## Структура репозиторію

```text
.
├── Dockerfile
├── LICENSE
├── Makefile
├── README.md
├── RELEASE.md
├── _dist
│   └── sentinel-bot-0.1.2.tgz
├── cmd
│   ├── root.go
│   ├── sentinel-bot.go
│   └── version.go
├── go.mod
├── go.sum
├── helm
│   └── sentinel-bot
│       ├── Chart.yaml
│       ├── templates
│       │   ├── NOTES.txt
│       │   ├── _helpers.tpl
│       │   ├── deployment.yaml
│       │   ├── secret.yaml
│       │   └── service.yaml
│       └── values.yaml
├── infra
│   ├── argocd-app-sentinel.yaml
│   ├── flux-bootstrap
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfstate
│   │   ├── terraform.tfstate.backup
│   │   ├── terraform.tfvars
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── gke
│   │   ├── kustomization.yaml
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfstate
│   │   ├── terraform.tfstate.backup
│   │   ├── variables.tf
│   │   └── versions.tf
│   └── kind
│       ├── kind-cluster-config
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfstate
│       ├── terraform.tfstate.backup
│       ├── variables.tf
│       └── versions.tf
├── main.go
└── sentinel-bot
```

---

## Інфраструктура (KIND / GKE)

### Локально (KIND через Terraform/OpenTofu)

```bash
cd infra/kind
tofu init -upgrade
tofu apply -auto-approve -var="kubeconfig_path=$(pwd)/kubeconfig"
export KUBECONFIG="$(tofu output -raw kubeconfig_path)"
kubectl get nodes
kubectl get ns
```

При потребі видалити: `kind delete cluster --name dev`

### У GKE

* Кластер створено модулем [`tf-google-gke-cluster`](https://github.com/mexxo-dvp/tf-google-gke-cluster).
* Тип: **зональний GKE-кластер** (менше вимог до SSD-квоти).
* Terraform керує:

  * GKE cluster + node pool
  * TLS ключами (модуль `tf-hashicorp-tls-keys`)
  * Deploy-key у GitHub
  * Flux bootstrap (`tf-fluxcd-flux-bootstrap`)

---

## FluxCD Bootstrap

* Простір імен: `flux-system`.
* Очікувані деплойменти: `source-controller`, `helm-controller`, `kustomize-controller`, `notification-controller`.

```bash
kubectl -n flux-system get ns
kubectl -n flux-system get deploy
kubectl -n flux-system get gitrepositories,helmrepositories,helmreleases
```

* Провайдер `fluxcd/flux` читає kubeconfig з env. Перед `terraform apply`:

```bash
export KUBECONFIG=infra/kind/kubeconfig   # або ~/.kube/config для GKE
```

---

## 5. CI/CD (GitHub Actions → GHCR)

Файл: `.github/workflows/cicd.yaml`

### Тригери

* push у `main`
* теги `v*.*.*`
* manual `workflow_dispatch`

### Що робить

1. Генерує версії: `${base_tag}-${sha_short}-${OS}-${ARCH}`, `main`, ін.
2. Логується в GHCR через `GHCR_PAT` або `GITHUB_TOKEN`.
3. Збирає і пушить docker-образ у `ghcr.io/<owner>/sentinel-bot`.
4. Оновлює `values.yaml` та `Chart.yaml` через `yq` (тільки на branch push).
5. На тег `v*.*.*`: пакує Helm-чарт і пушить в `oci://ghcr.io/<owner>/charts`.

Приклад ручного запуску:

```bash
gh workflow run "sentinel-bot CI/CD" -r main
gh run list --workflow "cicd.yaml" --limit 5
```

### Типові CI-проблеми

* `Unrecognized named-value: 'secrets'` → треба `${{ ... }}`.
* `403 Forbidden` при push → PAT без `write:packages` або SSO неавторизоване.
* Commit-бамп на PR/tag → ми обмежили тільки на push у branch.

---

## Деплой додатку через Flux

### A) GitRepository (dev-оточення)

* Flux `GitRepository` → HelmChart з гіта → HelmRelease деплоїть чарти.

### B) HelmRepository (OCI)

* Flux `HelmRepository`: `oci://ghcr.io/<owner>/charts`
* HelmRelease: `chart: sentinel-bot`, `version: 0.1.*`

Очікувано: `HelmRelease` в статусі `Ready=True`, деплой апки розгорнутий.

```bash
kubectl -n apps wait --for=condition=Ready hr/sentinel-bot --timeout=5m
kubectl -n apps rollout status deploy/sentinel-bot
```

---

## Release Flow (tags → chart publish → Flux upgrades)

1. Бамп версії в `Chart.yaml` (якщо не робить CI).
2. Створити тег і реліз:

   ```bash
   git tag v0.1.4
   git push origin refs/tags/v0.1.4
   gh release create v0.1.4 --target main --generate-notes -t "sentinel-bot v0.1.4"
   ```
3. CI пакує і пушить чарт у GHCR.
4. Flux з `version: 0.1.*` підтягує нову версію.

Перевірка:

```bash
helm pull oci://ghcr.io/<owner>/charts/sentinel-bot --version 0.1.4
kubectl -n apps get deploy sentinel-bot -o=jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

---

## Makefile шорткати

* `make print` — показати owner/image/tags/helm repo.
* `make image` — buildx build+push у GHCR.
* `make helm-bump` — синхронізувати values & Chart локально.
* `make helm-release` — `helm package` + `helm push`.

---

## Типові проблеми і рішення

* **403 при push у GHCR** — токен без `write:packages` або SSO не авторизоване.
* **Flux HelmChart не переключається на HelmRepository** — перевірити `HelmChart` і HR, зробити reconcile.
* **`invalid configuration: no configuration has been provided`** — забутий `export KUBECONFIG`.
* **KIND kubeconfig path дублюється** — завжди передавати `-var="kubeconfig_path=$(pwd)/kubeconfig"`.
* **gh api 403** — використовувати `GH_TOKEN=<PAT>` із `read:packages`.

---

## Валідейшн чекліст

* [ ] KIND кластер працює, `kubectl get nodes` OK.
* [ ] Flux-контролери у `flux-system` namespace.
* [ ] GitRepository/HelmRepository у статусі `Ready`.
* [ ] HelmRelease → `Ready`.
* [ ] CI на push у main зібрав образ у GHCR.
* [ ] Реліз-тег створив чарт у GHCR, `helm pull` працює.
* [ ] Flux підтягнув новий чарт (semver).

---

## One-liner статус команди

```bash
# CI runs (latest 5)
gh run list --workflow "cicd.yaml" --limit 5

# Поточний образ у кластері
kubectl -n apps get deploy sentinel-bot -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# HelmChart (source kind/name)
kubectl -n flux-system get helmchart -o wide

# Force reconcile
kubectl -n flux-system annotate helmrepository/mexxo-charts reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n apps annotate hr/sentinel-bot reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# GHCR: список chart tags
oras repo tags ghcr.io/<owner>/charts/sentinel-bot | sort -V | tail -n 20
```

---

## Прибирання (destroy)

```bash
# Flux/GitOps
tofu -chdir=infra/flux destroy -auto-approve

# Локальний кластер
tofu -chdir=infra/kind destroy -auto-approve || true
kind delete cluster || true
```
---

## Висновок

* ✅ Інфраструктура (KIND/GKE) піднята Terraform/OpenTofu.
* ✅ FluxCD забутстраплено і підключено до GitHub.
* ✅ CI/CD автоматично збирає контейнер і чарт, пушить у GHCR.
* ✅ Flux автопідтягує нові версії та розгортає апку.

Час: 20 годин від початку до кінця (завантаження KIND,GKE + Flux через Terraform, CI/CD, GHCR, релізна лінія, документація).
Ціна: фіксована $350 (за домовленістю).
