defprotocol Tonka.Service.Credentials do
  @doc """
  Returns the credentials value stored under `path`.
  """
  @spec get_path(t, binary) :: binary
  def get_path(t, path)
end
