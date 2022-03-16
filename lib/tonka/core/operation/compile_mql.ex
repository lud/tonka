defmodule Tonka.Core.Operation.CompileMql do
  @moduledoc """

  """
  use Tonka.Core.Operation

  output {:collection, Tonka.Data.IssueGroup}
  # input mql in Tonka.Data.MqlQuery

  call do
    {:ok, []}
  end
end
