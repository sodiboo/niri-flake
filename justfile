# deps: fish, fd, entr, moreutils (sponge)

# i don't wanna deal with xargs
set shell := ["fish", "-c"]

default: check

fmt:
    nix fmt --quiet --quiet $(fd '^[^.]*\\.nix' .) -- --quiet

hook:
    -ln -s ../../pre-commit .git/hooks/pre-commit
    -ln -s ../../post-commit .git/hooks/post-commit

check: fmt
    nix flake check --quiet --quiet --show-trace

check-docs: check
    nix eval --quiet --quiet --raw .#__docs > /dev/null

doc: check
    nix eval --quiet --quiet --raw .#__docs | sponge docs.md

watch:
    fd .nix . | entr just doc