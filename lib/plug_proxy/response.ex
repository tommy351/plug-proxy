defmodule PlugProxy.Response do
  import Plug.Conn
  alias PlugProxy.{BadGatewayError, GatewayTimeoutError}

  @type headers :: [{String.t(), String.t()}]

  @doc """
  Extract information from response headers.
  """
  @spec process_headers(headers) :: {headers, integer | :chunked}
  def process_headers(headers) do
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

  @doc """
  Run all before_send callbacks and set the connection state.
  """
  @spec before_send(Plug.Conn.t(), term) :: Plug.Conn.t()
  def before_send(%Plug.Conn{before_send: before_send} = conn, state) do
    conn = Enum.reduce(before_send, conn, & &1.(&2))
    %{conn | state: state}
  end

  @doc """
  Reads data from the client and sends the chunked response.
  """
  @spec chunked_reply(Plug.Conn.t(), :hackney.client_ref()) :: Plug.Conn.t()
  def chunked_reply(conn, client) do
    send_chunked(conn, conn.status)
    |> do_chunked_reply(client)
  end

  defp do_chunked_reply(conn, client) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        {:ok, conn} = chunk(conn, data)
        do_chunked_reply(conn, client)

      :done ->
        conn

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end

  @doc """
  Reads data from the client and sends the response.
  """
  @spec reply(Plug.Conn.t(), :hackney.client_ref()) :: Plug.Conn.t()
  def reply(conn, client) do
    case :hackney.body(client) do
      {:ok, body} ->
        send_resp(conn, conn.status, body)

      {:error, :timeout} ->
        raise GatewayTimeoutError, reason: :read

      {:error, err} ->
        raise BadGatewayError, reason: err
    end
  end
end
