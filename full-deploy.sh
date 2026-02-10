#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

git fetch --all --prune

clean_artifacts() {
  rm -rf "$script_dir/ConferenceHub/publish"
  rm -f "$script_dir/ConferenceHub/app.zip"
  rm -rf "$script_dir/.deploy"
}

run_lp() {
  local branch="$1"
  local folder="$2"

  echo ""
  echo "========== Running ${branch} (${folder}) =========="

  git switch "$branch" || git switch --track "origin/$branch"

  clean_artifacts

  cd "$folder"
  NO_BROWSE=1 ./create.sh
  cd "$script_dir"
}

run_lp "lp/01-init" "LearningPath/01-Init"
run_lp "lp/02-functions" "LearningPath/02-Functions"
run_lp "lp/03-storage" "LearningPath/03-Storage"

run_lp "lp/04-cosmos" "LearningPath/04-Cosmos"
cd "LearningPath/04-Cosmos"
./migrate.sh
cd "$script_dir"

run_lp "lp/05-container" "LearningPath/05-Container"
run_lp "lp/06-auth" "LearningPath/06-Auth"
run_lp "lp/07-keyvault" "LearningPath/07-KeyVault"
run_lp "lp/09-events" "LearningPath/09-Events"
run_lp "lp/10-messages" "LearningPath/10-Messages"
run_lp "lp/11-appinsight" "LearningPath/11-AppInsight"

source "$script_dir/tools/variables.sh"
az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

echo ""
echo "All learning paths deployed successfully."
