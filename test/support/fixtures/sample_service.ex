defmodule Tonka.Test.Fixtures.SampleService.Dependency do
  defstruct some_integer: 1, some_string: "hello"

  @behaviour Tonka.Core.Container.Type
  @impl Tonka.Core.Container.Type
  def expand_type, do: {:type, :binary}
end

defmodule Tonka.Test.Fixtures.SampleService do
  alias Tonka.Core.Container.Service
  use Service

  defstruct []

  @type t :: %__MODULE__{}

  inject dep in Tonka.Test.Fixtures.SampleService.Dependency
  provides __MODULE__, t

  def expand_type, do: {:type, :binary}

  init do
    Hello
  end
end

defmodule Tonka.Test.Fixtures.SampleService2 do
  alias Tonka.Core.Container.Service
  use Service

  defstruct []

  inject dep in Tonka.Test.Fixtures.SampleService.Dependency
  provides Tonka.Test.Fixtures.SampleService.Dependency

  def expand_type, do: {:type, :binary}

  init do
    Hello
  end
end
