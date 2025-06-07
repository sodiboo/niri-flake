{lib, ...}:
with lib; let
  short-circuit = v: steps:
    pipe v (map (step: x:
      if x == null
      then null
      else step x)
    steps);

  coalesce = flip pipe [
    (remove null)
    head
  ];

  ifilter = f:
    flip pipe [
      (imap0 (i: v: {inherit i v;}))
      (filter ({i, ...}: f i))
      (map ({v, ...}: v))
    ];

  filter-prev = f: l:
    if l == []
    then []
    else [(head l)] ++ (ifilter (flip pipe [(elemAt l) f]) (tail l));

  kebaberize = flip pipe [
    (replaceStrings strings.upperChars (map (c: "-${c}") strings.lowerChars))
    (removePrefix "-")
  ];
in
  flip short-circuit [
    # Read the file
    (src: "${src}/niri-config/src/lib.rs")
    (path:
      if builtins.pathExists path
      then path
      else null)
    builtins.readFile
    # Only collect the Action enum
    (strings.splitString "\n")
    (lists.foldl (
        {
          state,
          actions,
        }: line:
          {
            leading = {
              state =
                if line == "pub enum Action {"
                then "actions"
                else "leading";
              inherit actions;
            };
            actions =
              if line == "}"
              then {
                state = "trailing";
                inherit actions;
              }
              else {
                state = "actions";
                actions = actions ++ [line];
              };
            trailing = {
              state = "trailing";
              inherit actions;
            };
          }
          .${
            state
          }
      ) {
        state = "leading";
        actions = [];
      })
    ({
      state,
      actions,
    }:
      assert (state == "trailing"); actions)
    # Remove whitespaces
    (remove "")
    (map (strings.trim))
    # Turn multi-lined actions back into a single line
    concatStrings
    (builtins.split ''([A-Z][A-Za-z]*)(\(((#\[knuffel\([^]]*] [^,]*,?)*)\)| \{[^}]*})?,'')
    # Remove internal items
    (filter-prev (prev:
      if isString prev
      then !(strings.hasSuffix "#[knuffel(skip)]" prev)
      else true))
    (filter isList)
    # Get the params
    (map (
      m: let
        name = kebaberize (elemAt m 0);

        raw-params = elemAt m 2;
        params =
          if raw-params == null
          then {
            kind = "empty";
          }
          else
            short-circuit raw-params [
              (builtins.split ''(#\[knuffel\(([^]]*)\)] ([A-Za-z0-9<>]*)),?'')
              (filter isList)
              # TODO: Rewrite the section below
              (
                map
                (p:
                  coalesce [
                    (short-circuit p [
                      (flip elemAt 0)
                      (strings.match ''#\[knuffel\(argument(, str)?\)] ([A-Za-z0-9]+)'')
                      (m: {
                        kind = "arg";
                        as-str = elemAt m 0 != null;
                        type = elemAt m 1;
                      })
                    ])
                    (short-circuit p [
                      (flip elemAt 0)
                      (strings.match ''#\[knuffel\(arguments\)] Vec<([A-Za-z0-9]+)>'')
                      (m: {
                        kind = "list";
                        type = elemAt m 0;
                      })
                    ])
                    (short-circuit p [
                      (flip elemAt 0)
                      (strings.match ''#\[knuffel\(property\(name = "([^"]*)"\)(, default( = true)?)?\)] ([A-Za-z0-9]+)'')
                      (m: let
                        field = elemAt m 0;
                        use-default = elemAt m 1 != null;
                        type = elemAt m 3;
                      in {
                        kind = "prop";
                        none-important = false;
                        inherit field use-default type;
                      })
                    ])
                    (short-circuit p [
                      (flip elemAt 0)
                      (strings.match ''#\[knuffel\(property\(name = "([^"]*)"\)\)] Option<([A-Za-z0-9]+)>'')
                      (m: let
                        field = elemAt m 0;
                        type = elemAt m 1;
                      in {
                        kind = "prop";
                        # Option<T> always has a default value.
                        use-default = true;
                        # And it is actively meaningful to omit.
                        none-important = true;
                        inherit field type;
                      })
                    ])
                    {
                      kind = "unknown";
                      raw-params = elemAt p 0;
                    }
                  ])
              )
              # For now, only return the first item in the list so it's usable
              head
            ];
      in {
        inherit name params;
      }
    ))
  ]
