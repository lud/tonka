defmodule Tonka.Project.Scheduler do
  use GenServer

  defmodule Spec do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:id, type: :binary, required: true)
    |> Hugs.field(:schedule,
      type: :map,
      required: true,
      cast: {Crontab.CronExpression.Parser, :parse, []}
    )
    |> Hugs.field(:timezone,
      type: :binary,
      default: "UTC",
      cast: {__MODULE__, :check_timezone, []}
    )
    |> Hugs.inject()

    def check_timezone(tz) do
      case Tz.PeriodsProvider.periods(tz) do
        {:ok, _} -> {:ok, tz}
        {:error, _} = err -> err
      end
    end
  end

  @moduledoc """
  Write a little description of the module …
  """

  @gen_opts ~w(name timeout debug spawn_opt hibernate_after)a

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, @gen_opts)
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @type spec :: 1
  @type specs :: [spec]

  @spec cast_specs(term) :: {:ok, specs} | {:error, term}
  def cast_specs(raw) when is_map(raw) do
    raw
    |> Enum.map(fn {id, v} -> Map.put(v, :id, id) end)
    |> Ark.Ok.map_ok(&Spec.denormalize/1)
  end

  @impl GenServer
  def init(opts) do
    {:ok, opts}
  end
end
