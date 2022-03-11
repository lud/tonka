import Ark.Interface

definterface Tonka.Service.Credentials do
  @doc """
  Returns the credentials value stored under `path`.
  """
  @spec get_string(t, binary) :: {:ok, binary} | {:error, :not_a_string | :not_found | term}
  def get_string(t, path)
end
