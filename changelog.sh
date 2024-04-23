#!/bin/bash

git log --oneline --decorate --date=short --pretty=format:"- **%h** *%s* (%ad)" > CHANGELOG.md
