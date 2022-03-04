defmodule Tonka.Core.Container do
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
