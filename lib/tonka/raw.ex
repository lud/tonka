defmodule Tonka.Raw do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.Params
  alias Tonka.Core.Grid
  alias Tonka.Core.Operation
  import Container

  """
  -----------------------------------------------------------------------------

  We need to define operations as follows in the project layout.

  Each input is mapped to an origin. It can be an operation output, or it can
  be a litteral value.

  The input specs from an operation must define the possible origins for each
  input.  Some inputs may only originate from an operation, others only from a
  literal value (which should then be a param, but whatever).

  If the operation defines an input to be a literal, it must export a
  cast_input(:my_key, term) function that will return a term of the expected
  type.

  In the UI, the literal inputs my be embedded into the configuration of an
  operation, along with the params.

  We need the params to build the inject specs, so we can select a service based
  on a name. Some project may define two issues sources, for instance Github and
  Gitlab, so we need a param to tell which one to use.

  params:
    source: my_issues_source
  inputs:
    vars:
      origin: operation_output
      operation: my_other_op
    report:
      origin: literal
      literal: ~

  params {
    source = my_issues_source;
  }
  inputs vars {
    origin = operation_output;
    operation = my_other_op;
  inputs report {
    origin = literal;
    literal = ... some complex query ...;
  }

  -----------------------------------------------------------------------------
  """
  |> raise

  def run do
    credentials = build_credentials()

    issues_store =
      build_issues_store(credentials, "gitlab.private_token", ["company-agilap/r-d/agislack"])

    report_config = build_report_config()
    query_groups = build_query_groups(%{"todo_label" => "todo"})

    # gitlab = issues_repository(params)
    # issues_source = issues_fetch_all(gitlab)
    # queries = map(params_groups, compile_mql)
    # issues = filter_issues(issues_source, query)
    # report = generate_report(issues, params)
    # target = team_member(name)
    # post = encode_slack_rich(report)
    # transport = slack(target)
    # post(transport, post)
    query_groups |> IO.inspect(label: "query_groups", pretty: true)
  end

  defp build_credentials do
    File.cwd!()
    |> Path.join("var/projects/dev/credentials.json")
    |> Tonka.Service.Credentials.JsonFileCredentials.from_path!()
  end

  defp build_issues_store(credentials, creds_path, projects) do
    token = Tonka.Service.Credentials.get_string(credentials, creds_path)
    Tonka.Ext.Gitlab.Issues.new(projects: projects, private_token: token)
  end

  defp build_report_config() do
    report = """
    title: 'Issues report'
    intro: |-
    Those issues may require your attention.
    They require some work!
    outro: |-
    Thank you for *reading* :ghost:
    """
  end

  defp build_query_groups(vars) do
    atom_keys =
      Tonka.Data.Issue.__struct__()
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.map(&Atom.to_string/1)

    """
    - title: TODO List
      query:
        labels: '{{todo_label}}'
      limit: 1
    """
    |> YamlElixir.read_from_string!()
    |> Tonka.Renderer.BBMustache.render_tree(vars)
    |> Enum.map(fn group ->
      group
      |> Hugs.denormalize(
        Hugs.build_props()
        |> Hugs.field(:limit, type: :integer)
        |> Hugs.field(:title, type: :binary)
        |> Hugs.field(:query, type: :map)
      )
      |> Ark.Ok.uok!()
      |> Map.update!(
        :query,
        &Tonka.Core.Query.MQL.compile!(&1, as_atoms: atom_keys)
      )
    end)
  end
end
