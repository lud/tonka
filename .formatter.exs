[
  import_deps: [:ecto, :phoenix, :todo],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"],
  force_do_end_blocks: false,
  locals_without_parens: [
    # blocks
    prop: 1,
    prop: 2
  ]
]
