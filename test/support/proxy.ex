defmodule PlugProxyTest.Proxy do
  import Plug.Conn
  use Plug.Router

  plug :before_send

  plug :match
  plug :dispatch

  forward "/f/query", to: PlugProxy, url: "http://localhost:4000?a=1"
  forward "/f/path", to: PlugProxy, url: "http://localhost:4000/a/"
  forward "/", to: PlugProxy, url: "http://localhost:4000"

  defp before_send(conn, _) do
    register_before_send(conn, fn conn ->
      put_resp_header(conn, "x-before-send", "before send")
    end)
  end
end
