import Ark.Interface

definterface Tonka.Services.IssuesSource do
  @doc """
  Returns the credentials value stored under `path`.
  """
  @spec fetch_all_issues(t) :: {:ok, [Tonka.Data.Issue.t()]} | {:error, term}
  def fetch_all_issues(t)
end
