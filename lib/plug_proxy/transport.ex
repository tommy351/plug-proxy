defmodule PlugProxy.Transport do
  @moduledoc """
  The transport specification.

  A transport module must export the following functions:

  - a `c:write/3` function writes the request to the upstream.
  - a `c:read/3` function reads the response from the upstream and send it to the client.

  ## Examples

      defmodule TestTransport do
        use PlugProxy.Transport
        import Plug.Conn, only: [read_body: 2]

        def write(conn, client, _opts) do
          case read_body(conn, []) do
            {:ok, body, conn} ->
              :hackney.send_body(client, body)
              :hackney.finish_send_body(client)
              conn

            {:more, body, conn} ->
              :hackney.send_body(client, body)
              write(conn, client, opts)
          end
        end

        def read(conn, client, _opts) do
          {:ok, status, headers, client} = :hackney.start_response(client)
          {:ok, body} = :hackney.body(client)

          %{conn | resp_headers: headers}
          |> send_resp(status, body)
        end
      end
  """

  @type conn :: Plug.Conn.t()
  @type client :: :hackney.client_ref()
  @type opts :: term

  @callback write(conn, client, opts) :: conn
  @callback read(conn, client, opts) :: conn

  defmacro __using__(_) do
    quote do
      @behaviour PlugProxy.Transport

      @impl true
      def write(conn, client, opts) do
        case Plug.Conn.read_body(conn, []) do
          {:ok, body, conn} ->
            :hackney.send_body(client, body)
            :hackney.finish_send_body(client)
            conn

          {:more, body, conn} ->
            :hackney.send_body(client, body)
            write(conn, client, opts)

          {:error, :timeout} ->
            raise PlugProxy.GatewayTimeoutError, reason: :write

          {:error, err} ->
            raise PlugProxy.BadGatewayError, reason: err
        end
      end

      @impl true
      def read(conn, client, _) do
        case :hackney.start_response(client) do
          {:ok, status, headers, client} ->
            {headers, length} = PlugProxy.Response.process_headers(headers)

            %{conn | status: status, resp_headers: headers}
            |> reply(client, length)

          {:error, :timeout} ->
            raise PlugProxy.GatewayTimeoutError, reason: :read

          err ->
            raise PlugProxy.BadGatewayError, reason: err
        end
      end

      defp reply(conn, client, :chunked) do
        Plug.Conn.send_chunked(conn, conn.status)
        |> chunked_reply(client)
      end

      defp reply(conn, client, _length) do
        case :hackney.body(client) do
          {:ok, body} ->
            Plug.Conn.send_resp(conn, conn.status, body)

          {:error, :timeout} ->
            raise PlugProxy.GatewayTimeoutError, reason: :read

          {:error, err} ->
            raise PlugProxy.BadGatewayError, reason: err
        end
      end

      defp chunked_reply(conn, client) do
        case :hackney.stream_body(client) do
          {:ok, data} ->
            {:ok, conn} = Plug.Conn.chunk(conn, data)
            chunked_reply(conn, client)

          :done ->
            conn

          {:error, err} ->
            raise PlugProxy.BadGatewayError, reason: err
        end
      end

      defoverridable PlugProxy.Transport
    end
  end
end
