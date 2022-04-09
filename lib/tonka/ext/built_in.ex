defmodule Tonka.Ext.BuiltIn do
  @moduledoc """
  Extension that contains the builtin services and actions
  """
  @behaviour Tonka.Extension

  @impl Tonka.Extension
  def services do
    %{
      "core.issues_store" => Tonka.Services.IssuesStore
    }
  end

  @impl Tonka.Extension
  def actions do
    %{
      "core.query.mql.queries_groups_compiler" => Tonka.Actions.Queries.QueriesGroupsMQLCompiler,
      "core.render.booklet.issues_groups" => Tonka.Actions.Render.IssuesGroupsBookletRenderer,
      "core.query.issues_groups_reader" => Tonka.Actions.Queries.IssuesGroupsReader,
      "core.render.booklet_wrapper" => Tonka.Actions.Render.BookletWrapper
    }
  end
end
