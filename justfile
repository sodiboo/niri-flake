# deps: fish, fd, entr, moreutils (sponge)

# i don't wanna deal with xargs
set shell := ["fish", "-c"]

current-system := `nix eval --impure --raw --expr builtins.currentSystem`
nom-path := `command -v nom || true`

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

html-doc: check
    NIX_CONFIG="max-call-depth = 20000" nix eval --quiet --quiet --raw .#lib.internal.docs-html | sponge docs.html.gen
    @[ -s docs.html.gen ]
    cat docs.html.gen | sponge docs.html

watch:
    fd .nix . | entr just doc

watch-html:
    fd .nix . | entr just html-doc

doc-both: fmt
    NIX_CONFIG="max-call-depth = 20000" nix eval --quiet --quiet --raw .#lib.internal.docs-markdown --show-trace | sponge docs.md.gen
    @[ -s docs.md.gen ]
    NIX_CONFIG="max-call-depth = 20000" nix eval --quiet --quiet --raw .#lib.internal.docs-html --show-trace | sponge docs.html.gen
    @[ -s docs.html.gen ]
    mv docs.md.gen docs.md
    mv docs.html.gen docs.html

watch-both:
    fd .nix . | entr -r just doc-both