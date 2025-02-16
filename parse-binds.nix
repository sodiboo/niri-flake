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
    (src: "${src}/niri-config/src/lib.rs")
    (path:
      if builtins.pathExists path
      then path
      else null)
    builtins.readFile
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
          .${state}
      ) {
        state = "leading";
        actions = [];
      })
    ({
      state,
      actions,
    }:
      assert (state == "trailing"); actions)
    (remove "")
    (map (removePrefix "    "))
    (filter-prev (prev: prev != "#[knuffel(skip)]"))
    (remove "#[knuffel(skip)]")
    (map (
      flip short-circuit [
        (strings.match ''([A-Za-z]*)(\((.*)\))?,'')
        (
          m: let
            raw-name = elemAt m 0;
            raw = elemAt m 2;
            name = kebaberize raw-name;
            params =
              if raw == null
              then {
                kind = "empty";
              }
              else
                coalesce [
                  (short-circuit raw [
                    (strings.match ''#\[knuffel\(argument(, str)?\)] ([A-Za-z0-9]+)'')
                    (m: {
                      kind = "arg";
                      as-str = elemAt m 0 != null;
                      type = elemAt m 1;
                    })
                  ])
                  (short-circuit raw [
                    (strings.match ''#\[knuffel\(arguments\)] Vec<([A-Za-z0-9]+)>'')
                    (m: {
                      kind = "list";
                      type = elemAt m 0;
                    })
                  ])
                  (short-circuit raw [
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
                  (short-circuit raw [
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
                    inherit raw-name raw;
                  }
                ];
          in {
            inherit name params;
          }
        )
      ]
    ))
    (remove null)
  ]
