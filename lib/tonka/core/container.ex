defmodule Tonka.Core.Container do
  @moduledoc """
  Implements a container for data structures or functions providing
  functionality to any `Tonka.Core.Operation`.
  """

  @type typealias :: module

  @type f_params ::
          {typespec}
          | {typespec, typespec}
          | {typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec, typespec, typespec}

  @type function_spec :: {f_params, typespec}
  @type typespec :: typealias | function_spec | {:remote_type, module, atom} | {:type, atom}

  @spec expand_type(typespec) :: {:type, atom} | {:remote_type, atom, atom}
  def expand_type(module) when is_atom(module) do
    expand_type(module.expand_type())
  end

  def expand_type({:remote_type, module, type} = terminal)
      when is_atom(module) and is_atom(type) do
    terminal
  end

  def expand_type({:type, type} = terminal) when is_atom(type) do
    terminal
  end

  def to_quoted_type({:remote_type, module, type})
      when is_atom(module) and is_atom(type) do
    quote do
      unquote(module).unquote(type)
    end
  end

  def to_quoted_type({:type, type}) when is_atom(type) do
    quote do
      unquote(type)()
    end
  end
end
