defmodule Tonka.Test.Fixtures.OpOneInput.MyInput do
  @behaviour Tonka.Core.Container.Type

  defstruct text: nil

  @type t :: %__MODULE__{text: binary}

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
  alias Tonka.Test.Fixtures.OpOneInput.MyInput
  require alias Tonka.Test.UserlandMacros
  # use Operation

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
