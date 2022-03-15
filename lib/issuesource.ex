import Ark.Interface

definterface Tonka.Service.IssuesSource do
  @doc """
  Returns the credentials value stored under `path`.
  """
  @spec fetch_all_issues(t) :: {:ok, [Tonka.Data.Issue.t()]} | {:error, term}
  def fetch_all_issues(t)

  @spec mql_query(t, term) :: {:ok, [Tonka.Data.Issue.t()]} | {:error, term}
  def mql_query(t, term)

  Kernel.def(expand_type, do: {:remote_type, __MODULE__, :t})
end
