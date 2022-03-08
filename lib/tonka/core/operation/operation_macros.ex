defmodule Tonka.Core.Operation.OperationMacros do
  alias Tonka.Core.Operation
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Operation.OutputSpec

  defmacro init_module do
    quote location: :keep do
      import unquote(__MODULE__), only: :macros

      @behaviour Operation
      @before_compile unquote(__MODULE__)

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
    quote location: :keep, generated: true do
      if @tonka_call_called, do: raise("cannot declare call twice")
      @tonka_call_called true
      # We use an attribute to store the code block so unquote() from the user
      # are already expanded when stored
      @__tonka_call_block unquote(Macro.escape(block, unquote: true))
    end
  end

  defmacro __before_compile__(env) do
    [
      quote do
        if not (@tonka_call_called or Module.defines?(__MODULE__, {:call, 3}, :def)) do
          Tonka.Core.Operation.__raise_no_call(__MODULE__)
        end

        if not @tonka_output_called do
          Tonka.Core.Operation.__raise_no_output(__MODULE__)
        end
      end,
      def_inputs(env),
      def_output(),
      if(Module.get_attribute(env.module, :tonka_call_called), do: def_call(env))
    ]
  end

  defp def_inputs(env) do
    specs = Injector.registered_injects(env.module, :tonka_input_specs)

    quote location: :keep do
      alias unquote(__MODULE__), as: Operation

      @__built_input_specs for {key, defn} <- unquote(specs),
                               do: %InjectSpec{key: key, type: defn[:utype]}

      @impl Operation
      @spec input_specs :: [InjectSpec.t()]

      def input_specs do
        @__built_input_specs
      end
    end
  end

  defp def_output do
    quote location: :keep do
      @__built_output_spec %OutputSpec{type: @tonka_output_type}

      @impl Operation
      @spec output_spec :: OutputSpec.t()
      def output_spec do
        @__built_output_spec
      end
    end
  end

  defp def_call(env) do
    output_spec = Module.get_attribute(env.module, :tonka_output_type, nil)
    input_specs = Injector.registered_injects(env.module, :tonka_input_specs)
    input_injects = Injector.quoted_injects_map(input_specs)

    quote location: :keep,
          generated: true,
          bind_quoted: [
            input_specs: input_specs,
            output_spec: output_spec,
            input_injects: Macro.escape(input_injects)
          ] do
      input_type = Injector.expand_injects_to_quoted_map_typespec(input_specs)
      @type input_map :: unquote(input_type)

      output_type = Injector.expand_type_to_quoted(output_spec)
      @type output :: unquote(output_type)

      @doc """
      Executes the operation.
      """
      @impl Operation
      @spec call(input_map, map, map) :: Operation.op_out(output)
      def call(unquote(input_injects), _, _) do
        unquote(@__tonka_call_block)
      end
    end
  end

  def __raise_no_call(module) do
    raise """
    #{inspect(module)} must define the call function

    For instance, with the call/1 macro:

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
