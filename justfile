install:
    mix deps.get
    just start-infra
    mix do ecto.create, ecto.migrate
    MIX_ENV=test mix do ecto.create, ecto.migrate

test-watch:
    fswatch -o -m poll_monitor --event Updated --recursive lib test \
    | mix test --stale --listen-on-stdin

test-watch-one:
    fswatch -o -m poll_monitor --event Updated --recursive lib test \
    | mix test --stale --listen-on-stdin --max-failures 1

test-one-failed:
    mix test --max-failures 1 --trace --failed --seed $(date +%Y%m%d)

fwatch:
    fswatch -o -m poll_monitor --event Updated --recursive lib test


run: run-0
run-0: (_run "tonka0" "4000")
run-1: (_run "tonka1" "4001")
run-2: (_run "tonka2" "4002")
run-3: (_run "tonka3" "4003")
run-4: (_run "tonka4" "4004")
run-5: (_run "tonka5" "4005")

_run sname http_port:
    HTTP_PORT={{http_port}} iex --cookie tonkadev --sname {{sname}} -S mix phx.server

gettext-merge:
    mix gettext.extract --merge

start-infra:
    docker-compose up -d

stop-infra:
    docker-compose down

migrate:
    mix ecto.migrate
    MIX_ENV=test mix ecto.migrate

regen-database:
    mix ecto.regen
    MIX_ENV=test mix ecto.regen

reset-database:
    docker-compose down
    docker-compose up -d --force-recreate
    mix dev.await.db
    mix do ecto.drop, ecto.create, ecto.migrate
    MIX_ENV=test mix dev.await.db
    MIX_ENV=test mix do ecto.drop, ecto.create, ecto.migrate

seed-database:
    mix run priv/repo/seeds.exs