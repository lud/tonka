defmodule Tonka.Test.Fixtures.BunchOfFunctions do
  @type some_map :: %{
          :a_key => binary,
          :other_key => integer
        }

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

  @spec accepts_fun_and_arg((integer -> binary), integer) :: binary
  def accepts_fun_and_arg(f, arg) do
    f.(arg)
  end
end
