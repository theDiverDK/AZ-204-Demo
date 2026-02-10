# AZ-204 ConferenceHub Demo

This repository is a progressive AZ-204 demo project.  
After each AZ-204 learning path, it demonstrates how that knowledge can be applied in a real project that evolves step by step.

It was created because Microsoft has unfortunately removed most demonstrations from the course.  
The goal is to give instructors and students a practical, cumulative demo they can run and learn from.

Each Learning Path (LP) builds on the previous one using the same shared app (`ConferenceHub/`).

## Community
You are very welcome to use this project for teaching, studying, and hands-on practice.

If you find problems or improvement opportunities, please:
- Open an issue
- Submit a pull request

## Prerequisites
- Git
- .NET SDK 9
- Azure CLI (`az`) logged in
- Bash (macOS/Linux)

## Repository Layout
- `ConferenceHub/`: shared ASP.NET Core web app used across all LPs.
- `LearningPath/<NN-Name>/create.sh`: deploy script for each LP.
- `LearningPath/04-Cosmos/migrate.sh`: seed migration to Cosmos DB.
- `full-deploy.sh`: runs all LPs in sequence.
- `cleanup.sh`: deletes deployed Azure resources and purges soft-deleted services.

## Learning Paths
- **LP1 (`lp/01-init`)**: baseline App Service deployment for ConferenceHub.
- **LP2 (`lp/02-functions`)**: Azure Functions for registration confirmation flow.
- **LP3 (`lp/03-storage`)**: Blob Storage for slide upload/view.
- **LP4 (`lp/04-cosmos`)**: Cosmos DB for sessions/registrations + migration step.
- **LP5 (`lp/05-container`)**: container deployment variant.
- **LP6 (`lp/06-auth`)**: Entra ID auth + role-based authorization.
- **LP7 (`lp/07-keyvault`)**: secrets moved to Key Vault with managed identity/RBAC.
- **LP8**: intentionally omitted.
- **LP9 (`lp/09-events`)**: Event Grid/Event Hub event-driven processing.
- **LP10 (`lp/10-messages`)**: Service Bus + Queue Storage messaging workflows.
- **LP11 (`lp/11-appinsight`)**: Application Insights observability and tracing.

## How to Use (Step-by-Step)
Clone and run LPs in order:

```bash
git clone https://github.com/theDiverDK/AZ-204-Demo.git
cd AZ-204-Demo
git fetch --all --prune
```

Per LP, switch branch and run the script:

```bash
git switch lp/01-init || git switch --track origin/lp/01-init
cd LearningPath/01-Init
./create.sh
cd ../..
```

Repeat with the matching branch/folder for LP2, LP3, ..., LP11.

## Full Deployment Script
Use this to deploy all LPs in sequence automatically:

```bash
./full-deploy.sh
```

What it does:
- Runs LP branches in order (`01, 02, 03, 04, 05, 06, 07, 09, 10, 11`).
- Executes each LP `create.sh`.
- Runs LP4 `migrate.sh`.
- Opens browser once at the end.

## Cleanup Script
Use this to remove demo resources when finished:

```bash
./cleanup.sh
```

What it does:
- Deletes the resource group.
- Waits for deletion completion (Cosmos DB can take >15 minutes).
- Purges soft-deleted Key Vault and App Configuration where applicable.

## Notes
- LP scripts are cumulative: run LPs in order.
- Avoid pull requests between LP branches and `main`; differences are intentional for teaching progression.
