defmodule Tonka.Core.InputCaster.InputCasterMacros do
  @moduledoc false
  alias Tonka.Core.InputCaster
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec

  @call_called :__tonka_incast_call_called
  @out_called :__tonka_incast_output_called
  @output_type :__tonka_incast_output_type

  @doc false
  defmacro init_module do
    Module.put_attribute(__CALLER__.module, @call_called, false)
    Module.put_attribute(__CALLER__.module, @out_called, false)

    quote location: :keep do
      import unquote(__MODULE__), only: :macros

      @behaviour InputCaster
      @before_compile unquote(__MODULE__)
    end
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

  defmacro call(input_var, do: block) do
    if Module.get_attribute(__CALLER__.module, @call_called) do
      raise("cannot declare call twice")
    end

    Module.put_attribute(__CALLER__.module, @call_called, true)

    quote location: :keep, generated: true do
      # We use an attribute to store the code block so unquote() from the user
      # are already expanded when stored
      @__incast_call_var unquote(Macro.escape(input_var, unquote: true))
      @__incast_call_block unquote(Macro.escape(block, unquote: true))
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
      def_output(env),
      if(Module.get_attribute(env.module, @call_called), do: def_call(env))
    ]
  end

  defp def_output(env) do
    output_type = Module.get_attribute(env.module, @output_type)

    quote location: :keep do
      @impl InputCaster
      @spec output_spec :: ReturnSpec.t()
      def output_spec do
        %ReturnSpec{type: unquote(output_type)}
      end
    end
  end

  defp def_call(env) do
    output_spec = Module.get_attribute(env.module, @output_type)

    quote location: :keep,
          generated: true,
          bind_quoted: [output_spec: output_spec] do
      output_type = Injector.expand_type_to_quoted(output_spec)
      @type output :: unquote(output_type)

      @doc """
      Casts the input to type `t:output`.
      """
      @impl InputCaster
      @spec call(term, map, map) :: Operation.op_out(output)
      def call(unquote(@__incast_call_var), _, _) do
        unquote(@__incast_call_block)
      end
    end
  end

  def raise_no_call(module) do
    raise """
    #{inspect(module)} must define the call/3 function

    For instance, with the call/1 macro:

        use Tonka.Core.InputCaster

        call input do
          {:ok, inspect(input)}
        end
    """
  end

  def raise_no_output(module) do
    raise """
    #{inspect(module)} must define an output type

    For instance, with the output/1 macro:

        use Tonka.Core.InputCaster
        output Some.Out.Type
    """
  end
end
