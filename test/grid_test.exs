defmodule Tonka.GridTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Operation
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

  defmodule NoCaster do
    @behaviour Tonka.Core.InputCaster

    def output_spec(%{type: type}) do
      %Operation.OutputSpec{type: type}
    end

    def call(term, _, _) do
      term
    end
  end

  test "a grid can be created" do
    grid = Grid.new()
    assert is_struct(grid, Grid)
  end

  defmodule Noop do
  end

  test "it is possible to add an operation to a grid" do
    grid = Grid.new()
    grid = Grid.add_operation(grid, "a", Noop)
    assert is_struct(grid, Grid)
  end

  test "it is possible to add two operations with the same module" do
    grid =
      Grid.new()
      |> Grid.add_operation("a", Noop)
      |> Grid.add_operation("b", Noop)

    assert is_struct(grid, Grid)
  end

  test "it is not possible to add two operations with the same key" do
    assert_raise ArgumentError, ~r/"a" is already defined/, fn ->
      Grid.new()
      |> Grid.add_operation("a", Noop)
      |> Grid.add_operation("a", Noop)
    end
  end

  defmodule MessageParamSender do
    def input_specs() do
      [
        %Operation.InputSpec{
          key: :parent,
          type: {:raw, :pid}
        }
      ]
    end

    def output_spec() do
      %Operation.OutputSpec{
        type: {:raw, :atom}
      }
    end

    def call(%{parent: parent}, %{Tonka.T.Params => %{message: message}}) do
      send(parent, message)
      :ok
    end
  end

  test "it is possible to run the grid" do
    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster, params: %{type: {:raw, :pid}})
      |> Grid.add_operation("a", MessageParamSender,
        inputs: %{parent: :incast},
        params: %{message: {ref, "hello"}}
      )

    Grid.run(grid, this)
    assert_receive {^ref, "hello"}
  end

  defmodule Upcaser do
    def input_specs() do
      [
        %Operation.InputSpec{
          key: :text,
          type: {:raw, :binary}
        }
      ]
    end

    def output_spec() do
      %Operation.OutputSpec{
        type: {:raw, :term}
      }
    end

    def call(%{text: text}, %{Tonka.T.Params => %{tag: tag}}) do
      {tag, String.upcase(text)}
    end
  end

  defmodule InputMessageSender do
    def input_specs() do
      [
        %Operation.InputSpec{
          key: :message,
          type: {:raw, :term}
        }
      ]
    end

    def output_spec() do
      %Operation.OutputSpec{
        type: {:raw, :atom}
      }
    end

    def call(%{message: message}, %{Tonka.T.Params => %{parent: parent}}) do
      send(parent, message)
      :ok
    end
  end

  test "an operation can use another operation output as input" do
    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster, params: %{type: {:raw, :binary}})
      |> Grid.add_operation("a", InputMessageSender,
        inputs: %{message: "b"},
        params: %{parent: this}
      )
      |> Grid.add_operation("b", Upcaser,
        inputs: %{text: :incast},
        params: %{tag: ref}
      )

    Grid.run(grid, "hello")

    assert_receive {^ref, "HELLO"}
  end

  defmodule RequiresAText do
    @behaviour Operation

    def input_specs() do
      [
        %Operation.InputSpec{
          key: :mytext,
          type: {:raw, :binary}
        }
      ]
    end

    def output_spec() do
      %Operation.OutputSpec{
        type: {:raw, :atom}
      }
    end

    def call(%{mytext: mytext}, %{Tonka.T.Params => %{parent: parent, tag: tag}})
        when is_binary(mytext) do
      message = {tag, String.upcase(mytext)}
      send(parent, message)
      :ok
    end
  end

  defmodule ProvidesAText do
    @behaviour Operation

    def input_specs() do
      []
    end

    def output_spec() do
      %Operation.OutputSpec{
        type: {:raw, :binary}
      }
    end

    def call(_, _) do
      Base.encode16(:crypto.strong_rand_bytes(12))
    end
  end

  defmodule ProvidesAnInt do
    @behaviour Operation

    def input_specs() do
      []
    end

    def output_spec() do
      %Operation.OutputSpec{
        type: {:raw, :integer}
      }
    end

    def call(_, _) do
      :erlang.system_time()
    end
  end

  test "the grid will verify that the operations are compatible - ok" do
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster, params: %{type: {:raw, :pid}})
      |> Grid.add_operation("consumer", RequiresAText,
        inputs: %{mytext: "provider"},
        params: %{parent: self(), tag: ref}
      )
      |> Grid.add_operation("provider", ProvidesAText, inputs: %{_: :incast})

    Grid.run(grid, "hello")

    assert_receive {^ref, text} when is_binary(text)
  end

  test "the grid will verify that the operations are compatible - error" do
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster, params: %{type: {:raw, :pid}})
      |> Grid.add_operation("consumer", RequiresAText,
        inputs: %{mytext: "provider"},
        params: %{parent: self(), tag: ref}
      )
      # Here we provide and integer to the consumer, which cannt work
      |> Grid.add_operation("provider", ProvidesAnInt, inputs: %{_: :incast})

    # At this point everything is fine. But when we will try to build the grid
    # it will fail. It must not fail because of the guard in:
    #
    #     def call(%{mytext: mytext}, %{Tonka.T.Params => %{parent: parent, tag: tag}})
    #         when is_binary(mytext)
    #
    # But rather raise an exception regarding the control of inputs

    input = "some raw string"
    input_type = {:native, String}

    assert match?(
             {:error, {:invalid_inputs, [%InvalidInputTypeError{}]}},
             Grid.validate(grid)
           )

    assert_raise InvalidInputTypeError, fn ->
      Grid.run(grid, input)
    end
  end

  test "the grid will verify that the grid input is mapped" do
    grid =
      Grid.new()
      |> Grid.add_operation("consumer", RequiresAText, inputs: %{mytext: "provider"})
      # Here we provide and integer to the consumer, which cannt work
      |> Grid.add_operation("provider", ProvidesAnInt, inputs: %{_: :incast})

    assert_raise Grid.NoInputCasterError, fn ->
      Grid.run(grid, :some_input)
    end
  end

  test "the grid will verify that every input is mapped" do
    grid =
      Grid.new()
      |> Grid.set_input(NoCaster, params: %{type: {:raw, :pid}})
      # here we do not map the input :mytext for RequiresAText
      |> Grid.add_operation("consumer", RequiresAText)

    assert_raise Grid.UnmappedInputError, fn ->
      Grid.run(grid, :some_input)
    end
  end
end
