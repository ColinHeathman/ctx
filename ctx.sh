#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
  cat >&2 <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [update | completion | PROJECT_ID/CLUSTER/REGION]

ctx quickly configures a kubeconfig for easy cluster access in gcloud shell

Commands:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
update          Update auto complete lists
completion      Print auto completion
PROJECT_ID/CLUSTER/REGION  set up context with given parameters
EOF
  exit 1
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  [ $# -eq 0 ] && usage
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -?*) die "Unknown option: $1" ;;
    completion) print_completion ;;
    update) update_autocomplete ;;
    *)
    project=$(echo -n "$1" | awk -F "/" '{print $1}')
    cluster=$(echo -n "$1" | awk -F "/" '{print $2}')
    region=$(echo -n "$1" | awk -F "/" '{print $3}')
    break
    ;;
    esac
    shift
  done

  # check required params and arguments
  [[ -z ${project} ]]  && die "Missing project"
  [[ -z ${cluster} ]]  && die "Missing cluster"
  [[ -z ${region} ]]  && die "Missing region"

  return 0
}

# shellcheck disable=SC2207
project_contexts() {
    ALL_ORGS=($(gcloud organizations list --format=json | jq -r '.[] | .name' | awk -F'/' '{print $2}'))
    PROJECT_PARENTS=( "${ALL_ORGS[@]}" )
    for ORG in "${ALL_ORGS[@]}"; do
      PROJECT_PARENTS+=($(gcloud resource-manager folders list "--organization=${ORG}" --format=json | jq -r '.[] | .name' | awk -F'/' '{print $2}'))
    done

    PROJECTS=($(gcloud projects list --filter="parent.id=(${PROJECT_PARENTS[*]})" --format=json | jq -r '.[] | .projectId')) 
    for project_id in "${PROJECTS[@]}" ; do
        if ! gcloud --project=${project_id} container clusters list > /dev/null 2> /dev/null; then
	    echo "skip ${project_id}"
	    continue
	fi
        gcloud	"--project=${project_id}" container clusters list --format=json | jq -r '.[] | "\(.name) \(.location)"' | while read -r cluster_info ; do
            cluster_id=$(echo "$cluster_info" | awk '{print $1}')
            region_id=$(echo "$cluster_info" | awk '{print $2}')
            [[ -n $project_id ]] && [[ -n $cluster_id ]] && [[ -n $region_id ]] && echo "$project_id/$cluster_id/$region_id" && msg "found ${CYAN}$project_id${NOFORMAT}/${PURPLE}$cluster_id${NOFORMAT}/${BLUE}$region_id${NOFORMAT}"
        done
    done
}

update_autocomplete() {
    msg "${YELLOW}setting up ${HOME}/.local/share/ctx/contexts.list, this can take around 60 seconds...${NOFORMAT}"
    mkdir -p "${HOME}/.local/share/ctx/"
    project_contexts > "${HOME}/.local/share/ctx/contexts.list"
    msg "${YELLOW}please run ${ORANGE}\`source <(ctx completion)\`${YELLOW} to update your current shell ${NOFORMAT}"
    exit 0
}

print_completion() {
    if [ ! -f "${HOME}/.local/share/ctx/contexts.list" ]; then
      update_autocomplete
    fi
    echo 'complete -W "$(xargs < ~/.local/share/ctx/contexts.list)" ctx'
    exit 0
}

setup_colors
parse_params "$@"

echo "${project}" "${cluster}" "${region}"
