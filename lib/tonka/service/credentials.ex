defprotocol Tonka.Service.Credentials do
  @doc """
  Returns the credentials value stored under `path`.
  """
  @spec get_string(t, binary) :: binary
  def get_string(t, path)
end

defimpl Tonka.Service.Credentials, for: Any do
  defmacro __deriving__(module, struct, _options) do
    quote do
      defimpl Tonka.Service.Credentials, for: unquote(module) do
        def get_string(t, path) do
          unquote(struct.__struct__).get_string(t, path)
        end
      end
    end
  end

  def get_string(_, _) do
    raise "Tonka.Service.Credentials must be derived"
  end
end
