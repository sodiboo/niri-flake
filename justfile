# deps: fish, fd, entr, moreutils (sponge)

# i don't wanna deal with xargs
set shell := ["fish", "-c"]

current-system := `nix eval --impure --raw --expr builtins.currentSystem`
nom-path := `command -v nom || true`

nom-or-nix := if nom-path != "" { "nom" } else { "nix" }

default: check

fmt:
    nixfmt $(fd '^[^.]*\\.nix$' .)

hook:
    -ln -s ../../pre-commit .git/hooks/pre-commit
    -ln -s ../../post-commit .git/hooks/post-commit

ref:
    nix eval --raw --file fetch-refs.nix > refs.nix

# that's an ugly just command. but hey, it works. and doesn't require `nom` to be installed.
# but if you do have `nom` installed, the check command will have a nicer output
# for the long-running package builds.
check: fmt
    {{if nom-path != "" { "nom build --show-trace .#checks."+current-system+".cached-packages" } else {""} }}
    nix flake check --quiet --quiet --show-trace

# docs really do exceed the default call depth limit. as a workaround, increase it.

check-docs: check
    NIX_CONFIG="max-call-depth = 20000" nix eval --quiet --quiet --raw .#lib.internal.docs-markdown > /dev/null

doc: check
    NIX_CONFIG="max-call-depth = 20000" nix eval --quiet --quiet --raw .#lib.internal.docs-markdown | sponge docs.md

watch:
    fd .nix . | entr just doc

# intentionally copy out of nix store to play nicer with "Live Server"
pages:
    {{nom-or-nix}} build -o result-pages-link -f ./pages --show-trace
    rsync --chmod=+w -Lrcv result-pages-link/ result-pages

watch-pages:
    fd -p "^$(pwd)/pages/|\\.nix\$" . | entr just pages