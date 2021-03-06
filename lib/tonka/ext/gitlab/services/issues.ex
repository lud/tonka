defmodule Tonka.Ext.Gitlab.Services.Issues do
  use Tonka.Core.Service
  alias Tonka.Data.Issue
  alias Tonka.Data.People
  require Tonka.Project.ProjectLogger, as: Logger
  alias Tonka.Services.IssuesSource

  use TODO

  @enforce_keys [:projects, :private_token, :people]
  @behaviour IssuesSource
  @derive IssuesSource
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          projects: [binary()],
          private_token: binary,
          people: People.t()
        }

  @print_queries false
  @pretty_queries @print_queries

  @params_caster Hugs.build_props()
                 |> Hugs.field(:projects, type: {:list, :binary}, required: true)
                 |> Hugs.field(:credentials, type: :binary, required: true)

  @impl Service
  def service_type,
    do: IssuesSource

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @impl Service
  def cast_params(params) do
    Hugs.denormalize(params, @params_caster)
  end

  @impl Service
  def configure(config) do
    config
    |> use_service(:credentials, Tonka.Services.Credentials)
    |> use_service(:people, People)
  end

  @impl Service
  def build(%{credentials: credentials, people: people}, %{credentials: path, projects: projects}) do
    case Tonka.Services.Credentials.get_string(credentials, path) do
      {:ok, token} -> {:ok, new(private_token: token, projects: projects, people: people)}
      {:error, _} = err -> err
    end
  end

  @impl IssuesSource
  def fetch_all_issues(%__MODULE__{} = gitlab) do
    %__MODULE__{people: people, private_token: token} = gitlab
    client = build_http_client(token)

    with {:ok, projects_issues} <-
           Ark.Ok.map_ok(gitlab.projects, &fetch_project_issues(client, &1)) do
      all = projects_issues |> Enum.concat() |> Enum.map(&put_people(&1, people))
      {:ok, all}
    end
  end

  def put_people(%Issue{} = issue, people) do
    issue =
      with last_ext when is_binary(last_ext) <- issue.last_ext_username,
           {:ok, person} <- People.find_by(people, "gitlab.username", last_ext) do
        Map.put(issue, :last_user_id, person.id)
      else
        _ -> issue
      end

    issue =
      with assignee_ext when is_binary(assignee_ext) <- issue.assignee_ext_username,
           {:ok, person} <- People.find_by(people, "gitlab.username", assignee_ext) do
        Map.put(issue, :assignee_user_id, person.id)
      else
        _ -> issue
      end

    issue
  end

  @todo "remove hackish cache"
  defp build_http_client(token) when is_binary(token) do
    headers = [{"authorization", "Bearer #{token}"}]

    middleware = [
      {Tesla.Middleware.BaseUrl, "https://gitlab.com/api/graphql"},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, headers},
      Tonka.Utils.TeslaCache,
      {Tesla.Middleware.Logger, debug: false}
    ]

    Tesla.client(middleware)
  end

  defp fetch_project_issues(client, slug) when is_binary(slug) do
    case fetch_all_pages(client, slug, nil, []) do
      {:ok, raw_issues} -> build_issues(raw_issues)
      {:error, _} = err -> err
    end
  end

  defp fetch_all_pages(client, slug, prev_cursor, acc) do
    case fetch_issues_page(client, slug, prev_cursor) do
      {:ok, %{"project" => nil}} ->
        {:error, "gitlab project '#{slug}' not found"}

      {:ok,
       %{
         "project" => %{
           "issues" => %{"edges" => edges, "pageInfo" => page_info}
         }
       }} ->
        issues = get_in(edges, [Access.all(), "node"])

        # Adding the current pages issues onto the acc. The acc will have to
        # be flatenned
        acc = [issues | acc]

        if Map.fetch!(page_info, "hasNextPage") do
          end_cursor = Map.fetch!(page_info, "endCursor")
          fetch_all_pages(client, slug, end_cursor, acc)
        else
          {:ok, :lists.flatten(acc)}
        end

      {:error, _} = err ->
        Logger.warn("Unknown error when fetching issues: #{inspect(err)}")
        err
    end
  end

  defp fetch_issues_page(client, slug, prev_cursor) do
    query = issues_page_query(slug, prev_cursor)
    run_query(client, query)
  end

  defp run_query(client, query) do
    case Tesla.post(client, "", %{query: query}) do
      {:ok, response} -> cast_query_result(response.body)
      {:error, _} = err -> err
    end
  end

  defp cast_query_result(%{"errors" => errors}) do
    {:error, {__MODULE__, :graphql_errors, errors}}
  end

  defp cast_query_result(%{"data" => data}) do
    {:ok, data}
  end

  defp issues_page_query(project_slug, prev_cursor) do
    issues_args = %{sort: :updated_desc}

    issues_args =
      if prev_cursor do
        Map.put(issues_args, :after, prev_cursor)
      else
        issues_args
      end

    query =
      {"project", [fullPath: project_slug],
       [
         {"issues", issues_args,
          [
            pageInfo: ["endCursor", "startCursor", "hasNextPage"],
            edges: [node: issue_content_query()]
          ]}
       ]}
      |> Tonka.Core.Query.GraphQL.format_query(pretty: @pretty_queries)

    if @print_queries, do: print_query(query)
    query
  end

  defp issue_content_query do
    [
      "title",
      "id",
      "iid",
      "timeEstimate",
      "webUrl",
      "updatedAt",
      "state",
      "userNotesCount",
      # notes are always sorted by descending date
      {"notes", [first: 1],
       [
         edges: [
           node: ["id", "body", "system", {"author", ["username"]}]
         ]
       ]},
      {"labels", edges: [node: ["title"]]},
      {"assignees", edges: [node: ["id", "name", "username"]]}
    ]
  end

  defp build_issues(raw_issues) do
    issues = for raw <- raw_issues, do: raw_to_issue(raw)

    {:ok, issues}
  end

  def print_query(query) when is_binary(query) do
    IO.puts([IO.ANSI.cyan(), query, IO.ANSI.default_color()])
  end

  defp raw_to_issue(raw) do
    [
      id: raw["id"],
      iid: "#" <> raw["iid"],
      last_ext_username: extract_last_username(raw),
      assignee_ext_username: extract_assignee_username(raw),
      labels: extract_labels(raw),
      url: raw["webUrl"],
      title: raw["title"],
      updated_at: parse_date!(raw["updatedAt"]),
      status: cast_status(raw["state"])
    ]
    |> Keyword.filter(fn {_, v} -> v != nil end)
    |> Issue.new()
  end

  defp extract_last_username(raw_issue) do
    case raw_issue do
      %{
        "notes" => %{
          "edges" => [%{"node" => %{"author" => %{"username" => name}}} | _]
        }
      } ->
        name

      _ ->
        nil
    end
  end

  defp extract_assignee_username(raw_issue) do
    case raw_issue do
      %{
        "assignees" => %{
          "edges" => [%{"node" => %{"username" => username}} | _]
        }
      } ->
        username

      _ ->
        nil
    end
  end

  defp extract_labels(raw_issue) do
    case raw_issue do
      %{"labels" => %{"edges" => labels}} ->
        for %{"node" => %{"title" => label}} <- labels, do: label

      _ ->
        nil
    end
  end

  defp cast_status("closed"), do: "closed"
  defp cast_status(_), do: "open"

  defp parse_date!(bin) when is_binary(bin) do
    case DateTime.from_iso8601(bin) do
      {:ok, dt, _} -> dt
      _ -> raise "Could not parse '#{bin}' as DateTime"
    end
  end
end
