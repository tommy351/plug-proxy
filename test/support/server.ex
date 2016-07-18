defmodule PlugProxyTest.Server do
  import Plug.Conn
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "ok")
  end

  post "/submit" do
    case read_body(conn) do
      {:ok, data, conn} -> send_resp(conn, 200, data)
    end
  end

  get "/query" do
    send_resp(conn, 200, conn.query_string)
  end

  get "/header" do
    conn
    |> put_resp_header("x-response-header", "response ok")
    |> send_resp(200, get_req_header(conn, "x-request-header"))
  end

  get "/chunk" do
    conn = send_chunked(conn, 200)

    Enum.reduce(["1", "2", "3"], conn, fn x, conn ->
      {:ok, conn} = chunk(conn, x)
      conn
    end)
  end

  get "/nothing" do
    send_resp(conn, 404, "not found")
  end

  get "/f/query" do
    send_resp(conn, 200, conn.query_string)
  end

  get "/a/*_path" do
    send_resp(conn, 200, conn.request_path)
  end

  get "/e/timeout/read" do
    :timer.sleep(600)
    send_resp(conn, 200, "ok")
  end
end
