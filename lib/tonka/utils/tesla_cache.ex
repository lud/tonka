defmodule Tonka.Utils.TeslaCache do
  @behaviour Tesla.Middleware

  @dir Path.join([File.cwd!(), "var", "http-cache"])
  File.mkdir_p!(@dir)
  @impl Tesla.Middleware

  def call(env, next, _options) do
    key = hash(env.url) <> "." <> hash(env.body)

    case fetch_cache(key) do
      :miss ->
        env
        |> Tesla.run(next)
        |> maybe_write(key)

      {:hit, response} ->
        {:ok, response}
    end
  end

  defp fetch_cache(key) do
    path = file(key)

    if File.exists?(path) do
      data =
        path
        |> File.read!()
        |> :erlang.binary_to_term()

      {:hit, data}
    else
      :miss
    end
  end

  defp maybe_write({:ok, %Tesla.Env{body: ~s({"data":{"project":null}}) <> _} = resp}, key) do
    {:ok, resp}
  end

  defp maybe_write({:ok, %Tesla.Env{status: status} = resp}, key) when status < 300 do
    path = file(key)

    IO.puts("write file #{path}")
    bin = :erlang.term_to_binary(resp)

    File.write!(path, bin)
    {:ok, resp}
  end

  defp maybe_write({:ok, resp}, _key) do
    {:ok, resp}
  end

  defp maybe_write(other, _key) do
    IO.warn("bad data #{inspect(other)}")
    other
  end

  defp hash(str) do
    :crypto.hash(:md5, str) |> Base.encode16()
  end

  defp file(key) do
    Path.join(@dir, "#{key}.resp")
  end
end
