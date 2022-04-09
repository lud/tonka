defmodule Tonka.Ext.Gitlab do
  @behaviour Tonka.Extension

  @impl Tonka.Extension
  def services do
    %{"ext.gitlab.issues" => Tonka.Ext.Gitlab.Services.Issues}
  end

  @impl Tonka.Extension
  def actions do
    %{}
  end
end
