defmodule Tonka.Extension do
  @moduledoc """
  Defines the behaviour for extensions providing actions and services
  """

  @callback services :: %{binary => module}
  @callback actions :: %{binary => module}

  def list_extensions do
    Application.get_env(:tonka, :extensions, [])
  end

  def build_service_index do
    # Merge in order of the list_extensions config value so it is possible to
    # override previous definitions with new modules
    Enum.reduce(list_extensions(), %{}, fn mod, acc -> Map.merge(acc, mod.services()) end)
  end
end
