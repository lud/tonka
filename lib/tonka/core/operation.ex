defmodule Tonka.Core.Operation do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as operations
  in a `Tonka.Core.Grid`.
  """

  alias Tonka.Core.Operation.{InputSpec, OutputSpec}

  @type params :: map
  @type op_in :: map
  @type op_out :: op_out(term)
  @type op_out(value) :: {:ok, value} | {:error, term} | {:async, Task.t()}

  @callback input_specs() :: [InputSpec.t()]
  @callback output_spec() :: OutputSpec.t()

  @callback call(op_in, params, injects :: map) :: op_out

  defmacro __using__(_) do
    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      @behaviour Operation
      @before_compile Operation

      import Operation, only: :macros

      @tonka_input_called false
      @tonka_call_called false
      @tonka_output_called false
    end
  end

  defmacro input(definition) do
    definition = normalize_input(definition)

    module = __CALLER__.module

    IO.puts("register #{inspect(definition)} in #{inspect(module)}")

    Module.put_attribute(module, :tonka_input_specs, [
      definition | Module.get_attribute(module, :tonka_input_specs, [])
    ])

    quote location: :keep do
      if @tonka_call_called, do: raise("cannot declare input after call")
      @tonka_input_called true
    end

    # |> tap(&IO.puts(Macro.to_string(&1)))
  end

  defmacro output(typedef) do
    typedef = normalize_type(typedef)

    quote location: :keep do
      if @tonka_call_called, do: raise("cannot declare output after call")
      if @tonka_output_called, do: raise("cannot declare output twice")
      @tonka_output_called true
      @tonka_output_type unquote(typedef)
    end
  end

  defmacro call(do: block) do
    Module.put_attribute(__CALLER__.module, :tonka_call_block, block)

    quote location: :keep do
      if @tonka_call_called, do: raise("cannot declare call twice")
      @tonka_call_called true
    end
  end

  defp normalize_input({:in, _, [var, type]}) do
    {normalize_vardef(var), normalize_type(type)}
  end

  defp normalize_vardef({varname, meta, nil}) when is_atom(varname) when is_list(meta) do
    varname
  end

  # defp normalize_type({:__aliases__, _, _} = mod_type) do
  #   mod_type
  # end

  defp normalize_type(any) do
    any
  end

  defmacro __before_compile__(env) do
    [
      def_inputs(env),
      def_output(),
      def_call(env)
    ]
  end

  defp def_inputs(env) do
    specs = Module.get_attribute(env.module, :tonka_input_specs, [])

    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      @__built_input_specs for {varname, type} <- unquote(specs),
                               do: %Operation.InputSpec{key: varname, type: type}

      @impl unquote(__MODULE__)
      @spec input_specs :: [Operation.InputSpec.t()]

      def input_specs do
        @__built_input_specs
      end
    end
  end

  defp def_output do
    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      if nil == Module.get_attribute(__MODULE__, :tonka_output_type) and
           not Module.defines?(__MODULE__, {:output_spec, 0}, :def) do
        raise """
        #{inspect(__MODULE__)} must define an output

        For instance, with the output/1 macro:

            use #{inspect(unquote(__MODULE__))}
            output Some.Out.Type
        """
      end

      @__built_output_spec %Operation.OutputSpec{type: @tonka_output_type}
      @impl unquote(__MODULE__)
      @spec output_spec :: Operation.OutputSpec.t()

      def output_spec do
        @__built_output_spec
      end
    end
  end

  defp def_call(env) do
    input_specs = Module.get_attribute(env.module, :tonka_input_specs, [])
    output_spec = Module.get_attribute(env.module, :tonka_output_type, nil)

    output_spec |> IO.inspect(label: "output_spec")
    input_keys = Keyword.keys(input_specs)
    input_vars = Enum.map(input_keys, fn k -> {k, Macro.var(k, nil)} end)

    input =
      quote do
        %{unquote_splicing(input_vars)}
      end
      |> tap(&IO.puts(Macro.to_string(&1)))

    block = Module.get_attribute(env.module, :tonka_call_block)

    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      if not @tonka_call_called and not Module.defines?(__MODULE__, {:call, 3}, :def) do
        Operation.__raise_no_call(__MODULE__)
      end

      @tonka_output_called |> IO.inspect(label: "@tonka_output_called")

      if not @tonka_output_called do
        Operation.__raise_no_output(__MODULE__)
      end

      input_types =
        unquote(input_specs)
        |> Enum.map(fn {key, type} -> {key, Operation.expand_input_type_quoted(type)} end)
        |> then(&{:%{}, [], &1})

      output_type =
        unquote(output_spec)
        |> Operation.expand_input_type_quoted()
        |> IO.inspect(label: "output_type")

      @impl unquote(__MODULE__)

      Operation.input_typespec(input_types)
      Operation.output_typespec(output_type)
      # @type output :: term

      @doc """
      Executes the operation.
      """
      @spec call(input_map, map, map) :: output
      def call(unquote(input), _, _) do
        unquote(block)
      end
    end
  end

  def expand_input_type_quoted(userland_type) do
    userland_type
    |> Tonka.Core.Container.expand_type()
    |> Tonka.Core.Container.to_quoted_type()
  end

  defmacro input_typespec(x) do
    quote bind_quoted: [x: x] do
      @type input_map :: unquote(x)
    end
    |> tap(&IO.puts(Macro.to_string(&1)))
  end

  defmacro output_typespec(x) do
    quote bind_quoted: [x: x] do
      @type output :: unquote(x)
    end
    |> tap(&IO.puts(Macro.to_string(&1)))
  end

  def __raise_no_call(module) do
    raise """
    #{inspect(module)} must define the call function

    For instance, with the output/1 macro:

        use #{inspect(__MODULE__)}
        input myinput Some.In.Type

        call do
          myinput + 1
        end
    """
  end

  def __raise_no_output(module) do
    raise """
    #{inspect(module)} must define an output type

    For instance, with the output/1 macro:

        use #{inspect(__MODULE__)}
        output Some.Out.Type
    """
  end
end
