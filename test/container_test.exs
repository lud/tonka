defmodule Tonka.ContainerTest do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.ServiceResolutionError
  alias Tonka.Core.Container.Service
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.Params
  use ExUnit.Case, async: true

  test "a new container can be created" do
    container = Container.new()
    assert %Container{} = container
  end

  defmodule SomeStructService do
    @behaviour Service

    defstruct [:val]

    @spec cast_params(term) :: {:ok, Service.params()} | {:error, term}
    def cast_params(term) do
      {:ok, term}
    end

    @spec configure(Service.config(), term) :: {:ok, Service.config()} | {:error, term}
    def configure(config, _) do
      config
    end

    @spec init(map, term) :: {:ok, struct} | {:error, term}
    def init(injects, params) do
      send(self(), {:init_called, __MODULE__})
      {:ok, %__MODULE__{val: :set_in_init}}
    end
  end

  defmodule SomeDependentStruct do
    @behaviour Container.Service

    defstruct []

    @spec cast_params(term) :: {:ok, Service.params()} | {:error, term}
    def cast_params(term) do
      {:ok, term}
    end

    @spec configure(Service.config(), term) :: {:ok, Service.config()} | {:error, term}
    def configure(config, _) do
      config
      |> Service.use_service(:mykey, SomeStructService)
    end

    @spec init(map, term) :: {:ok, struct} | {:error, term}
    def init(injects, params) do
      {:ok, %__MODULE__{}}
    end
  end

  test "a struct service module can be registered and pulled" do
    # When a single atom is registered, it is considered as a utype (a userland
    # abstract type).
    assert %Container{} = container = Container.bind(Container.new(), SomeStructService)

    assert Container.has?(container, SomeStructService)
    refute Container.has_built?(container, SomeStructService)

    refute_receive {:init_called, SomeStructService}

    assert {:ok, %SomeStructService{val: :set_in_init}, %Container{} = new_container} =
             Container.pull(container, SomeStructService)

    assert Container.has_built?(new_container, SomeStructService)

    assert_receive {:init_called, SomeStructService}
  end

  test "a builder function can be provided" do
    ref = make_ref()

    container =
      Container.new()
      |> Container.bind(SomeStructService, fn c ->
        send(self(), :some_builder_was_called)
        {:ok, %SomeStructService{val: ref}, c}
      end)

    assert {:ok, %SomeStructService{val: ^ref}, new_container} =
             Container.pull(container, SomeStructService)

    refute_receive {:init_called, SomeStructService}
    assert_received :some_builder_was_called

    # pull again, must be called only once: same ref, no message
    assert {:ok, %SomeStructService{val: ^ref}, _} =
             Container.pull(new_container, SomeStructService)

    refute_receive {:init_called, SomeStructService}
    refute_receive :some_builder_was_called
  end

  test "a struct service can depdend on another" do
    # When a single atom is registered, it is considered as a utype (a userland
    # abstract type). Given we do not provide an implementation, the container
    # expects that it is not only a Tonka.Core.Container.Type but also a
    container =
      Container.new()
      |> Container.bind(SomeStructService)
      |> Container.bind(SomeDependentStruct)

    refute_receive {:init_called, SomeStructService}

    assert {:ok, %SomeDependentStruct{}, %Container{}} =
             Container.pull(container, SomeDependentStruct)

    assert_receive {:init_called, SomeStructService}
  end

  test "a service value can be immediately set with bind_impl" do
    container =
      Container.new()
      |> Container.bind_impl(SomeStructService, %SomeStructService{})
      |> Container.bind(SomeDependentStruct)

    assert Container.has?(container, SomeStructService)
    assert Container.has_built?(container, SomeStructService)

    assert Container.has?(container, SomeDependentStruct)
    refute Container.has_built?(container, SomeDependentStruct)

    assert {:ok, %SomeDependentStruct{}, %Container{}} =
             Container.pull(container, SomeDependentStruct)

    refute_receive {:init_called, SomeStructService}
  end

  test "the container can tell if it has a service" do
    container = Container.bind(Container.new(), SomeStructService)
    assert Container.has?(container, SomeStructService)
    refute Container.has?(container, SomeDependentStruct)

    refute_receive {:init_called, SomeStructService}
  end

  test "a service can be built with a builder function" do
    container =
      Container.new()
      |> Container.bind(SomeStructService)
      |> Container.bind(SomeDependentStruct, fn c ->
        # This is not a refenrece implementation of a builder function. This is
        # basically what the container and service do with module-based
        # services.  An actual builder function would create a service from a
        # module that does not implement the Service behaviour, thus not by
        # calling init/1 but using another API.
        params = %{}

        with %{injects: inject_specs} <-
               SomeDependentStruct.configure(Service.base_config(), params),
             {:ok, {deps, c}} <- Container.build_injects(c, inject_specs),
             {:ok, impl} <- SomeDependentStruct.init(deps, params) do
          {:ok, impl, c}
        else
          {:error, _} = err -> err
        end
      end)

    assert {:ok, service, %Container{}} = Container.pull(container, SomeDependentStruct)

    assert is_struct(service, SomeDependentStruct)
  end

  defmodule UsesStuff do
    def cast_params(p),
      do: {:ok, p}

    @spec configure(Service.config(), term) :: {:ok, Service.config()} | {:error, term}
    def configure(config, _) do
      config
      |> Service.use_service(:a_stuff, Stuff)
    end

    def init(%{a_stuff: %{stuff_name: stuff_name}}, _) when is_atom(stuff_name) do
      send(self, {__MODULE__, stuff_name})
      {:ok, "UsesStuff name: #{stuff_name}"}
    end
  end

  defmodule AlsoUsesStuff do
    use Service

    def cast_params(p),
      do: {:ok, p}

    @spec configure(Service.config(), term) :: {:ok, Service.config()} | {:error, term}
    def configure(config, _) do
      config
      |> Service.use_service(:a_stuff, Stuff)
      |> Service.use_service(:user, UsesStuff)
    end

    def init(%{a_stuff: %{stuff_name: stuff_name}, user: dep}, _) when is_atom(stuff_name) do
      send(self, {__MODULE__, stuff_name})
      {:ok, "AlsoUsesStuff name: #{stuff_name}, dep was: #{dep}"}
    end
  end

  defp provide_stuff(stuff) do
    %{Stuff => fn -> {:ok, stuff} end}
  end

  defmodule PulledService do
    @behaviour Service

    defstruct []
    def cast_params(term), do: {:ok, term}
    def configure(config, _), do: config
    def init(injects, params), do: {:ok, :available}
  end

  defmodule PulledToLate do
    @behaviour Service

    defstruct []
    def cast_params(term), do: {:ok, term}
    def configure(config, _), do: config
    def init(injects, params), do: raise("this should not be called")
  end

  test "a container can be frozen" do
    container =
      Container.new()
      |> Container.bind(PulledService)

    assert false == Container.frozen?(container)

    container = Container.freeze(container)

    assert true == Container.frozen?(container)
  end

  test "a frozen container rejects new bindings" do
    assert_raise RuntimeError, ~r/is frozen/, fn ->
      Container.new()
      |> Container.bind(PulledService)
      |> Container.freeze()
      |> Container.bind(Something)
    end
  end

  test "a frozen container rejects pulling unbuilt services" do
    c1 =
      Container.new()
      |> Container.bind(PulledService)
      |> Container.bind(PulledToLate)

    # Pull before freeze OK
    {:ok, :available, c2} = Container.pull(c1, PulledService)

    # Now freeze
    frozen = Container.freeze(c2)

    # Pull service already built ok
    assert {:ok, :available, ^frozen} = Container.pull(frozen, PulledService)

    # Error cannot pull service that was not built
    assert {:error, %ServiceResolutionError{errkind: :build_frozen}} =
             Container.pull(frozen, PulledToLate)
  end

  test "using pull_frozen ensures that the container cannot be changed" do
    c0 =
      Container.new()
      |> Container.bind(PulledService)
      |> Container.bind(PulledToLate)
      |> Container.bind_impl(Prebuilt, :prebuilt)

    {:ok, _pulled, c1} = Container.pull(c0, PulledService)

    # Pull before freeze will result in an error if the service is not built
    assert {:ok, :prebuilt} = Container.pull_frozen(c1, Prebuilt)
    assert {:ok, :available} = Container.pull_frozen(c1, PulledService)

    assert {:error,
            %Tonka.Core.Container.ServiceResolutionError{
              errkind: :build_frozen,
              utype: PulledToLate
            }} = Container.pull_frozen(c1, PulledToLate)
  end
end
