defmodule Tonka.Core.Reflection do
  def implements_behaviour?(module, behaviour) do
    match_behaviour(behaviour, module.module_info(:attributes))
  end

  def match_behaviour(behaviour, [{:behaviour, [behaviour]} | _]), do: true
  def match_behaviour(behaviour, [_ | attrs]), do: match_behaviour(behaviour, attrs)
  def match_behaviour(_behaviour, []), do: false
end
