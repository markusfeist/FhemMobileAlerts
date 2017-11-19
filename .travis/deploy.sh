#!/bin/bash
set -e # Exit with nonzero exit code if anything fails
MY_PATH="`dirname \"$0\"`"

function doCompile {
  perl $MY_PATH/../MakeUpd.pl
}

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "develop" ]; then
    echo "Skipping deploy $TRAVIS_PULL_REQUEST $TRAVIS_BRANCH."
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Run our compile script
doCompile

# Now let's go have some fun with the cloned repo
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if git diff --quiet $MY_PATH/../controls_mobilealerts.txt; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add -v -A $MY_PATH/../controls_mobilealerts.txt
git commit -v -m "Travis build $TRAVIS_BUILD_NUMBER update Controlfile"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
#ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
#ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
#ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
#ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
#openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in $MY_PATH/deploy_key.enc -out ../deploy_key -d
chmod 600 $MY_PATH/travis_id_rsa
eval `ssh-agent -s`
ssh-add $MY_PATH/travis_id_rsa

# Now that we're all set up, we can push.
git push -v $SSH_REPO $TRAVIS_BRANCH
