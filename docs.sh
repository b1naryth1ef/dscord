#!/bin/bash

DFLAGS='-c -o- -Df__dummy.html -Xfdocs.json' dub build
dub fetch scod
dub run scod -- filter --min-protection=Protected docs.json
dub run scod -- generate-html --navigation-type=ModuleTree docs.json docs
# pkg_path=$(dub list | sed -n 's|.*scod.*: ||p')
# rsync -ru "$pkg_path"public/ docs/

if [ ! -z "${GH_TOKEN:-}" ]; then
  pushd docs
  git init
  git config user.name "AutoDoc"
  git config user.email "<>"
  git add .
  git commit -m "Generated Documentation"
  git push --force --quiet "https://${GH_TOKEN}@github.com/b1naryth1ef/dscord" master:gh-pages
  popd
fi
