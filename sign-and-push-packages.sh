#!/bin/bash
# Adds RPM packages passed as arguments to the repository and signs them using the repositories GPG key
# Requires RPM_SIGNING_KEY environment variable to be imported from a GitHub secret

export GPG_TTY=$(tty)
REPOSITORY_DIR=$(dirname "$(readlink -f "$0")")

# Import private signing key from an environment variable
echo "${RPM_SIGNING_KEY}" | gpg --import -

# Sign RPM packages
for FILE in "$@"; do
    REPOSITORY_FILE="${REPOSITORY_DIR}/Packages/$(basename "${FILE}")"
    cp "${FILE}" "${REPOSITORY_FILE}"
    echo "Signing ${REPOSITORY_FILE}"
    rpm --addsign \
        --define "%_signature gpg" \
        --define "%_gpg_path ${HOME}/.gnupg" \
        --define "%_gpg_name 6A35D8BB5AC20692F0F92E650852EDDC75AB35F6" \
        --define "%_gpg_bin /usr/bin/gpg" \
        "${REPOSITORY_FILE}"
done

# Update the repository metadata and push the updated state
cd "${REPOSITORY_DIR}" || exit 1

git config --local user.email "actions@github.com"
git config --local user.name "GitHub Actions"

git add --all
git commit -F-<<-END
Push from ${GITHUB_REPOSITORY}
Commit: ${GITHUB_SHA}
END

for i in $(seq 1 5);
do
    git push origin master
    if [ $? = 0 ] ; then
        break
    else
        # Another job has most likely pushed a commit in the meantime
        git fetch origin
        git rebase origin/master
    fi
done

