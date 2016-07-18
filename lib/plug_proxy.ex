defmodule PlugProxy do
  @moduledoc """
  A plug for reverse proxy server.

  PlugProxy pipeline the request to the upstream, and the response will be sent with
  [ranch](https://github.com/ninenines/ranch) transport which is highly efficient.

  ## Options

    - `:upstream` - Upstream URL string. Additional path and query string will be prefixed.
    - `:url` - URL string or a function which returns an URL

  Additional options will be passed to hackney. You can see [:hackney.request/5](https://github.com/benoitc/hackney/blob/master/doc/hackney.md#request5)
  for available options.

  ## Examples

  Forward requests to a upstream.

      forward "/v2", to: PlugProxy, upstream: "http://example.com/"
      \# http://localhost:4000/v2/test => http://example.com/v2/test

      forward "/v2", to: PlugProxy, upstream: "http://example.com/abc/"
      \# http://localhost:4000/v2/test => http://example.com/abc/v2/test

      forward "/v2", to: PlugProxy, upstream: "http://example.com?a=1"
      \# http://localhost:4000/v2/test?b=2 => http://example.com/v2/test?a=1&b=2

  Return URL in a function.

      get "/v2/:id", do
        url_fun = fn conn, opts ->
          "http://example.com/a/" <> String.reverse(id)
        end

        opts = PlugProxy.init(url: url_fun)
        PlugProxy.call(conn, opts)
      end
      \# http://localhost:4000/v2/123 => http://example.com/a/321
  """

  import Plug.Conn, only: [read_body: 2]
  alias PlugProxy.BadGatewayError
  alias PlugProxy.GatewayTimeoutError

  @methods ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

  @doc false
  def init(opts) do
    opts
    |> parse_upstream(Keyword.get(opts, :upstream))
  end

  @doc false
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
    url_fun = Keyword.get(opts, :url, &format_url/2)
    url = get_url(url_fun, conn, opts)

    :hackney.request(method_atom(conn.method), url, prepare_headers(conn), :stream, opts)
  end

  defp parse_upstream(opts, upstream) when is_binary(upstream) do
    uri = URI.parse(upstream)
    uri = %{uri | query: uri.query || "",
                  path: String.replace_trailing(uri.path || "", "/", "")}

    Keyword.put(opts, :upstream, uri)
  end

  defp parse_upstream(opts, _), do: opts

  defp get_url(url, conn, opts) when is_function(url) do
    url.(conn, opts)
  end

  defp get_url(url, _, _), do: url

  defp format_url(conn, opts) do
    upstream = Keyword.get(opts, :upstream)
    scheme = scheme_str(upstream.scheme || conn.scheme)
    host = upstream.host || conn.host
    port = upstream.port || conn.port
    path = format_path(upstream.path, conn.request_path)
    query = format_query_string(upstream.query, conn.query_string)

    "#{scheme}://#{host}:#{port}#{path}"
    |> append_query_string(query)
  end

  for scheme <- [:http, :https] do
    defp scheme_str(unquote(scheme)), do: unquote(Atom.to_string(scheme))
  end

  defp scheme_str(scheme), do: to_string(scheme)

  defp format_path(target, "/" <> path), do: format_path(target, path)
  defp format_path(target, path), do: "#{target}/#{path}"

  defp format_query_string("", query), do: query
  defp format_query_string(target, query), do: "#{target}&#{query}"

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
