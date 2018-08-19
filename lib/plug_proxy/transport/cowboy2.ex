defmodule PlugProxy.Transport.Cowboy2 do
  @moduledoc """
  A transport module using Cowboy 2.
  """

  @behaviour PlugProxy.Transport

  import Plug.Conn, only: [send_resp: 3, send_chunked: 2, chunk: 2]
  import PlugProxy.Response
  alias PlugProxy.{BadGatewayError, GatewayTimeoutError}

  @impl true
  defdelegate write(conn, client, opts), to: PlugProxy.Transport.Cowboy

  @impl true
  def read(conn, client, _) do
    case :hackney.start_response(client) do
      {:ok, status, headers, client} ->
        {headers, length} = process_headers(headers)

        %{conn | status: status, resp_headers: headers}
        |> reply(client, length)

      {:error, :timeout} ->
        raise GatewayTimeoutError, reason: :read

      err ->
        raise BadGatewayError, reason: err
    end
  end

  defp reply(conn, client, :chunked) do
    send_chunked(conn, conn.status)
    |> chunked_reply(client)
  end

  defp reply(conn, client, _length) do
    case :hackney.body(client) do
      {:ok, body} ->
        send_resp(conn, conn.status, body)

      {:error, :timeout} ->
        raise GatewayTimeoutError, reason: :read

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end

  defp chunked_reply(conn, client) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        {:ok, conn} = chunk(conn, data)
        chunked_reply(conn, client)

      :done ->
        conn

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end
end
