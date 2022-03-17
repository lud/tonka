defmodule Tonka.ContainerTest do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.Service
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.Params
  use ExUnit.Case, async: true

  @tag :skip
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

    refute_receive {:init_called, SomeStructService}

    assert {:ok, %SomeStructService{val: :set_in_init}, %Container{}} =
             Container.pull(container, SomeStructService)

    assert_receive {:init_called, SomeStructService}
  end

  test "using a single argument to bind/1" do
    require Logger

    Logger.warn("""
    # Given we do not provide an implementation, the container should expect
    # that the utype name is also a module that produces this utype.
    """)
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

  test "a service value can be immediately set" do
    container =
      Container.new()
      |> Container.bind_impl(SomeStructService, %SomeStructService{})
      |> Container.bind(SomeDependentStruct)

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
             {:ok, deps, c} <- Injector.build_injects(c, inject_specs),
             {:ok, impl} <- SomeDependentStruct.init(deps, params) do
          {:ok, impl, c}
        else
          {:error, _} = err -> err
        end
      end)

    assert {:ok, service, %Container{}} = Container.pull(container, SomeDependentStruct)

    assert is_struct(service, SomeDependentStruct)
  end

  test "a type is not overridable for builder functions" do
    assert_raise ArgumentError, ~r/only available for module-based services/, fn ->
      builder = fn _ -> raise "this will not be called" end
      Container.bind(Container.new(), SomeType, builder, overrides: %{Unused => fn -> :ok end})
    end
  end

  defmodule UsesParams do
    def cast_params(%{"param" => param}) when is_binary(param) do
      {:ok, %{p: String.to_existing_atom(param)}}
    end
  end

  defmodule AlsoUsesParams do
    use Service

    def cast_params(%{"param" => param}) when is_binary(param) do
      {:ok, %{p: String.to_existing_atom(param)}}
    end
  end

  defp provide_params(module, params) do
    %{
      Params => fn ->
        case module.cast_params(params) do
          {:ok, params} -> {:ok, params}
          {:error, _} = err -> err
        end
      end
    }
  end

  @tag :skip
  test "a type is overridable for a service" do
    container =
      Container.new()
      |> Container.bind(UsesParams, UsesParams,
        overrides: provide_params(UsesParams, %{"param" => "uses"})
      )

    assert {:ok, impl, _} = Container.pull(container, UsesParams)

    assert "hello from UsesParams" ==
             impl

    assert_receive {UsesParams, :uses}
  end

  @tag :skip
  test "a type is overridable for a service and only that service" do
    container =
      Container.new()
      |> Container.bind(UsesParams, UsesParams,
        overrides: provide_params(UsesParams, %{"param" => "uses"})
      )
      # Also uses params depends on UsesParams.  When we will pull that service,
      # each service will send self its module name and param value as atom
      |> Container.bind(AlsoUsesParams, AlsoUsesParams,
        overrides: provide_params(AlsoUsesParams, %{"param" => "other"})
      )

    assert {:ok, impl, _} = Container.pull(container, AlsoUsesParams)

    assert "hello from AlsoUsesParams, dep was: hello from UsesParams" ==
             impl

    assert_receive {UsesParams, :uses}
    assert_receive {AlsoUsesParams, :other}
  end
end
