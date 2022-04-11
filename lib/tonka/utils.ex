defmodule Tonka.Utils do
  def struct_binary_keys(module) when is_atom(module) do
    module.__struct__()
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.map(&Atom.to_string/1)
  end

  def yaml!(string) when is_binary(string) do
    YamlElixir.read_from_string!(string)
  end

  def yaml(string) when is_binary(string) do
    YamlElixir.read_from_string(string)
  end

  def module_to_string(module) when is_atom(module) do
    case Atom.to_string(module) do
      "Elixir." <> rest -> rest
      full -> full
    end
  end
end
