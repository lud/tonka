defmodule Tonka.Actions.Render.IssuesGroupsBookletRenderer do
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.Blocks.Section
  alias Tonka.Data.IssuesGroup
  import Tonka.Gettext
  use Tonka.Core.Action

  def cast_params(term) do
    {:ok, term}
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:issues_groups, {:list, IssuesGroup})
    |> Action.use_service(:people, Tonka.Data.People)
  end

  def call(%{issues_groups: issues_groups}, %{people: people}, _params) do
    blocks = Enum.map(issues_groups, fn group -> group_to_blocks(group, people) end)
    booklet_result = blocks |> Booklet.splat_list() |> Booklet.from_blocks()

    booklet_result
  end

  defp group_to_blocks(group, people) do
    %{title: title, remain: remain, issues: issues} = group

    {Section,
     header: String.replace(title, "*", ""),
     content: [
       {:ul,
        for issue <- issues do
          issue_item(issue, people)
        end}
     ],
     footer:
       if remain && remain > 0 do
         ngettext(
           "tonka.IssuesGroupsBookletRenderer.remaining_issue",
           "tonka.IssuesGroupsBookletRenderer.remaining_issues",
           remain
         )
       end}
  end

  defp issue_item(issue, people) do
    iid = format_iid(issue.iid)

    case format_assignee(issue, people) do
      {:ok, assignee} -> [{:link, issue.url, [iid, issue.title]}, " – ", assignee]
      :error -> {:link, issue.url, [iid, issue.title]}
    end
  end

  defp format_assignee(%{assignee_user_id: nil}, _) do
    :error
  end

  defp format_assignee(%{assignee_user_id: user_id}, people) do
    Tonka.Data.People.fetch(people, user_id)
  end

  # defp format_assignee(%{assignee_user_id: nil}) do

  # end

  # This iid already contains the "#" character
  defp format_iid(nil), do: ""
  defp format_iid(iid), do: "#{iid} "
end
