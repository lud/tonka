defmodule TonkaWeb.ErrorViewTest do
  use TonkaWeb.Test.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  @tag :skip
  test "renders 404.json" do
    assert render(TonkaWeb.ErrorView, "404.json", []) == %{errors: %{detail: "Not Found"}}
  end

  @tag :skip
  test "renders 500.json" do
    assert render(TonkaWeb.ErrorView, "500.json", []) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
