defprotocol Tonka.Services.CleanupStore.Hashable do
  @spec hashable(t) :: iodata()
  @doc """
  Returns a value that will be used to computes hashes for the cleanup store.
  """
  def hashable(t)
end

defimpl Tonka.Services.CleanupStore.Hashable, for: List do
  def hashable(list), do: Enum.map(list, &Tonka.Services.CleanupStore.Hashable.hashable/1)
end

defimpl Tonka.Services.CleanupStore.Hashable, for: BitString do
  # this does not actually support bitstrings, only binaries
  def hashable(string), do: string
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Map do
  def hashable(map) do
    map
    |> Map.to_list()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Tuple do
  def hashable(tuple) do
    tuple
    |> Tuple.to_list()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Atom do
  def hashable(atom) do
    # Atoms supports utf8 in elixir, to not use to_charlist
    atom
    |> Atom.to_string()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Integer do
  def hashable(int), do: int
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Integer do
  def hashable(int) when int < 0 when int > 255 do
    int
    |> Integer.to_charlist()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end

  def hashable(int),
    do: int
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Float do
  def hashable(float) do
    float
    |> Float.to_charlist()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end
