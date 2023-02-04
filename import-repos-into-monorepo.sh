#!/bin/bash
#
# Create a new monorepo by fusing multiple repositories.
#
# Exit immediately if a command exits with a non-zero status,
# and print commands and their arguments as they are executed.
set -ex

# Set the name of the org, and the monorepo to create
GITHUB_ORG="github-org-or-account"
MONOREPO_NAME="test-monorepo"

if [ -d "${MONOREPO_NAME}" ]; then
    echo "Directory ${MONOREPO_NAME} already exists!"
    exit -1 # Can be commented out to try multiple times
    rm -rf "${MONOREPO_NAME}"
fi

# Create the monorepo folder, init, and make a first
# commit (which is needed before we can merge in repos).
########################################################

mkdir ${MONOREPO_NAME}
cd ${MONOREPO_NAME}
git init

echo "this-will-be-removed" > this-will-be-removed
git add this-will-be-removed
git commit -m "this-will-be-removed"


# Phase 1: Setup all repos to be imported
#########################################

function setup_repos() {
    TARGET_FOLDER="$1"
    IMPORT_REPOS="$2"

    for REPO in ${IMPORT_REPOS}; do
        git remote add "${REPO}" "https://github.com/${GITHUB_ORG}/${REPO}.git"
    done
}

# Phase 2: Import each repos into a seperate branch and then rewrite
# their commit history to fit in with the monorepo folder structure.
####################################################################

function rewrite_history() {
    TARGET_FOLDER="$1"
    IMPORT_REPOS="$2"

    # Checkout all the master branches of the child repositories
    for REPO in ${IMPORT_REPOS}; do
            git checkout -f -b "${REPO}_master" "${REPO}/master"
            # Rewrite history to move all REPO files into a subdirectory
            export SUBDIRECTORY="${TARGET_FOLDER}/${REPO}"
            FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --index-filter '\
                git ls-files -s | gsed "s#\t#&'"${SUBDIRECTORY}"'/#g" \
                    | GIT_INDEX_FILE=${GIT_INDEX_FILE}.new git update-index --index-info && \
                        if [ -f "${GIT_INDEX_FILE}.new" ]; then \
                            mv "${GIT_INDEX_FILE}.new" "${GIT_INDEX_FILE}"; \
                        fi' --
    done
}

# Phase 3: Merge all repos and their rewritten histories into the monorepo
##########################################################################

function merge_repos() {
    TARGET_FOLDER="$1"
    IMPORT_REPOS="$2"

    # Merge all the repositories in our master branch.
    for REPO in ${IMPORT_REPOS}; do
        git merge --no-commit --allow-unrelated-histories "${REPO}_master"
        git commit -a -m \
            "Import ${REPO} from https://github.com/${GITHUB_ORG}/${REPO}.git to ${TARGET_FOLDER}/${REPO}" \
            || echo "Nothing to do"
    done

    # remove all child REPO branches and remotes
    for REPO in ${IMPORT_REPOS}; do
        git branch -D "${REPO}_master"
        git remote remove "${REPO}"
    done
}

# Execute Phase 1
setup_repos "apps/ts" "my-ts-app another-ts-app third-ts-app"
setup_repos "apps/py" "py-server py-app another-py-app"
setup_repos "apps/tools" "misc-tool-repo another-tool etc-etc-etc"

# Execute Phase 2
git fetch --all
rewrite_history "apps/ts" "my-ts-app another-ts-app third-ts-app"
rewrite_history "apps/py" "py-server py-app another-py-app"
rewrite_history "apps/tools" "misc-tool-repo another-tool etc-etc-etc"

# Execute Phase 3
git checkout -b master
merge_repos "apps/ts" "my-ts-app another-ts-app third-ts-app"
merge_repos "apps/py" "py-server py-app another-py-app"
merge_repos "apps/tools" "misc-tool-repo another-tool etc-etc-etc"

# Finally, prune all history and do an aggressive gc
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Finish up by creating a new README in the root directory!
###########################################################

MONOREPO_URL="https://github.com/${GITHUB_ORG}/${MONOREPO_NAME}.git"
echo "# ${MONOREPO_NAME}" > README.md
git add README.md
git commit -m "Finished creating ${MONOREPO_URL}"
git remote add ${MONOREPO_NAME} ${MONOREPO_URL}

# Print instructions for how to force push the new monorepo.
############################################################
set +x

CWD=`pwd`
echo
echo "  Done! Finish up by --force pushing the new repo:"
echo
echo "      cd ${CWD}"
echo "      git push --force ${MONOREPO_NAME} master"
echo