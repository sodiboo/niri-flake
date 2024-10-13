# deps: fish, fd, entr, moreutils (sponge)

# i don't wanna deal with xargs
set shell := ["fish", "-c"]

current-system := `nix eval --impure --raw --expr builtins.currentSystem`
nom-path := `command -v nom || true`

default: check

fmt:
    nix fmt --quiet --quiet $(fd '^[^.]*\\.nix$' .) -- --quiet

hook:
    -ln -s ../../pre-commit .git/hooks/pre-commit
    -ln -s ../../post-commit .git/hooks/post-commit

ref:
    nix eval --raw --file fetch-refs.nix > refs.nix

# that's an ugly just command. but hey, it works. and doesn't require `nom` to be installed.
# but if you do have `nom` installed, the check command will have a nicer output
# for the long-running package builds.
check: fmt
    {{if nom-path != "" { "nom build .#checks."+current-system+".cached-packages" } else {""} }}
    nix flake check --quiet --quiet --show-trace

check-docs: check
    nix eval --quiet --quiet --raw .#lib.internal.docs-markdown > /dev/null

doc: check
    nix eval --quiet --quiet --raw .#lib.internal.docs-markdown | sponge docs.md

watch:
    fd .nix . | entr just doc