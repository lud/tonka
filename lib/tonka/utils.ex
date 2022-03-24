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
end
