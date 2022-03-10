defmodule Tonka.Core.Operation.OperationMacros do
  alias Tonka.Core.Operation
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec

  @call_called :__tonka_op_call_called
  @out_called :__tonka_op_output_called
  @input_specs :__tonka_op_input_specs
  @output_type :__tonka_op_output_type

  @doc false
  defmacro init_module do
    Module.put_attribute(__CALLER__.module, @call_called, false)
    Module.put_attribute(__CALLER__.module, @out_called, false)

    quote location: :keep do
      import unquote(__MODULE__), only: :macros

      @behaviour Operation
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro input(definition) do
    if Module.get_attribute(__CALLER__.module, @call_called) do
      raise("cannot declare input after call")
    end

    case Injector.register_inject(__CALLER__.module, @input_specs, definition, :varname) do
      :ok -> nil
      {:error, badarg} -> raise badarg
    end

    nil
  end

  defmacro output(typedef) do
    typedef = Injector.normalize_utype(typedef)

    if Module.get_attribute(__CALLER__.module, @call_called) do
      raise("cannot declare input after call")
    end

    if Module.get_attribute(__CALLER__.module, @out_called) do
      raise("cannot declare output twice")
    end

    Module.put_attribute(__CALLER__.module, @out_called, true)
    Module.put_attribute(__CALLER__.module, @output_type, typedef)

    nil
  end

  defmacro call(do: block) do
    if Module.get_attribute(__CALLER__.module, @call_called) do
      raise("cannot declare call twice")
    end

    Module.put_attribute(__CALLER__.module, @call_called, true)

    quote location: :keep, generated: true do
      # We use an attribute to store the code block so unquote() from the user
      # are already expanded when stored
      @__op_call_block unquote(Macro.escape(block, unquote: true))
    end
  end

  defmacro __before_compile__(env) do
    call_called = Module.get_attribute(env.module, @call_called)
    custom_call = Module.defines?(env.module, {:call, 3}, :def)
    output_called = Module.get_attribute(env.module, @out_called)
    custom_output = Module.defines?(env.module, {:output_spec, 0}, :def)

    if not (output_called or custom_output) do
      raise_no_output(env.module)
    end

    if not (call_called or custom_call) do
      raise_no_call(env.module)
    end

    [
      def_inputs(env),
      def_output(env),
      if(Module.get_attribute(env.module, @call_called), do: def_call(env))
    ]
  end

  defp def_inputs(env) do
    specs = Injector.registered_injects(env.module, @input_specs)

    quote location: :keep do
      @__built_input_specs for {key, defn} <- unquote(specs),
                               do: %InjectSpec{key: key, type: defn[:utype]}

      @impl Operation
      @spec input_specs :: [InjectSpec.t()]

      def input_specs do
        @__built_input_specs
      end
    end
  end

  defp def_output(env) do
    output_type = Module.get_attribute(env.module, @output_type)

    quote location: :keep do
      @impl Operation
      @spec output_spec :: ReturnSpec.t()
      def output_spec do
        %ReturnSpec{type: unquote(output_type)}
      end
    end
  end

  defp def_call(env) do
    output_spec = Module.get_attribute(env.module, @output_type)
    input_specs = Injector.registered_injects(env.module, @input_specs)
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
        unquote(@__op_call_block)
      end
    end
  end

  def raise_no_call(module) do
    raise """
    #{inspect(module)} must define the call/3 function

    For instance, with the call/1 macro:

        use Tonka.Core.Operation
        input myinput Some.In.Type

        call do
          myinput + 1
        end
    """
  end

  def raise_no_output(module) do
    raise """
    #{inspect(module)} must define an output type

    For instance, with the output/1 macro:

        use Tonka.Core.Operation
        output Some.Out.Type
    """
  end
end
