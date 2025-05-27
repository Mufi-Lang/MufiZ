#!/bin/bash

# Overwrite the CHANGELOG.md with the header
echo "# Changelog" > CHANGELOG.md

# Append the commit log in the desired format
git log --oneline --decorate --date=short --pretty=format:"- **%h** *%s* (%ad)" >> CHANGELOG.md
