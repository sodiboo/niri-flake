{lib, kdl, ...}:
with lib; let
  short-circuit = v: steps:
    pipe v (map (step: x:
      if x == null
      then null
      else step x)
    steps);

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
    (strings.match ''.*pub enum Action \{([^}]*).*'')
    head
    (strings.splitString "\n")
    (remove "")
    (map (removePrefix "    "))
    (filter-prev (prev: prev != "#[knuffel(skip)]"))
    (remove "#[knuffel(skip)]")
    (map (flip short-circuit [
      (strings.match ''([A-Za-z]*)(\((.*)\))?,'')
      head
      kebaberize
    ]))
    (remove null)
    (map (
      name: {
        inherit name;
        value = kdl.magic-leaf name;
      }
    ))
    listToAttrs
  ]
