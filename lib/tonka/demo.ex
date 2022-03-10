defmodule Tonka.Demo do
  def run do
    # -----------------------------------------------------------------------------
    #  Simulate a grid run from a job
    # -----------------------------------------------------------------------------

    # TODO check the rate-limiter
    # TODO fake fetching the build container

    alias Tonka.Core.Container

    # -- Project container initialization -----------------------------------------

    # On init, the project will fill the container with services used by operations.
    container =
      Container.new()
      |> Container.bind(Tonka.Service.Credentials, fn c ->
        store =
          File.cwd!()
          |> Path.join("var/projects/dev/credentials.json")
          |> Tonka.Service.Credentials.JsonFileCredentials.from_path!()

        {:ok, store, c}
      end)

    {:ok, creds, container} = Container.pull(container, Tonka.Service.Credentials)
    creds |> IO.inspect(label: "pulled", pretty: true)
  end
end
