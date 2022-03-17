defmodule Tonka.Core.InputCaster.NilInput do
  def output_spec() do
    %Tonka.Core.Container.ReturnSpec{type: {:type, {:atom, nil}}}
  end
end
