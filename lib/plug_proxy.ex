defmodule PlugProxy do
  import Plug.Conn, only: [read_body: 2]
  alias PlugProxy.BadGatewayError
  alias PlugProxy.GatewayTimeoutError

  @methods ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    case send_req(conn, opts) do
      {:ok, client} ->
        conn
        |> write_proxy(client)
        |> read_proxy(client)

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end

  for method <- @methods do
    defp method_atom(unquote(method)), do: unquote(method |> String.downcase |> String.to_atom)
  end

  defp send_req(conn, opts) do
    url_fun = Keyword.get(opts, :url, &format_url/1)
    url = get_url(url_fun, conn)

    :hackney.request(method_atom(conn.method), url, prepare_headers(conn), :stream, opts)
  end

  defp scheme(str) when is_binary(str), do: str
  defp scheme(:http), do: "http"
  defp scheme(:https), do: "https"
  defp scheme(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp get_url(fun, conn) when is_function(fun) do
    fun.(conn)
  end

  defp get_url(url, conn) when is_binary(url) do
    uri = URI.parse(url)
    query = uri.query || ""
    path = String.trim_trailing(uri.path || "", "/")

    format_url(%{
      scheme: uri.scheme || conn.scheme,
      host: uri.host || conn.host,
      port: uri.port || conn.port,
      request_path: format_path(path, conn.request_path),
      query_string: format_query_string(query, conn.query_string)
    })
  end

  defp format_path(target, "/" <> path), do: format_path(target, path)
  defp format_path(target, path), do: "#{target}/#{path}"

  defp format_query_string("", query), do: query
  defp format_query_string(target, query), do: "#{target}&#{query}"

  defp format_url(conn) do
    "#{scheme conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}"
    |> append_query_string(conn.query_string)
  end

  defp append_query_string(url, ""), do: url
  defp append_query_string(url, query_string), do: "#{url}?#{query_string}"

  defp prepare_headers(conn) do
    conn.req_headers
  end

  defp write_proxy(conn, client) do
    case read_body(conn, [])  do
      {:ok, body, conn} ->
        :hackney.send_body(client, body)
        :hackney.finish_send_body(client)
        conn

      {:more, body, conn} ->
        :hackney.send_body(client, body)
        write_proxy(conn, client)

      {:error, :timeout} ->
        raise GatewayTimeoutError

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end

  defp read_proxy(conn, client) do
    case :hackney.start_response(client) do
      {:ok, status, headers, client} ->
        {headers, length} = process_headers(headers)

        %{conn | status: status}
        |> reply(client, headers, length)

      {:error, :timeout} ->
        raise GatewayTimeoutError

      err ->
        raise BadGatewayError, reason: err
    end
  end

  defp process_headers(headers) do
    process_headers(headers, [], 0)
  end

  defp process_headers([], acc, length) do
    {Enum.reverse(acc), length}
  end

  defp process_headers([{key, value} | tail], acc, length) do
    process_headers(String.downcase(key), value, tail, acc, length)
  end

  defp process_headers("content-length", value, headers, acc, length) do
    length = case Integer.parse(value) do
      {int, ""} -> int
      _ -> length
    end

    process_headers(headers, acc, length)
  end

  defp process_headers("transfer-encoding", "chunked", headers, acc, _) do
    process_headers(headers, acc, :chunked)
  end

  defp process_headers(key, value, headers, acc, length) do
    process_headers(headers, [{key, value} | acc], length)
  end

  defp reply(conn, client, headers, :chunked) do
    conn = before_send(conn, headers, :chunked)
    {adapter, req} = conn.adapter
    {:ok, req} = :cowboy_req.chunked_reply(conn.status, conn.resp_headers, req)
    chunked_reply(conn, client, req)
    %{conn | adapter: {adapter, req}}
  end

  defp reply(conn, client, headers, length) do
    body_fun = fn(socket, transport) ->
      stream_reply(conn, client, socket, transport)
    end

    conn = before_send(conn, headers, :set)
    {adapter, req} = conn.adapter
    {:ok, req} = :cowboy_req.reply(conn.status, conn.resp_headers, :cowboy_req.set_resp_body_fun(length, body_fun, req))
    %{conn | adapter: {adapter, req}, state: :sent}
  end

  defp chunked_reply(conn, client, req) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        :cowboy_req.chunk(data, req)
        chunked_reply(conn, client, req)

      :done ->
        :ok

      {:error, _reason} ->
        # TODO: error handling
        :ok
    end
  end

  defp stream_reply(conn, client, socket, transport) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        transport.send(socket, data)
        stream_reply(conn, client, socket, transport)

      :done ->
        :ok

      {:error, _reason} ->
        # TODO: error handling
        :ok
    end
  end

  defp before_send(%Plug.Conn{before_send: before_send} = conn, headers, state) do
    conn = %{conn | resp_headers: headers, state: state}
    Enum.reduce(before_send, conn, &(&1.(&2)))
  end
end
