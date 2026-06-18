# Azure DevSecOps CI/CD POC — Hello World

> **Purpose:** A comprehensive DevSecOps reference implementation demonstrating **CI/CD**, **DevSecOps**, **IaC**, and **deployment** on Azure using **Azure DevOps**, **GitHub**, **SonarQube**, **Trivy**, and **Azure Monitor**.
> **Stack:** Node.js 20 + Express (easily swappable to .NET, Python, Java, etc.).

---

## 1. What This POC Demonstrates

| Pattern | How It Is Implemented |
|---------|----------------------|
| **CI (Continuous Integration)** | Install → Lint → Test → SonarQube SAST → Trivy Container Scan → Package artifact + Docker image |
| **CD (Continuous Deployment)** | Provision infra with Bicep → Deploy code to Web App via Zip Deploy |
| **IaC (Infrastructure as Code)** | Bicep modules for compute, monitoring, and diagnostics; no manual portal clicks |
| **DevSecOps** | SonarQube (SAST) + Trivy (container vulnerability scan) integrated in pipeline |
| **Observability** | Application Insights + Log Analytics + Azure Monitor Alerts + Diagnostic Settings |
| **Multi-Source** | Both Azure DevOps YAML and GitHub Actions workflows included |
| **Managed Identity** | System-assigned MI enabled on Web App for future Key Vault / SQL access |
| **Environment Promotion** | Parameter files (`dev.bicepparam`) for per-environment configs |

---

## 2. Architecture Diagram

```
┌─────────────────┐     ┌─────────────────────────────────────────────────────────────┐
│   Developer     │────►│  GitHub Repository                                          │
│   (Push Code)   │     │  • Source code                                              │
└─────────────────┘     │  • Azure DevOps pipeline YAML (for ADO repos)              │
                        │  • GitHub Actions workflow (for GitHub repos)              │
                        └─────────────────────────────────────────────────────────────┘
                                                   │
                        ┌──────────────────────────┼──────────────────────────┐
                        │                          │                          │
                        ▼                          ▼                          ▼
               ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
               │ Azure DevOps    │      │ GitHub Actions  │      │ SonarQube       │
               │ Pipelines       │      │ Workflow        │      │ (SAST Analysis) │
               │                 │      │                 │      │                 │
               │ • Build & Test  │      │ • Build & Test  │      │ • Code Quality  │
               │ • SonarQube     │      │ • SonarQube     │      │ • Security      │
               │ • Trivy Scan    │      │ • Trivy Scan    │      │   Hotspots      │
               │ • Deploy to Azure│     │ • Deploy to Azure│     │ • Coverage Gate │
               └────────┬────────┘      └────────┬────────┘      └────────┬────────┘
                        │                          │                          │
                        └──────────────────────────┼──────────────────────────┘
                                                   │
                                                   ▼
                        ┌─────────────────────────────────────────────────────────────┐
                        │  Azure DevOps / GitHub Actions — CI Stage                 │
                        │  ───────────────────────────────────────────────           │
                        │  1. npm ci / build                                         │
                        │  2. npm test (Jest + coverage)                              │
                        │  3. SonarQube Scan (SAST)                                   │
                        │  4. Docker Build                                            │
                        │  5. Trivy Scan (CVE check)                                  │
                        │  6. Publish Artifact / Push to ACR                          │
                        └─────────────────────────────────────────────────────────────┘
                                                   │
                                                   ▼
                        ┌─────────────────────────────────────────────────────────────┐
                        │  Azure DevOps / GitHub Actions — CD Stage                 │
                        │  ───────────────────────────────────────────────           │
                        │  1. Bicep Deploy (Subscription-level)                       │
                        │     • Resource Group                                        │
                        │     • App Service Plan + Web App                            │
                        │     • Log Analytics + App Insights                          │
                        │     • Azure Monitor Alerts + Diagnostic Settings            │
                        │  2. Zip Deploy / Container Deploy                           │
                        │  3. Smoke Test (/health endpoint)                           │
                        │  4. Azure Monitor Alert Verification                        │
                        └─────────────────────────────────────────────────────────────┘
                                                   │
                                                   ▼
                        ┌─────────────────────────────────────────────────────────────┐
                        │  Azure Resources (Dev Environment)                          │
                        │  ───────────────────────────────────────────────           │
                        │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
                        │  │ App Service │  │ App Insights│  │ Log Analytics   │  │
                        │  │ (Web App)   │  │ (APM)       │  │ Workspace       │  │
                        │  │             │  │             │  │                 │  │
                        │  │ • Linux B1  │  │ • Tracing   │  │ • Logs          │  │
                        │  │ • Node 20   │  │ • Metrics   │  │ • Metrics       │  │
                        │  │ • HTTPS     │  │ • Alerts    │  │ • 30d retention │  │
                        │  └─────────────┘  └─────────────┘  └─────────────────┘  │
                        │         │                                      │            │
                        │         └──────────────────────────────────────┘            │
                        │                        │                                    │
                        │                        ▼                                    │
                        │           ┌─────────────────────┐                             │
                        │           │ Azure Monitor       │                             │
                        │           │ • Alerts (HTTP 5xx) │                             │
                        │           │ • Alert (High CPU)  │                             │
                        │           │ • Diagnostic Settings│                             │
                        │           └─────────────────────┘                             │
                        └─────────────────────────────────────────────────────────────┘
```

