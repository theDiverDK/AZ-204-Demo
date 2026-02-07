# AZ-204 Demo with Git Worktrees

This repository keeps `ConferenceHub/` as the shared web app source of truth on `main`.
Learning path differences are implemented under `LearningPath/<NN-Name>/` and selected by branch.

## Branch and Folder Convention
- Branches: `lp/01-init`, `lp/02-functions`, `lp/03-storage`, `lp/04-cosmos`, `lp/05-container`, `lp/06-auth`, `lp/07-keyvault`, `lp/08-apim`, `lp/09-events`, `lp/10-messages`, `lp/11-appinsight`
- Folders: `LearningPath/01-Init`, `LearningPath/02-Functions`, `LearningPath/03-Storage`, `LearningPath/04-Cosmos`, `LearningPath/05-Container`, `LearningPath/06-Auth`, `LearningPath/07-KeyVault`, `LearningPath/08-Apim`, `LearningPath/09-Events`, `LearningPath/10-Messages`, `LearningPath/11-AppInsight`

## Create Worktrees
From repo root:

```bash
./tools/worktrees.sh
```

This creates local worktrees under `./worktrees/01-init` ... `./worktrees/11-appinsight`.

## Run a Learning Path
From a worktree (or any checkout on an `lp/*` branch):

```bash
./create.sh
```

`./create.sh` detects the current branch, loads `LearningPath/<NN-Name>/lp.env` if present, and executes `LearningPath/<NN-Name>/create.sh`.

## Learning Path 2 (Functions)
`LearningPath/02-Functions/create.sh` provisions and deploys:
- Resource Group
- App Service Plan + Web App for ConferenceHub
- Storage Account
- Function App (Node.js v4)
- Function code under `LearningPath/02-Functions/functions/`

It then sets Web App app settings:
- `API_MODE=functions`
- `FUNCTIONS_BASE_URL=https://<functionapp>.azurewebsites.net`
- `AzureFunctions__SendConfirmationUrl=<base>/api/SendConfirmation`

## Merge Main into Learning Path Branches
For each branch:

```bash
git checkout lp/02-functions
git merge main
```

Or update all worktrees by repeating merge in each `worktrees/lpXX` directory.
