#!/bin/bash

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline
 
TIMESTAMP=$(date +"%Y%m%d")
S3_ENDPOINT="https://eu-central-1.linodeobjects.com"
S3_BUCKET="backups"

MYSQL=/usr/bin/mysql
RSYNC=/bin/rsync
MYSQLDUMP=/usr/bin/mysqldump
FIND=/bin/find
AWS="/usr/bin/aws"

usage()
{
    cat << EOF
Usage:
    -h|--help                  Displays this help
    -v|--verbose               Displays verbose output
    -l|--local                 Store backup locally
    -a|--archive               Store backup in a tarball (.tar.gz)
    -r|--remove-old            Remove old locally stored backups
    -d|--directory             Output directory
EOF
}

parseParams() {
    local param

    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h | --help)
                usage
                exit 0
                ;;
            -v | --verbose)
                verbose=true
                ;;
            -l | --local)
                local=true
                ;;
            -a | --archive)
                archive=true
                ;;
            -r | --remove-old)
                remove_old=true
                ;;
            -d | --directory)
                directory="$1"
                shift
                ;;
            *)
                echo "Invalid argument $param"
                exit 1
                ;;
        esac
    done
}

main()
{
    source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/.backup_credentials.local"

    parseParams "$@"

    scriptPath="${BASH_SOURCE[1]}"
    scriptDir="$(dirname "$scriptPath")"

    if [[ ! -n ${directory-} ]]; then
        BACKUP_DIR="${scriptDir}/${TIMESTAMP}"
    else
        BACKUP_DIR="${directory}/${TIMESTAMP}"
    fi

    if [[ -n ${remove_old-} ]]; then
        scriptOutput "Removing old archives"
        removeOldBackups
        exit 0;
    fi

    backup
}


main "$@"



