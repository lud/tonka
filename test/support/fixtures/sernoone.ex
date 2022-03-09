defmodule Tonka.Test.Fixtures.SampleServiceNoInjects do
  alias Tonka.Core.Container.Service
  use Service

  def provides_spec, do: raise("no impl")
  def init(_), do: raise("no impl")
end
