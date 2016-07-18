defmodule PlugProxyTest.Catch do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    try do
      opts = PlugProxy.init(opts)
      PlugProxy.call(conn, opts)
    catch
      :error, %{plug_status: status, reason: reason} ->
        send_resp(conn, status, to_string(reason))
    end
  end
end
