defmodule Tonka.Core.Reflection do
  @moduledoc """
  Helpers to extract information from language structures like modules or
  functions.
  """
  def implements_behaviour?(module, behaviour) do
    match_behaviour(behaviour, module.module_info(:attributes))
  end

  def match_behaviour(behaviour, [{:behaviour, [behaviour]} | _]), do: true
  def match_behaviour(behaviour, [_ | attrs]), do: match_behaviour(behaviour, attrs)
  def match_behaviour(_behaviour, []), do: false
end
