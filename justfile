# deps: fish, fd, entr, moreutils (sponge)

# i don't wanna deal with xargs
set shell := ["fish", "-c"]

default: check

fmt:
    nix fmt --quiet --quiet $(fd '^[^.]*\\.nix$' .) -- --quiet

hook:
    -ln -s ../../pre-commit .git/hooks/pre-commit
    -ln -s ../../post-commit .git/hooks/post-commit

ref:
    nix eval --raw --file fetch-refs.nix > refs.nix

check: fmt
    nix flake check --quiet --quiet --show-trace

check-docs: check
    nix eval --quiet --quiet --raw .#lib.internal.docs-markdown > /dev/null

doc: check
    nix eval --quiet --quiet --raw .#lib.internal.docs-markdown | sponge docs.md

watch:
    fd .nix . | entr just doc