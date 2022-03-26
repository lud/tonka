import Ark.Interface

defmodule Tonka.Services.ProjectStore do
  alias Tonka.Services.ProjectStore.Record
  alias Tonka.Services.ProjectStore

  definterface Backend do
    @spec put(Record.t()) :: :ok
    def put(record)

    @spec get(key :: String.t()) :: Record.t()
    def get(key)
  end

  @enforce_keys [:backend]
  defstruct @enforce_keys

  def new(backend) do
    %ProjectStore{backend: backend}
  end
end
