defmodule Tonka.Core.Operation do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as operations
  in a `Tonka.Core.Grid`.
  """

  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Operation.OutputSpec
  alias Tonka.Core.Injector

  @type params :: map
  @type op_in :: map
  @type op_out :: op_out(term)
  @type op_out(output) :: {:ok, output} | {:error, term} | {:async, Task.t()}

  @callback input_specs() :: [InjectSpec.t()]
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
    Injector.register_inject(__CALLER__.module, :tonka_input_specs, definition, :varname)

    quote location: :keep do
      if @tonka_call_called, do: raise("cannot declare input after call")
      @tonka_input_called true
    end
  end

  defmacro output(typedef) do
    typedef = Injector.normalize_utype(typedef)

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

  defmacro __before_compile__(env) do
    [
      def_inputs(env),
      def_output(),
      def_call(env)
    ]
  end

  defp def_inputs(env) do
    specs = Injector.registered_injects(env.module, :tonka_input_specs)

    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      @__built_input_specs for {key, defn} <- unquote(specs),
                               do: %Tonka.Core.Container.InjectSpec{key: key, type: defn[:utype]}

      @impl unquote(__MODULE__)
      @spec input_specs :: [Tonka.Core.Container.InjectSpec.t()]

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
    output_spec = Module.get_attribute(env.module, :tonka_output_type, nil)
    input_injects = Injector.quoted_injects_map(env.module, :tonka_input_specs)
    block = Module.get_attribute(env.module, :tonka_call_block)

    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      if not @tonka_call_called and not Module.defines?(__MODULE__, {:call, 3}, :def) do
        Operation.__raise_no_call(__MODULE__)
      end

      if not @tonka_output_called do
        Operation.__raise_no_output(__MODULE__)
      end

      output_type = Injector.expand_input_type_to_quoted(unquote(output_spec))

      @impl unquote(__MODULE__)

      unquote(Injector.quoted_injects_map_typedef(env.module, :tonka_input_specs, :input_map))

      Operation.output_typespec(output_type)

      @doc """
      Executes the operation.
      """
      @spec call(input_map, map, map) :: Operation.op_out(output)
      def call(unquote(input_injects), _, _) do
        unquote(block)
      end
    end
  end

  defmacro input_typespec(x) do
    quote bind_quoted: [x: x] do
      @type input_map :: unquote(x)
    end
  end

  defmacro output_typespec(t) do
    quote bind_quoted: [t: t] do
      @type output :: unquote(t)
    end
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
