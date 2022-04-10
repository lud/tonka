defmodule Tonka.Extension do
  @moduledoc """
  Defines the behaviour for extensions providing actions and services
  """

  @callback services :: %{binary => module}
  @callback actions :: %{binary => module}

  def list_extensions do
    Application.get_env(:tonka, :extensions, [])
  end

  @doc """
  Ensures that all modules from all extensions are loaded in memory. This is
  notably useful to load all defined atoms in order to successfully parse the
  projects configurations
  """
  def ensure_all_loaded do
    list_extensions() |> Enum.each(&ensure_loaded/1)
  end

  def ensure_loaded(ext) do
    ext.services |> Map.values() |> Enum.each(&Code.ensure_loaded!/1)
    ext.actions |> Map.values() |> Enum.each(&Code.ensure_loaded!/1)
  end

  def build_service_index do
    # Merge in order of the list_extensions config value so it is possible to
    # override previous definitions with new modules
    Enum.reduce(list_extensions(), %{}, fn mod, acc -> Map.merge(acc, mod.services()) end)
  end

  def build_action_index do
    # Merge in order of the list_extensions config value so it is possible to
    # override previous definitions with new modules
    Enum.reduce(list_extensions(), %{}, fn mod, acc -> Map.merge(acc, mod.actions()) end)
  end
end
