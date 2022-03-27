defmodule Tonka.Test.Fixtures.OpOneInput.MyInput do
  defstruct text: nil

  @type t :: %__MODULE__{text: binary}
end

defmodule Tonka.Test.Fixtures.OpOneInput.MyOutput do
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
  alias Tonka.Test.Fixtures.OpOneInput.MyInput
  require alias Tonka.Test.UserlandMacros
  # use Action

  suffix = "_SUF"

  @type output :: binary

  # def __mix_recompile__?, do: true

  def call(myvar) do
    %MyInput{text: text} = myvar
    IO.puts("myvar is #{inspect(myvar)}")

    two = fn -> 2 end
    square_of_two = UserlandMacros.squared(two.())
    4 = square_of_two
    IO.puts("suare of two = #{inspect(square_of_two)}")

    {:ok, String.upcase(text) <> unquote(suffix)}
  end
end
