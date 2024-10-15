#!/bin/bash
set -eu

REPO_NAME=dmitrij

git -C /var/db/repos/${REPO_NAME}/ diff --cached | patch -p1
