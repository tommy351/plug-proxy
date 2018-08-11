defmodule PlugProxy.Transport.Cowboy do
  @moduledoc """
  A transport module using Cowboy.
  """

  @behaviour PlugProxy.Transport

  import Plug.Conn, only: [read_body: 2]
  alias PlugProxy.{BadGatewayError, GatewayTimeoutError}

  @impl true
  def write(conn, client, opts) do
    case read_body(conn, []) do
      {:ok, body, conn} ->
        :hackney.send_body(client, body)
        :hackney.finish_send_body(client)
        conn

      {:more, body, conn} ->
        :hackney.send_body(client, body)
        write(conn, client, opts)

      {:error, :timeout} ->
        raise GatewayTimeoutError, reason: :write

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end

  @impl true
  def read(conn, client, _) do
    case :hackney.start_response(client) do
      {:ok, status, headers, client} ->
        {headers, length} = process_headers(headers)

        %{conn | status: status}
        |> reply(client, headers, length)

      {:error, :timeout} ->
        raise GatewayTimeoutError, reason: :read

      err ->
        raise BadGatewayError, reason: err
    end
  end

  defp process_headers(headers) do
    process_headers(headers, [], 0)
  end

  defp process_headers([], acc, length) do
    {Enum.reverse(acc), length}
  end

  defp process_headers([{key, value} | tail], acc, length) do
    process_headers(String.downcase(key), value, tail, acc, length)
  end

  defp process_headers("content-length", value, headers, acc, length) do
    length =
      case Integer.parse(value) do
        {int, ""} -> int
        _ -> length
      end

    process_headers(headers, acc, length)
  end

  defp process_headers("transfer-encoding", "chunked", headers, acc, _) do
    process_headers(headers, acc, :chunked)
  end

  defp process_headers(key, value, headers, acc, length) do
    process_headers(headers, [{key, value} | acc], length)
  end

  defp reply(conn, client, headers, :chunked) do
    conn = before_send(conn, headers, :chunked)
    {adapter, req} = conn.adapter
    {:ok, req} = :cowboy_req.chunked_reply(conn.status, conn.resp_headers, req)
    chunked_reply(conn, client, req)
    %{conn | adapter: {adapter, req}}
  end

  defp reply(conn, client, headers, length) do
    body_fun = fn socket, transport ->
      stream_reply(conn, client, socket, transport)
    end

    conn = before_send(conn, headers, :set)
    {adapter, req} = conn.adapter

    {:ok, req} =
      :cowboy_req.reply(
        conn.status,
        conn.resp_headers,
        :cowboy_req.set_resp_body_fun(length, body_fun, req)
      )

    %{conn | adapter: {adapter, req}, state: :sent}
  end

  defp chunked_reply(conn, client, req) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        :cowboy_req.chunk(data, req)
        chunked_reply(conn, client, req)

      :done ->
        :ok

      {:error, _reason} ->
        # TODO: error handling
        :ok
    end
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

  defp before_send(%Plug.Conn{before_send: before_send} = conn, headers, state) do
    conn = %{conn | resp_headers: headers}
    conn = Enum.reduce(before_send, conn, & &1.(&2))
    %{conn | state: state}
  end
end
