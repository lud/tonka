defmodule Tonka.ReflectionTest do
  alias Tonka.Core.Reflection
  use ExUnit.Case, async: true

  defmodule ImplementsA do
    @behaviour A
  end

  defmodule Other do
  end

  test "behaviour is detected" do
    assert Reflection.implements_behaviour?(ImplementsA, A)
    refute Reflection.implements_behaviour?(Other, A)
  end
end