---

## 3. Repository Structure

```
azure-cicd-poc/
├── app/                          # Application source code
│   ├── src/
│   │   └── index.js              # Express server with /, /health, /api/info
│   ├── tests/
│   │   └── app.test.js           # Jest unit tests (3 tests, 100% coverage)
│   ├── Dockerfile                # Multi-stage container build (node:20-alpine)
│   ├── .dockerignore
│   ├── package.json
│   ├── jest.config.js            # Jest config with Cobertura + JUnit output
│   └── sonar-project.properties  # SonarQube configuration
├── infra/                        # Infrastructure as Code (Bicep)
│   ├── main.bicep                # Orchestrator (subscription-level)
│   ├── modules/
│   │   ├── appService.bicep      # App Service Plan + Web App (MI enabled)
│   │   ├── monitoring.bicep      # App Insights + Log Analytics
│   │   └── alerts.bicep          # Azure Monitor Alerts (HTTP 5xx, CPU, Memory)
│   └── parameters/
│       └── dev.bicepparam        # Dev environment parameter values
├── pipelines/
│   ├── azure-pipelines.yml       # Azure DevOps multi-stage pipeline
│   └── github-actions.yml        # GitHub Actions workflow (alternative)
├── README.md                     # This file
└── docs/
    ├── setup-sonarqube.md        # SonarQube integration guide
    ├── setup-trivy.md            # Trivy scanning guide
    └── azure-monitor.md          # Azure Monitor alerts & diagnostics guide
```

---

## 4. Prerequisites

### 4.1 Azure Requirements
1. **Azure Subscription** with Owner/Contributor access.
2. **Azure DevOps Organization** + Project (for Azure DevOps pipeline).
3. **GitHub Account** + Repository (for GitHub Actions workflow).
4. **Azure Service Connection** in Azure DevOps:
   - Project Settings → Service Connections → New → Azure Resource Manager → Service Principal (Automatic).
   - Name it `azure-service-connection` (or update the pipeline variable).

### 4.2 SonarQube Requirements
1. **SonarQube Server** (self-hosted or SonarCloud).
   - SonarCloud: https://sonarcloud.io (free for open source).
   - Self-hosted: Docker image `sonarqube:lts-community`.
2. **SonarQube Project Token** stored in Azure DevOps / GitHub Secrets.
3. **SonarQube Service Connection** in Azure DevOps (if using Azure DevOps).

### 4.3 Trivy Requirements
1. Trivy is installed automatically in the pipeline via:
   - Azure DevOps: `AquasecurityTrivy@1` task or `trivy` CLI.
   - GitHub Actions: `aquasecurity/trivy-action`.
2. No external service needed — Trivy is a CLI scanner.

### 4.4 Local Tools (Optional)
```bash
# Azure CLI
az bicep install

# Node.js 20+
node -v  # Should be >= 20.0.0

# Docker (for local container testing)
docker -v

# Trivy (for local scanning)
brew install trivy  # macOS
```

---

## 5. Quick Start — Run Locally

```bash
# 1. Navigate to app
cd azure-cicd-poc/app

# 2. Install dependencies
npm install

# 3. Run tests with coverage
npm test

# 4. Start the server
npm start
```

