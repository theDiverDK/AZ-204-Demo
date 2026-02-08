# Instructor Runbook

This guide is for running the AZ-204 demo end-to-end in class.

## 1) Clone and Prepare

```bash
git clone https://github.com/theDiverDK/AZ-204-Demo.git
cd AZ-204-Demo
```

Prerequisites:
- .NET SDK 9
- Azure CLI (`az login` already done)
- Bash

Optional (recommended for instructors): create all worktrees once so all LPs are available side-by-side.

```bash
./tools/worktrees.sh
git worktree list
```

## 2) Teaching Flow
Run learning paths in order. Each path assumes previous paths are already deployed.

## 3) Deploy + Demo per Learning Path

LP1 Init
```bash
cd worktrees/01-init/LearningPath/01-Init
./create.sh
```
Demo: browse app, show sessions and registration basics.

LP2 Functions
```bash
cd ../../02-functions/LearningPath/02-Functions
./create.sh
```
Demo: registration triggers Function-based confirmation.

LP3 Storage
```bash
cd ../../03-storage/LearningPath/03-Storage
./create.sh
```
Demo: organizer uploads slides, users open slide links.

LP4 Cosmos
```bash
cd ../../04-cosmos/LearningPath/04-Cosmos
./create.sh
./migrate.sh
```
Demo: sessions and registrations stored/read from Cosmos DB.

LP5 Container
```bash
cd ../../05-container/LearningPath/05-Container
./create.sh
```
Demo: app running from container deployment.

LP6 Auth
```bash
cd ../../06-auth/LearningPath/06-Auth
./create.sh
```
Demo: sign-in required for registration, organizer authorization.

LP7 Key Vault
```bash
cd ../../07-keyvault/LearningPath/07-KeyVault
./create.sh
```
Demo: secrets loaded from Key Vault via managed identity.

LP9 Events
```bash
cd ../../09-events/LearningPath/09-Events
./create.sh
```
Demo: Event Grid/Event Hub flow for slide/activity events.

LP10 Messages
```bash
cd ../../10-messages/LearningPath/10-Messages
./create.sh
```
Demo: Service Bus + Queue Storage processing.

LP11 App Insights
```bash
cd ../../11-appinsight/LearningPath/11-AppInsight
./create.sh
```
Demo: Application Map, dependency traces, custom telemetry.

## 4) Between Learning Paths
- Confirm branch/worktree: `git branch --show-current`
- Pull updates if needed: `git pull`
- Re-run same path script if configuration drift occurs.

## 5) Cleanup After Class
From repo root (`main`):

```bash
./cleanup.sh
```

This deletes the resource group and purges soft-deleted resources (including Key Vault).
