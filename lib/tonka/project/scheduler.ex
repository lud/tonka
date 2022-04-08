defmodule Tonka.Project.Scheduler do
  use GenServer
  require Logger
  alias Tonka.Data.TimeInterval

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
      cast: {Crontab.CronExpression.Parser, :parse, []}
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

    def check_timezone(%{timezone: tz}) do
      Tz.PeriodsProvider.periods(tz)
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

  @type specs :: [Spec.t()]

  @spec cast_specs(term) :: {:ok, specs} | {:error, term}
  def cast_specs(raw) when is_map(raw) do
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
    {:ok, %S{prk: prk, tq: tq}, TimeQueue.timeout(tq)}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    case TimeQueue.pop(state.tq) do
      {:ok, spec, tq} -> run_spec(spec, Map.put(state, :tq, tq))
      {:delay, _, timeout} -> {:noreply, state, timeout}
      :empty -> {:noreply, state, :infinity}
    end
  end

  defp run_spec(%Spec{id: id} = spec, state) do
    Logger.debug("scheduler running job #{id}")

    state =
      case run_command(spec.run, state) do
        :ok ->
          Logger.info("✓ scheduler job #{id} ran successfully")
          requeue(state, spec)

        {:error, reason} ->
          Logger.error("scheduler job #{id} failed: #{Ark.Error.to_string(reason)}")
          requeue_attempt(state, spec)
      end

    {:noreply, state, next_timeout(state)}
  end

  defp run_command(f, _) when is_function(f, 0) do
    case f.() do
      :ok -> :ok
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {f, []}, other}}
    end
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
    TimeQueue.timeout(tq)
  end
end