Open [http://localhost:3000](http://localhost:3000) and [http://localhost:3000/health](http://localhost:3000/health).

### Local SonarQube Scan (Optional)
```bash
# Requires SonarQube server running and sonar-scanner CLI
sonar-scanner \
  -Dsonar.projectKey=hello-world-azure \
  -Dsonar.sources=src \
  -Dsonar.tests=tests \
  -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
```

### Local Trivy Scan (Optional)
```bash
# Scan the Dockerfile / container image
cd azure-cicd-poc/app
docker build -t hello-world-azure:test .
trivy image hello-world-azure:test

# Scan the source code for secrets and vulnerabilities
trivy filesystem --scanners vuln,secret,config .
```

---

## 6. Azure DevOps Pipeline Setup

### 6.1 Create the Pipeline
1. In Azure DevOps, go to **Pipelines → Create Pipeline**.
2. Select **Azure Repos Git** (or **GitHub** if using GitHub repo).
3. Choose this repository.
4. Select **Existing Azure Pipelines YAML file**.
5. Path: `/pipelines/azure-pipelines.yml`.
6. Save and run.

### 6.2 Required Pipeline Variables / Secrets
Set these in **Pipelines → Library → Variable Groups** or as pipeline variables:

| Variable | Example | Purpose |
|----------|---------|---------|
| `azureServiceConnection` | `azure-service-connection` | Azure DevOps service connection name |
| `subscriptionId` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | Azure subscription ID |
| `location` | `eastus` | Azure region |
| `appName` | `hello-world-dev` | Base name for resources |
| `environment` | `dev` | Environment label |
| `sonarQubeServiceConnection` | `sonar-qube-conn` | SonarQube service connection name |
| `sonarQubeProjectKey` | `hello-world-azure` | SonarQube project key |

For **SonarQube token**, add it as a secret variable: `SONAR_TOKEN`.

### 6.3 Pipeline Stages Explained

```
┌─────────────────┐     ┌─────────────────────────────────────────────┐     ┌─────────────────────────────────────────────┐
│   Trigger       │────►│   Stage 1: BUILD & SECURE                   │────►│   Stage 2: DEPLOY & MONITOR                 │
│   (main)        │     │   ───────────────────────────────            │     │   ───────────────────────────────            │
│                 │     │   1. npm install                              │     │   1. Bicep Provision Infra                  │
│                 │     │   2. npm test (Jest + coverage)               │     │      • App Service                          │
│                 │     │   3. SonarQube Scan (SAST)                    │     │      • Monitoring                           │
│                 │     │   4. Docker Build                             │     │      • Azure Monitor Alerts                   │
│                 │     │   5. Trivy Scan (CVE + Secrets)               │     │   2. Deploy Zip to Web App                  │
│                 │     │   6. Publish Artifact                         │     │   3. Smoke Test                             │
│                 │     │                                               │     │   4. Verify Alerts                            │
└─────────────────┘     └─────────────────────────────────────────────┘     └─────────────────────────────────────────────┘
```

### Stage 1: Build & Secure (`build_job`)
- **Checkout:** Clean fetch of source code.
- **Node Install:** `npm ci` for reproducible builds.
- **Lint:** `npm run lint` (optional, can be enforced later).
- **Test:** `npm test` with Jest; failures block the pipeline.
- **Publish Coverage:** JUnit test results + Cobertura code coverage uploaded to Azure DevOps.
- **SonarQube Scan:** Static analysis of code quality, security hotspots, and coverage gate.
- **Docker Build:** Build container image for Trivy scanning (and optional ACR push).
- **Trivy Scan:** Scan the built image for:
  - **OS vulnerabilities** (CVEs in `node:20-alpine` base image)
  - **Application vulnerabilities** (NPM dependency CVEs)
  - **Secrets** (accidentally committed keys, tokens)
  - **Misconfigurations** (Dockerfile security best practices)
- **Package:** Create `app.zip` artifact for deployment.

### Stage 2: Deploy & Monitor (`deploy_job`)
- **Depends On:** `Build` must succeed AND SonarQube quality gate must pass AND Trivy must not find CRITICAL vulnerabilities.
- **Bicep Deploy:** `az deployment sub create` using the service connection. Provisions:
  - Resource Group
  - App Service Plan (Linux B1)
  - Web App (Node 20, HTTPS-only, TLS 1.2, System-assigned MI)
  - Log Analytics Workspace + Application Insights
  - Azure Monitor Alerts (HTTP 5xx rate, CPU > 80%, Memory > 80%)
  - Diagnostic Settings (Web App logs → Log Analytics)
- **App Deploy:** `AzureWebApp@1` task deploys `app.zip` via Zip Deploy.
- **Smoke Test:** Curl the `/health` endpoint with 10 retries to validate deployment.
- **Alert Verification:** Query Azure Monitor to confirm alerts are active.

---

## 7. GitHub Actions Setup

### 7.1 Add Workflow to GitHub
1. Copy `pipelines/github-actions.yml` to `.github/workflows/azure-deploy.yml` in your GitHub repo.
2. Add the following **GitHub Secrets** in Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AZURE_CREDENTIALS` | JSON service principal credentials (from `az ad sp create-for-rbac`) |
| `SONAR_TOKEN` | SonarQube/SonarCloud token |
| `SONAR_HOST_URL` | `https://sonarcloud.io` or your SonarQube URL |
| `SONAR_PROJECT_KEY` | `hello-world-azure` |

### 7.2 GitHub Actions Workflow
The workflow is structurally identical to the Azure DevOps pipeline:
- **Build job:** Checkout → Node setup → Test → SonarQube → Trivy scan → Upload artifact.
- **Deploy job:** Azure login → Bicep deploy → Deploy to Web App → Smoke test.

See `pipelines/github-actions.yml` for the full implementation.

---

## 8. SonarQube Integration Details

### 8.1 What SonarQube Scans
| Category | Checks |
|----------|--------|
| **Bugs** | Null pointer risks, infinite loops, logical errors |
| **Vulnerabilities** | SQL injection, XSS, insecure crypto, hardcoded secrets |
| **Code Smells** | Duplication, complexity, maintainability issues |
| **Security Hotspots** | Areas requiring security review (e.g., CORS config) |
| **Coverage** | Unit test line/branch coverage (Jest → LCOV) |
| **Quality Gate** | Configurable pass/fail criteria (e.g., 80% coverage, 0 new vulnerabilities) |

### 8.2 SonarQube Configuration
See `app/sonar-project.properties`:
```properties
sonar.projectKey=hello-world-azure
sonar.sources=src
sonar.tests=tests
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.testExecutionReportPaths=coverage/junit.xml
sonar.exclusions=node_modules/**,coverage/**,tests/**
```

### 8.3 Pipeline Task (Azure DevOps)
```yaml
- task: SonarQubePrepare@5
  inputs:
    SonarQube: '$(sonarQubeServiceConnection)'
    scannerMode: 'CLI'
    configMode: 'manual'
    cliProjectKey: '$(sonarQubeProjectKey)'
    cliSources: 'app/src'
    extraProperties: |
      sonar.javascript.lcov.reportPaths=$(appPath)/coverage/lcov.info

- task: SonarQubeAnalyze@5

- task: SonarQubePublish@5
  inputs:
    pollingTimeoutSec: '300'
```

### 8.4 GitHub Actions Step
```yaml
- name: SonarQube Scan
  uses: SonarSource/sonarqube-scan-action@v2
  with:
    projectBaseDir: ./app
    args: >
      -Dsonar.projectKey=${{ secrets.SONAR_PROJECT_KEY }}
      -Dsonar.javascript.lcov.reportPaths=./coverage/lcov.info
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

---

## 9. Trivy Integration Details

### 9.1 What Trivy Scans
| Scanner | Target | Purpose |
|---------|--------|---------|
| **Vulnerability** | OS packages + app dependencies | CVE detection in base image and NPM packages |
| **Secret** | Entire filesystem | Detect accidentally committed API keys, passwords, tokens |
| **Config** | Dockerfile, IaC files | Misconfigurations (e.g., running as root, missing health checks) |

### 9.2 Trivy in Azure DevOps Pipeline
```yaml
- task: AquasecurityTrivy@1
  displayName: 'Trivy Container Scan'
  inputs:
    image: 'hello-world-azure:$(Build.BuildId)'
    severity: 'CRITICAL,HIGH'
    exitCode: '1'  # Fail pipeline on CRITICAL
```

### 9.3 Trivy in GitHub Actions
```yaml
- name: Trivy Scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'hello-world-azure:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

### 9.4 Trivy SARIF Upload to GitHub Security Tab (GitHub Actions only)
```yaml
- name: Upload Trivy SARIF
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

---

## 10. Azure Monitor Integration Details

### 10.1 What Azure Monitor Provides
| Component | Purpose |
|-----------|---------|
| **Log Analytics Workspace** | Centralized log ingestion and querying (KQL) |
| **Application Insights** | APM, distributed tracing, performance metrics, failure analysis |
| **Diagnostic Settings** | Native Azure resource logs (HTTP logs, app logs) forwarded to Log Analytics |
| **Azure Monitor Alerts** | Proactive notifications based on metric thresholds or log queries |

### 10.2 Bicep Modules for Monitoring

#### `modules/monitoring.bicep`
- Log Analytics Workspace (`PerGB2018` SKU, 30-day retention).
- Application Insights (linked to Log Analytics, `web` kind).

#### `modules/alerts.bicep` (NEW)
- **HTTP 5xx Rate Alert:** Fires when > 5% of requests return 5xx over 5 minutes.
- **High CPU Alert:** Fires when CPU usage > 80% for 5 minutes.
- **High Memory Alert:** Fires when memory usage > 80% for 5 minutes.
- **Action Group:** Sends email to ops team and triggers a webhook.

#### `modules/diagnostics.bicep` (NEW)
- Diagnostic Settings on Web App:
  - AppServiceConsoleLogs
  - AppServiceHTTPLogs
  - AppServiceAppLogs
  - All forwarded to Log Analytics Workspace.

### 10.3 Sample KQL Queries
Run these in **Log Analytics → Logs**:

```kql
// Failed requests in the last hour
AppServiceHTTPLogs
| where ScStatus >= 500
| summarize count() by bin(TimeGenerated, 5m), CsUriStem
| render timechart

// Application exceptions
exceptions
| where timestamp > ago(1h)
| summarize count() by problemId

// Custom application logs
traces
| where message contains "error" or message contains "exception"
| order by timestamp desc
```

---

## 11. Swapping to Another Runtime

The Bicep module uses `linuxFxVersion` to set the runtime. Change it in `infra/modules/appService.bicep`:

| Runtime | `linuxFxVersion` Value |
|---------|------------------------|
| Node 20 | `NODE|20-lts` |
| .NET 8  | `DOTNETCORE|8.0` |
| Python 3.11 | `PYTHON|3.11` |
| Java 17 | `JAVA|17-java17` |
| Docker | `DOCKER\|ghcr.io/...` (use ACR) |

Then update the `BUILD` stage commands (e.g., `dotnet build` instead of `npm ci`).

---

## 12. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Bicep over Terraform** | Native Azure tooling, zero state file management, seamless ARM integration. |
| **Zip Deploy over Container** | Faster inner-loop for hello-world; container path is documented for scale. |
| **Subscription-level deployment** | Allows creating the Resource Group as part of IaC, keeping everything declarative. |
| **System-assigned Managed Identity** | Future-proof: no secrets needed for Azure SQL, Storage, or Key Vault access. |
| **SonarQube + Trivy** | Dual-layer security: SAST for code quality + container scanning for runtime vulnerabilities. |
| **Azure Monitor Alerts in Bicep** | Alerts are infrastructure, not configuration drift. Declarative alert definitions. |
| **Diagnostic Settings in Bicep** | Ensures every resource is observable from creation, not retrofitted. |
| **Separate parameter files** | Clean environment promotion (`dev.bicepparam` → `uat.bicepparam` → `prod.bicepparam`). |

---

## 13. Next Steps to Production-ize

1. **Add Environments:** Create `uat.bicepparam` and `prod.bicepparam`; add deployment stages with Azure DevOps environment approvals.
2. **Key Vault Integration:** Store app settings in Key Vault; reference them via `@Microsoft.KeyVault` in App Service.
3. **Azure SQL:** Add a `sqlDatabase.bicep` module; connect Web App to SQL via Managed Identity.
4. **APIM:** Add `apiManagement.bicep` to front the Web App with policies, rate limiting, and developer portal.
5. **Private Endpoints:** VNet-integrate the Web App and add private endpoints for PaaS resources.
6. **Blue-Green Deployments:** Use Azure App Service deployment slots for zero-downtime releases.
7. **SAST/DAST Expansion:** Add OWASP ZAP or Microsoft Defender for DevOps for DAST.
8. **Cost Alerts:** Configure Azure Budgets and Cost Management alerts for the dev environment.
9. **GitHub Advanced Security:** Enable secret scanning, dependency review, and code scanning in the GitHub repo.
10. **WAF:** Add Azure Front Door with WAF (OWASP 3.2) in front of the App Service.

---

## 14. Troubleshooting

| Issue | Solution |
|-------|----------|
| `az bicep` not found | Run `az bicep install` or use the Azure CLI task in the pipeline (Bicep built-in). |
| Web App shows "Service Unavailable" | Check `npm start` in `package.json` and `WEBSITE_RUN_FROM_PACKAGE=1` is set. |
| Pipeline fails on `AzureWebApp` task | Verify service connection has **Contributor** role on the target subscription. |
| Bicep deployment fails | Run `az deployment sub validate` before `create` to catch parameter errors. |
| Port binding issues | App must listen on `process.env.PORT \|\| 3000`; Azure assigns a dynamic port. |
| SonarQube scan fails | Verify `SONAR_TOKEN` is set and SonarQube server is reachable from the pipeline agent. |
| Trivy scan fails | Check if the Docker image was built successfully before the Trivy step. |
| Azure Monitor alerts not firing | Verify diagnostic settings are active and the alert scope matches the resource. |

---

*End of README*
