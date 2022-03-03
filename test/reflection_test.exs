defmodule Tonka.ReflectionTest do
  alias Tonka.Core.Reflection
  use ExUnit.Case, async: true

  defmodule A do
    @callback noop() :: :ok
  end

  defmodule ImplementsA do
    @behaviour A
    def noop, do: :ok
  end

  defmodule Other do
  end

  test "behaviour is detected" do
    assert Reflection.implements_behaviour?(ImplementsA, A)
    refute Reflection.implements_behaviour?(Other, A)
  end
end
