defmodule Tonka.Test.Fixtures.BunchOfFunctions do
  @spec validate_integer(term) :: {:ok, integer} | {:error, :not_an_int}
  def validate_integer(term) do
    if is_integer(term),
      do: {:ok, term},
      else: {:error, :not_an_int}
  end

  @spec two_args(binary | [char] | charlist, integer) :: atom
  def two_args(text, num) do
    String.to_existing_atom(to_string(text) <> Integer.to_string(num))
  end
end
