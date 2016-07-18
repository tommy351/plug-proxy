defmodule PlugProxy.BadGatewayError do
  @moduledoc false
  defexception reason: nil, plug_status: 502

  def message(exception) do
    "bad gateway: #{exception.reason}"
  end
end

defmodule PlugProxy.GatewayTimeoutError do
  @moduledoc false
  defexception reason: nil, plug_status: 504

  def message(exception) do
    "gateway timeout: #{exception.reason}"
  end
end
