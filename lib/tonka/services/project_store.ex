defmodule Tonka.Services.ProjectStore do
  import Ark.Interface

  definterface Protocol do
    @spec put(t, term, term) :: :ok
    def put(t, key, value)

    @spec get(t, term, term) :: term
    def get(t, key, default)
  end
end
