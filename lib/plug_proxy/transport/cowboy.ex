defmodule PlugProxy.Transport.Cowboy do
  @moduledoc """
  A transport module using Cowboy.
  """

  use PlugProxy.Transport
  import PlugProxy.Response, only: [process_headers: 1, chunked_reply: 2, before_send: 2]
  alias PlugProxy.{BadGatewayError, GatewayTimeoutError}

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
    chunked_reply(conn, client)
  end

  defp reply(conn, client, length) do
    body_fun = fn socket, transport ->
      stream_reply(conn, client, socket, transport)
    end

    conn = before_send(conn, :set)
    {adapter, req} = conn.adapter

    {:ok, req} =
      :cowboy_req.reply(
        conn.status,
        conn.resp_headers,
        :cowboy_req.set_resp_body_fun(length, body_fun, req)
      )

    %{conn | adapter: {adapter, req}, state: :sent}
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
end
