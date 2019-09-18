#!/bin/bash

# Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Pre-requisites
# 1. install hub (https://hub.github.com/)

HOME=`pwd`
GITHUB_USERNAME=pram0dya
GITHUB_PASSWORD=Welcome1994hello
GITHUB_ORG=pramodya1994 # wso2
GITHUB_REPO=docs-ei
UPSTREAM_NAME=upstream

NEW_UUID=$(cat /dev/urandom |  LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
BRANCH_NAME=Docs-${NEW_UUID}

function send_pr {
    git commit -a -m "Add docs changes from ballerina-integrator"
    git push ${UPSTREAM_NAME} ${BRANCH_NAME}
    git request-pull ${BRANCH_NAME} https://github.com/${GITHUB_ORG}/${GITHUB_REPO} master
}

# build www project.
mvn clean install -f ${HOME}/pom.xml
# Run created a jar to create `mkdocs-content` directory.
java -jar $HOME/target/www-builder-1.0-jar-with-dependencies.jar

# Clone `docs-ei` repo.
git clone https://${GITHUB_USERNAME}:${GITHUB_PASSWORD}@github.com/${GITHUB_ORG}/${GITHUB_REPO}.git
cd ${GITHUB_REPO}

# Fork `docs-ei` repo.
hub fork
# Add upstream
git remote add ${UPSTREAM_NAME} https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}.git

# Checkout to new branch with the name `Docs-<32-character-length-uuid>`
git checkout -b ${BRANCH_NAME} master

# Copy `mkdocs-content` directory content to `docs-ei/en/ballerina-integrator/docs/` directory.
cp -r $HOME/target/mkdocs-content/* $HOME/docs-ei/en/ballerina-integrator/docs/

# Check `git status` to ensure docs change.
git_status=$(git status)
if [[ ${git_status} == *."nothing to commit, working tree clean".* ]]; then
    echo "No docs changes!"
    else
    echo "There are docs changes! Need to send a PR to 'https://github.com/wso2/docs-ei.git'"
    send_pr
fi
