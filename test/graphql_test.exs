defmodule Tonka.GraphQLTest do
  use ExUnit.Case, async: true
  alias Tonka.Core.Query.GraphQL

  test "basic queries" do
    expected =
      """
      query {
        a {
          b
        }
      }
      """
      |> String.trim()

    assert format([{"a", ["b"]}], pretty: true) ===
             expected
  end

  test "basic queries 2" do
    expected =
      """
      query {
        a {
          b
          c
        }
      }
      """
      |> String.trim()

    assert format([{:a, ~w(b c)}], pretty: true) === expected
  end

  @tag :skip
  test "basic queries 3" do
    expected =
      """
      query {
        a(sort: desc) {
          b
          c
        }
      }
      """
      |> String.trim()

    assert format(%{{:a, sort: :desc} => ["b", :c]}, pretty: true) === expected
  end

  @tag :skip
  test "empty args or bodies" do
    assert format(%{{:a, nil} => ["b", :c]}) === "query { a { b c } }"
    assert format(%{{:a, []} => ["b", :c]}) === "query { a { b c } }"
    assert format(%{{:a, %{}} => ["b", :c]}) === "query { a { b c } }"
    assert format(%{:a => []}) === "query { a }"
  end

  @tag :skip
  test "list with tupes" do
    assert format(%{:a => ["b", {:c, ["d", "e"]}]}) ===
             "query { a { b c { d e } } }"

    assert format(%{:a => ["b", {{:c, x: 1}, ["d", "e"]}]}) ===
             "query { a { b c(x: 1) { d e } } }"
  end

  @tag :skip
  test "strange behaviour" do
    expected = "query { a { b { c } } }"
    assert expected === format(%{"a" => %{"b" => "c"}})
    assert expected === format(%{"a" => {"b", "c"}})
    assert expected === format(%{"a" => [{"b", "c"}]})
  end

  defp format(query, opts \\ []) do
    _v = GraphQL.format_query(query, opts)
  end

  @tag :skip
  test "can format a query" do
    query = %{
      # tuple-keys allow to put arguments. Map body allows to have children
      # query objects
      {:project, fullPath: "company-agilap/r-d/agislack"} => %{
        # atom values will not be quoted
        {:issues, sort: :updated_desc} => %{
          # simple keys will not have arguments
          # lists can be used if no child has children or arguments.
          # atom or string names will never be quoted
          pageInfo: ["endCursor", :startCursor, "hasNextPage"],
          # If mixing with leaves and sub-objects, an empty list can be used to
          # mark a child a a leaf.
          edges: %{
            node: %{
              :title => [],
              :id => [],
              :timeEstimate => [],
              :webUrl => [],
              :userNotesCount => [],
              {:notes, first: 1} => %{
                edges: %{
                  node: %{id: [], body: [], system: [], author: ["username"]}
                }
              }
            }
          }
        }
      }
    }

    expected = """
    query {
      project(fullPath: "company-agilap/r-d/agislack") {
        issues(sort: updated_desc) {
          edges {
            node {
              id
              notes(first: 1) {
                edges {
                  node {
                    author {
                      username
                    }
                    body
                    id
                    system
                  }
                }
              }
              timeEstimate
              title
              userNotesCount
              webUrl
            }
          }
          pageInfo {
            endCursor
            hasNextPage
            startCursor
          }
        }
      }
    }
    """

    generated = format(query, pretty: true, sort: true)

    assert String.trim(generated) ===
             String.trim(expected)
  end
end
