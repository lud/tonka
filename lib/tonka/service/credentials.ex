require Tonka.Core.StructDispatch

Tonka.Core.StructDispatch.defdispatch Tonka.Service.Credentials do
  # defprotocol Tonka.Service.Credentials do
  @doc """
  Returns the credentials value stored under `path`.
  """
  @spec get_string(t, binary) :: {:ok, binary} | {:error, :not_a_string | :not_found | term}
  def get_string(t, path)
end

# defimpl Tonka.Service.Credentials, for: Any do
#   defmacro __deriving__(module, struct, _options) do
#     quote location: :keep do
#       defimpl Tonka.Service.Credentials, for: unquote(module) do
#         def get_string(t, path) do
#           unquote(struct.__struct__).get_string(t, path)
#         end
#       end
#     end
#   end

#   def get_string(_, _) do
#     raise "Tonka.Service.Credentials must be derived"
#   end
# end

# Tonka.Core.StructDispatch.defdispatch Tonka.Service.MyProto do
#   @spec get_string(t, binary) :: {:ok, binary} | {:error, :not_a_string | :not_found | term}
#   def get_string(t, path)
# end

# defmodule AProt do
#   @derive Tonka.Service.MyProto
#   defstruct [:lol]
# end
