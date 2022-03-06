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

defmodule Tonka.Test.Fixtures.OpOneInput do
  alias Tonka.Core.Operation
  alias Tonka.Test.Fixtures.OpOneInput.MyInput
  alias Tonka.Test.Fixtures.OpOneInput.MyOutput
  use Operation

  def __mix_recompile__?, do: true

  input myvar in MyInput
  output MyOutput

  call do
    IO.puts("myvar is #{inspect(myvar)}")
    {:ok, "hello"}
  end
end
