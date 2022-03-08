defmodule Tonka.Test.Fixtures.OpOneInput.MyInput do
  @behaviour Tonka.Core.Container.Type

  defstruct dummy: true

  @type t :: %__MODULE__{}

  def expand_type do
    {:remote_type, __MODULE__, :t}
  end
end

defmodule Tonka.Test.Fixtures.OpOneInput.MyOutput do
  @behaviour Tonka.Core.Container.Type

  def expand_type do
    {:type, :binary}
  end
end

defmodule Tonka.Test.UserlandMacros do
  defmacro squared(expr) do
    quote do
      value = unquote(expr)
      value * value
    end
  end
end

defmodule Tonka.Test.Fixtures.OpOneInput do
  alias Tonka.Core.Operation
  alias Tonka.Test.Fixtures.OpOneInput.MyInput
  alias Tonka.Test.Fixtures.OpOneInput.MyOutput
  require alias Tonka.Test.UserlandMacros
  use Operation

  suffix = "_SUF"

  def __mix_recompile__?, do: true

  input myvar in MyInput
  output MyOutput

  call do
    IO.puts("myvar is #{inspect(myvar)}")

    two = fn -> 2 end
    square_of_two = UserlandMacros.squared(two.())
    4 = square_of_two
    IO.puts("suare of two = #{inspect(square_of_two)}")

    {:ok, String.upcase(myvar) <> unquote(suffix)}
  end
end
