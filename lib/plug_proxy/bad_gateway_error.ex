defmodule PlugProxy.BadGatewayError do
  defexception reason: nil, plug_status: 502

  def message(exception) do
    "bad gateway: #{exception.reason}"
  end
end
