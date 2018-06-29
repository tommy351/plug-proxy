defmodule PlugProxyTest do
  use ExUnit.Case, async: true

  defp proxy_url(mod) do
    conf = Application.get_env(:plug_proxy, mod, [])
    port = Keyword.get(conf, :port)

    "http://localhost:#{port}"
  end

  defp request(), do: request([])

  defp request(options) when is_list(options) do
    request(PlugProxyTest.Proxy, options)
  end

  defp request(mod, options \\ []) when is_atom(mod) and is_list(options) do
    method = Keyword.get(options, :method, :get)
    path = Keyword.get(options, :path, "/")
    headers = Keyword.get(options, :headers, [])
    body = Keyword.get(options, :body, "")
    url = proxy_url(mod)

    case :hackney.request(method, url <> path, headers, body, options) do
      {:ok, status, headers, client} -> {status, headers, client}
      {:ok, client} -> client
    end
  end

  test "get" do
    {_, _, client} = request()
    {:ok, body} = :hackney.body(client)

    assert body == "ok"
  end

  test "post" do
    {_, _, client} = request(method: :post, path: "/submit", body: "test")
    {:ok, body} = :hackney.body(client)

    assert body == "test"
  end

  test "query string" do
    query = "a=1&b=2"
    {_, _, client} = request(path: "/query?#{query}")
    {:ok, body} = :hackney.body(client)

    assert body == query
  end

  test "request header" do
    header = "foooo"

    {_, _, client} =
      request(
        path: "/header",
        headers: [
          {"x-request-header", header}
        ]
      )

    {:ok, body} = :hackney.body(client)

    assert body == header
  end

  test "response header" do
    {_, headers, _} = request(path: "/header")
    {_, header} = List.keyfind(headers, "x-response-header", 0)

    assert header == "response ok"
  end

  test "chunk" do
    {_, headers, client} = request(path: "/chunk")
    {:ok, body} = :hackney.body(client)
    {_, header} = List.keyfind(headers, "transfer-encoding", 0)

    assert body == "123"
    assert header == "chunked"
  end

  test "run before_send plugs" do
    {_, headers, _} = request()
    {_, header} = List.keyfind(headers, "x-before-send", 0)

    assert header == "before send"
  end

  test "not found" do
    {status, _, client} = request(path: "/nothing")
    {:ok, body} = :hackney.body(client)

    assert body == "not found"
    assert status == 404
  end

  test "append query string" do
    {_, _, client} = request(path: "/f/query?c=3")
    {:ok, body} = :hackney.body(client)

    assert body == "a=1&c=3"
  end

  test "append path" do
    {_, _, client} = request(path: "/f/path/b/c")
    {:ok, body} = :hackney.body(client)

    assert body == "/a/f/path/b/c"
  end

  test "url function" do
    {_, _, client} = request(path: "/f/fun/abc")
    {:ok, body} = :hackney.body(client)

    assert body == "/a/cba"
  end

  test "literal url" do
    {_, _, client} = request(path: "/f/literal")
    {:ok, body} = :hackney.body(client)

    assert body == "ok"
  end

  test "bad gateway - nxdomain" do
    {status, _, client} = request(path: "/e/gateway")
    {:ok, body} = :hackney.body(client)

    assert status == 502
    assert body == "nxdomain"
  end

  test "gateway timeout - read" do
    {status, _, client} = request(path: "/e/timeout/read")
    {:ok, body} = :hackney.body(client)

    assert status == 504
    assert body == "read"
  end
end
