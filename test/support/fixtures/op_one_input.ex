defmodule Tonka.Test.Fixtures.OpOneInput do
  alias Tonka.Core.Operation
  use Operation

  defmodule MyInput do
    @behaviour Tonka.Core.Container.Type
  end

  defmodule MyOutput do
    @behaviour Tonka.Core.Container.Type
  end

  def __mix_recompile__?, do: true

  input myvar in MyInput

  output MyOutput

  # call do
  #   myvar |> IO.inspect(label: "myvar")
  # end
end
