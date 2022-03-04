defmodule Tonka.Core.Container do
  @moduledoc """
  Implements a container for data structures or functions providing
  functionality to any `Tonka.Core.Operation`.
  """

  @type typealias :: module

  @type f_params ::
          {typespec}
          | {typespec, typespec}
          | {typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec, typespec, typespec}

  @type typespec :: typealias | {f_params, typespec} | {:struct, module}
end
