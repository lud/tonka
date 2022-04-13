defmodule Tonka.Project.Scheduler do
  use GenServer
  require Logger
  alias Tonka.Data.TimeInterval
  use Tonka.Core.Service

  defmodule Command.Grid do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:grid, type: :binary, required: true)
    |> Hugs.field(:input, type: :any, required: true)
    |> Hugs.define()
  end

  defmodule Spec do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:id, type: :binary, required: true)
    |> Hugs.field(:schedule,
      type: :map,
      required: true,
      cast: &__MODULE__.parse_cron/1
    )
    |> Hugs.field(:timezone,
      type: :binary,
      default: "UTC"
    )
    |> Hugs.field(:backoff, type: :integer, default: 0, cast: &TimeInterval.to_ms/1)
    |> Hugs.field(:max_attempts, type: :integer, default: 1)
    |> Hugs.field(:attempts, type: :integer, default: 0)
    |> Hugs.field(:run, type: Command.Grid, required: true)
    |> Hugs.constraint(__MODULE__, :check_timezone, [])
    |> Hugs.define()

    @doc false
    def check_timezone(%{timezone: tz}) do
      if Tzdata.zone_exists?(tz) do
        :ok
      else
        {:error, "invalid timezone: #{inspect(tz)}"}
      end
    end

    @doc false
    def parse_cron(exp) do
      size = length(String.split(exp, " ", trim: true))

      case size do
        6 ->
          Logger.warn("using extended crontab expression: #{exp}")
          Crontab.CronExpression.Parser.parse(exp, true)

        _ ->
          Crontab.CronExpression.Parser.parse(exp, false)
      end
    end
  end

  @impl Tonka.Core.Service
  def service_type, do: __MODULE__

  @params_schema Hugs.build_props()
                 |> Hugs.field(:jobs,
                   type: {:list, Spec},
                   required: true,
                   cast: {__MODULE__, :cast_specs, []}
                 )

  @impl true
  def cast_params(term) do
    Hugs.denormalize(term, @params_schema)
  end

  @impl true
  def configure(config) do
    config
    |> use_service(:store, Tonka.Services.ProjectStore)
    |> use_service(:sup, Tonka.Services.ServiceSupervisor)
    |> use_service(:pinfo, Tonka.Data.ProjectInfo)
  end

  @impl true
  def build(%{sup: sup, store: _store, pinfo: %{prk: prk}}, %{jobs: specs}) do
    Tonka.Services.ServiceSupervisor.start_child(sup, {__MODULE__, specs: specs, prk: prk})
  end

  @moduledoc """
  Write a little description of the module …
  """

  @gen_opts ~w(name timeout debug spawn_opt hibernate_after)a

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, @gen_opts)
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @type specs :: [Spec.t()]

  @spec cast_specs(term, Hugs.Context.t() | nil) :: {:ok, specs} | {:error, term}
  def cast_specs(raw, _ctx \\ nil) when is_map(raw) do
    raw
    |> Enum.map(fn {id, v} -> Map.put(v, :id, id) end)
    |> Ark.Ok.map_ok(&Spec.denormalize/1)
  end

  defmodule S do
    defstruct tq: nil, prk: nil
  end

  @impl GenServer
  def init(opts) do
    specs = Keyword.fetch!(opts, :specs)
    prk = Keyword.fetch!(opts, :prk)
    tq = build_queue(specs)
    state = %S{prk: prk, tq: tq}
    {:ok, state, next_timeout(state)}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    Logger.debug("scheduler timeout")

    case TimeQueue.pop(state.tq) do
      {:ok, spec, tq} ->
        state = run_spec(spec, Map.put(state, :tq, tq))
        {:noreply, state, next_timeout(state)}

      {:delay, _, timeout} ->
        {:noreply, state, timeout}

      :empty ->
        {:noreply, state, :infinity}
    end
  end

  defp run_spec(%Spec{id: id} = spec, state) do
    Logger.debug("scheduler running job #{id}")

    case run_command(spec.run, state) do
      :ok ->
        Logger.info("✓ scheduler job #{id} ran successfully")
        requeue(state, spec)

      {:error, reason} ->
        Logger.error("scheduler job #{id} failed: #{Ark.Error.to_string(reason)}")
        requeue_attempt(state, spec)
    end
  end

  defp run_command(f, _) when is_function(f, 0) do
    case f.() do
      :ok -> :ok
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {f, []}, other}}
    end
  end

  defp run_command(%Command.Grid{grid: grid, input: input}, %{prk: prk}) do
    Tonka.Project.run_publication(prk, grid, input)
  end

  defp requeue(%S{tq: tq} = state, spec) do
    %S{state | tq: spec |> reset_attempts() |> insert_spec(tq)}
  end

  defp requeue_attempt(%S{tq: tq} = state, spec) do
    spec = bump_attempts(spec)
    %Spec{id: id, attempts: at, max_attempts: max} = spec

    if at >= max do
      Logger.warn("maximum attempts reached for scheduler job #{id}")
      requeue(state, spec)
    else
      %S{state | tq: insert_spec(spec, tq, spec.backoff)}
    end
  end

  def reset_attempts(spec) do
    set_attempts(spec, 0)
  end

  def bump_attempts(spec) do
    set_attempts(spec, spec.attempts + 1)
  end

  def set_attempts(spec, n) do
    %Spec{spec | attempts: n}
  end

  defp build_queue(specs) when is_list(specs) do
    List.foldr(specs, TimeQueue.new(), &insert_spec/2)
  end

  defp insert_spec(spec, tq) do
    ttl =
      spec
      |> next_utc_datetime()
      |> datetime_to_ttl()

    insert_spec(spec, tq, ttl)
  end

  defp insert_spec(spec, tq, ttl) when is_integer(ttl) do
    {:ok, _tref, tq} = TimeQueue.enqueue(tq, ttl, spec)
    tq
  end

  defp next_utc_datetime(%Spec{timezone: tz, schedule: sked}) do
    now = now_to_naive(tz)

    sked
    |> Crontab.Scheduler.get_next_run_date!(now)
    |> naive_tz_to_utc(tz)
  end

  defp now_to_naive(timezone) do
    DateTime.to_naive(DateTime.now!(timezone))
  end

  defp datetime_to_ttl(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(datetime, now, :millisecond)
    max(0, diff)
  end

  defp naive_tz_to_utc(datetime, timezone) do
    datetime
    |> DateTime.from_naive!(timezone)
    |> DateTime.shift_zone!("UTC")
  end

  defp next_timeout(%{tq: tq}) do
    case TimeQueue.timeout(tq) do
      :infinity ->
        Logger.info("scheduler hibernating")
        :hibernate

      t ->
        Logger.info("scheduler timeout in #{TimeInterval.to_string(t)}")
        t
    end
  end
end
