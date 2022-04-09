defmodule Tonka.Extension.CompileTime do
  @moduledoc false
end

defmodule Tonka.Extension do
  @moduledoc """
  Defines the behaviour for extensions providing actions and services
  """

  @callback services :: %{binary => module}
  @callback actions :: %{binary => module}

  def list_extensions do
    Application.get_env(:tonka, :extensions, [])
  end
end
