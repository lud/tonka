defmodule Tonka.Services.ServiceSupervisor do
  @moduledoc """
  A generic one_for_one supervisor with an API dedicated to start process-based
  services within a project.
  """
  use Supervisor
end
