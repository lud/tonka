defmodule Tonka.Actions.Render.BookletFromIssuesGroups do
  use Tonka.Core.Action
  alias Tonka.Data.IssuesGroup
  alias Tonka.Core.Booklet

  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  import Tonka.Gettext

  def cast_params(term) do
    {:ok, term}
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:issues_groups, {:list, IssuesGroup})
  end

  def call(%{issues_groups: issues_groups}, _, _params) do
    blocks = Enum.map(issues_groups, fn group -> group_to_blocks(group) end)
    booklet_result = blocks |> Booklet.splat_list() |> Booklet.from_blocks()

    with {:ok, booklet} <- booklet_result do
      Tonka.Core.Booklet.CliRenderer.render!(booklet) |> IO.puts()
    end

    booklet_result
  end

  defp group_to_blocks(group) do
    %{title: title, remain: remain, issues: issues} = group

    {Section,
     header: String.replace(title, "*", ""),
     content: [
       {:ul,
        for issue <- issues do
          iid = format_iid(issue.iid)
          {:link, issue.url, [iid, issue.title]}
        end}
     ],
     footer:
       if remain && remain > 0 do
         ngettext(
           "tonka.BookletFromIssuesGroups.remaining_issue",
           "tonka.BookletFromIssuesGroups.remaining_issues",
           remain
         )
       end}
  end

  # This iid already contains the "#" character
  defp format_iid(nil), do: ""
  defp format_iid(iid), do: "#{iid} "
end