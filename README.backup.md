# AZ-204 ConferenceHub Student Guide

This repository is organized as progressive learning paths. You run each path from its branch in order.

## Prerequisites
- Git
- .NET SDK 9
- Azure CLI (`az`) logged in
- Bash (macOS/Linux)

## How This Repo Works
- `ConferenceHub/` is the shared app code.
- Each learning path branch (`lp/*`) adds the next topic.
- Each path has its own deployment script: `LearningPath/<NN-Name>/create.sh`.
- Do not create pull requests between `lp/*` branches and `main`; branch differences are intentional for step-by-step learning.

## Student Workflow (Recommended)
Clone once, then switch branches as you progress.

```bash
git clone https://github.com/theDiverDK/AZ-204-Demo.git
cd AZ-204-Demo
git fetch --all --prune
```

Run learning paths in this order:

1. `lp/01-init`
This creates the baseline Azure hosting for ConferenceHub (resource group, plan, web app) and deploys the app.
Use this as the starting point for all later paths.
Test by opening the site, browsing sessions, and submitting one registration.
```bash
git switch --track origin/lp/01-init
cd LearningPath/01-Init
./create.sh
cd ../..
```

2. `lp/02-functions`
This adds Azure Functions for confirmation handling and updates the web app to call the function endpoint.
Registrations now go through the function flow instead of only local app logic.
Test by registering and checking Function App logs for the confirmation payload.
```bash
git switch lp/02-functions || git switch --track origin/lp/02-functions
cd LearningPath/02-Functions
./create.sh
cd ../..
```

3. `lp/03-storage`
This adds Blob Storage support for session slide uploads (multiple files per session).
Organizer uploads are stored in Azure Storage and linked from session details.
Test by uploading PDF/JPG slides as organizer and opening links from the session page.
```bash
git switch lp/03-storage || git switch --track origin/lp/03-storage
cd LearningPath/03-Storage
./create.sh
cd ../..
```

4. `lp/04-cosmos`
This switches data persistence to Cosmos DB for sessions and registrations.
The migration step imports existing seed sessions so the app can run immediately on Cosmos.
Test by registering users and verifying data/count changes in Cosmos containers.
```bash
git switch lp/04-cosmos || git switch --track origin/lp/04-cosmos
cd LearningPath/04-Cosmos
./create.sh
./migrate.sh
cd ../..
```

5. `lp/05-container`
This demonstrates container-based deployment for the web app.
The script builds/publishes and deploys ConferenceHub in container hosting configuration.
Test by opening the deployed app and verifying normal browse/register behavior.
```bash
git switch lp/05-container || git switch --track origin/lp/05-container
cd LearningPath/05-Container
./create.sh
cd ../..
```

6. `lp/06-auth`
This enables Microsoft Entra ID authentication and role-based authorization.
Registration requires login, and organizer-only features are restricted by role.
Test by signing in as user vs organizer and confirming UI/action differences.
```bash
git switch lp/06-auth || git switch --track origin/lp/06-auth
cd LearningPath/06-Auth
./create.sh
cd ../..
```

7. `lp/07-keyvault`
This moves sensitive settings to Azure Key Vault and uses managed identity + RBAC access.
App secrets are resolved from Key Vault references instead of plain app settings values.
Test by confirming app still works and Key Vault reference resolution is successful in web app settings.
```bash
git switch lp/07-keyvault || git switch --track origin/lp/07-keyvault
cd LearningPath/07-KeyVault
./create.sh
cd ../..
```

> Note: `lp/08-apim` is intentionally not included right now. For the current ConferenceHub architecture, an APIM step does not add meaningful value, so this section is omitted on purpose.


8. `lp/09-events`
This introduces event-driven behavior with Event Grid/Event Hub integrations.
Events are emitted and processed when app actions occur (for example slide-related activity).
Test by triggering event-producing actions and validating downstream processing/logs.
```bash
git switch lp/09-events || git switch --track origin/lp/09-events
cd LearningPath/09-Events
./create.sh
cd ../..
```

9. `lp/10-messages`
This adds asynchronous messaging with Service Bus and Queue Storage.
Work is decoupled into message handlers (for example registration email flow and thumbnail jobs).
Test by performing actions that enqueue messages and verifying consumers process them.
```bash
git switch lp/10-messages || git switch --track origin/lp/10-messages
cd LearningPath/10-Messages
./create.sh
cd ../..
```

10. `lp/11-appinsight`
This enables full observability with Application Insights across app and functions.
Dependency/custom telemetry and distributed traces are configured for end-to-end visibility.
Test by running core flows, then confirming traces/dependencies in Application Map and Logs.
```bash
git switch lp/11-appinsight || git switch --track origin/lp/11-appinsight
cd LearningPath/11-AppInsight
./create.sh
cd ../..
```

## What Each Learning Path Adds

### LP1 (`lp/01-init`)
- Demonstrates: baseline App Service deployment of ConferenceHub.
- `create.sh` adds/updates: resource group, app service plan, web app, app build/publish/deploy, then opens the site.

### LP2 (`lp/02-functions`)
- Demonstrates: Azure Functions integration for confirmation flow.
- `create.sh` adds/updates: function app resources, function deployment, web app settings for function endpoint/key, and redeploys the web app with function calling enabled.

### LP3 (`lp/03-storage`)
- Demonstrates: Azure Blob Storage for session slide uploads.
- `create.sh` adds/updates: storage account + containers for slides, web app settings for storage usage, and redeploys web app with upload/view support.

### LP4 (`lp/04-cosmos`)
- Demonstrates: Cosmos DB as app data store.
- `create.sh` adds/updates: Cosmos account, database, sessions/registrations containers, web app Cosmos settings.
- `migrate.sh` adds/updates: imports seed session data into Cosmos.

### LP5 (`lp/05-container`)
- Demonstrates: containerized deployment path.
- `create.sh` adds/updates: container-related hosting resources and deploys ConferenceHub container image to Azure hosting.

### LP6 (`lp/06-auth`)
- Demonstrates: Entra ID authentication/authorization.
- `create.sh` adds/updates: auth configuration for web app, app settings for tenant/client configuration, and deploys role-aware app behavior.

### LP7 (`lp/07-keyvault`)
- Demonstrates: secret/key management via Key Vault with managed identity and RBAC.
- `create.sh` adds/updates: key vault, role assignments, secret references, and replaces direct sensitive app settings with Key Vault-backed values.

### LP9 (`lp/09-events`)
- Demonstrates: event-driven integration using Event Grid/Event Hub.
- `create.sh` adds/updates: event infrastructure subscriptions/endpoints and app/function settings for event publishing/handling.

### LP10 (`lp/10-messages`)
- Demonstrates: asynchronous messaging with Service Bus and Queue Storage.
- `create.sh` adds/updates: messaging resources, function triggers/bindings deployment, and app settings so registration/thumbnail jobs flow through queues/topics.

### LP11 (`lp/11-appinsight`)
- Demonstrates: full observability with Application Insights.
- `create.sh` adds/updates: shared Application Insights connection across apps/functions, sampling disabled, telemetry settings, and redeploys for dependency/custom-event visibility.

## Verify Current State
- Current branch: `git branch --show-current`
- Local branches: `git branch --list`

## Cleanup Azure Resources
From repo root:

```bash
./cleanup.sh
```

This deletes the resource group and purges soft-deleted resources (including Key Vault).

## Optional: Worktrees (Advanced)
If you want all learning paths checked out at once, use:

```bash
./tools/worktrees.sh
```
