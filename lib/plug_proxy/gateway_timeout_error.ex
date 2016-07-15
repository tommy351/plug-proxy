defmodule PlugProxy.GatewayTimeoutError do
  defexception plug_status: 504

  def message(_exception) do
    "gateway timeout"
  end
end
