# SonarQube Integration Guide

## Prerequisites
- SonarQube server (self-hosted) or SonarCloud account
- SonarQube project token with access to the project

## Option 1: SonarCloud (Recommended for POC)
1. Go to https://sonarcloud.io and sign in with GitHub/GitLab/Bitbucket.
2. Click **Analyze new project** and select your repository.
3. Generate a **token** (User → My Account → Security → Generate Tokens).
4. Save the token in:
   - **Azure DevOps:** Pipeline Library → Variable Group → Secret variable `SONAR_TOKEN`
   - **GitHub:** Settings → Secrets and variables → Actions → New secret `SONAR_TOKEN`
5. Set `SONAR_HOST_URL = https://sonarcloud.io`

## Option 2: Self-Hosted SonarQube (Docker)
```bash
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts-community
```
Then configure a service connection in Azure DevOps:
- Project Settings → Service Connections → New → SonarQube
- Server URL: `http://localhost:9000` or your server IP
- Authentication Token: from SonarQube Admin → My Account → Security

## Pipeline Configuration
### Azure DevOps
The pipeline uses three tasks:
1. `SonarQubePrepare@5` — configure project key, sources, coverage paths
2. `SonarQubeAnalyze@5` — run the scanner
3. `SonarQubePublish@5` — wait for the quality gate result (300s timeout)

### GitHub Actions
Uses `SonarSource/sonarqube-scan-action@v2` with `SONAR_TOKEN` and `SONAR_HOST_URL` secrets.