defmodule Tonka.Core.InputCaster.NilInput do
  use Tonka.Core.InputCaster

  output {:type, {:atom, nil}}

  def output_spec() do
    %Tonka.Core.Container.ReturnSpec{type: {:type, {:atom, nil}}}
  end

  call _ do
    {:ok, nil}
  end
end
