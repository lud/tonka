[
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"],
  force_do_end_blocks: false,
  locals_without_parens: [
    # operation macros
    input: 1,
    output: 1,
    call: 1,

    # service macros
    inject: 1,
    provides: 1,
    provides: 2,
    init: 1,
    defdispatch: 2
  ]
]
