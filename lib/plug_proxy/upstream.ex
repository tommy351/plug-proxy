defmodule PlugProxy.Upstream do
  import PlugProxy, only: [format_url: 1]

  def init(opts) do
    Keyword.put(opts, :url, Keyword.get(opts, :url) |> url_fun)
  end

  def call(conn, opts) do
    PlugProxy.call(conn, opts)
  end

  defp url_fun(uri) when is_list(uri) do
    {:ok, {scheme, _, host, port, path, query}} = uri
    host = List.to_string(host)
    path = List.to_string(path)
    query = List.to_string(query)

    fn conn ->
      format_url(%{conn | scheme: scheme,
                          host: host,
                          port: port,
                          request_path: append_path(path, conn.request_path),
                          query_string: append_query_string(query, conn.query_string)})
    end
  end

  defp url_fun(uri) when is_binary(uri) do
    url_fun(String.to_charlist uri)
  end

  defp append_path(target, path) do
    if String.ends_with?(target, "/") do
      target <> path
    else
      target <> "/" <> path
    end
  end

  defp append_query_string("?" <> target, query), do: target <> query
  defp append_query_string("", query), do: query
end
