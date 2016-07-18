defmodule PlugProxyTest.Proxy do
  import Plug.Conn
  use Plug.Router

  plug :before_send

  plug :match
  plug :dispatch

  get "/f/fun/:path" do
    url_fun = fn _, _ ->
      "http://localhost:4000/a/#{String.reverse path}"
    end

    opts = PlugProxy.init(url: url_fun)
    PlugProxy.call(conn, opts)
  end

  forward "/f/query",  to: PlugProxy, upstream: "http://localhost:4000?a=1"
  forward "/f/path",   to: PlugProxy, upstream: "http://localhost:4000/a/"
  forward "f/literal", to: PlugProxy, url: "http://localhost:4000"
  forward "/",         to: PlugProxy, upstream: "http://localhost:4000"

  defp before_send(conn, _) do
    register_before_send(conn, fn conn ->
      put_resp_header(conn, "x-before-send", "before send")
    end)
  end
end
