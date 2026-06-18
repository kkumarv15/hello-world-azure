# Trivy Container Security Scan Guide

## What Trivy Scans
| Scanner | Target | Purpose |
|---------|--------|---------|
| **Vulnerability** | OS packages + app dependencies | CVE detection in base image and NPM/YARN packages |
| **Secret** | Entire filesystem | Detect accidentally committed API keys, passwords, tokens |
| **Config** | Dockerfile, IaC files | Misconfigurations (e.g., running as root, missing health checks) |

## Local Usage
```bash
# Install Trivy on macOS
brew install trivy

# Scan a Docker image
docker build -t hello-world-azure:test .
trivy image hello-world-azure:test

# Scan source code (no build required)
cd azure-cicd-poc/app
trivy filesystem --scanners vuln,secret,config .

# Generate SARIF output
trivy image --format sarif --output trivy-results.sarif hello-world-azure:test
```

## Pipeline Integration
### Azure DevOps
The `AquasecurityTrivy@1` task scans the built container image:
```yaml
- task: AquasecurityTrivy@1
  inputs:
    image: '$(appName):$(Build.BuildId)'
    severity: 'CRITICAL,HIGH'
    exitCode: '1'
```

The `exitCode: '1'` fails the pipeline if any CRITICAL or HIGH vulnerabilities are found.

### GitHub Actions
The `aquasecurity/trivy-action` scans and outputs SARIF for the GitHub Security tab:
```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'hello-world:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

Results appear under GitHub → Security → Code scanning alerts.