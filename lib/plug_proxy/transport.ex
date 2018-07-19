defmodule PlugProxy.Transport do
  @moduledoc """
  The transport specification.

  A transport module must export the following functions:

  - a `write/3` function writes the request to the upstream.
  - a `read/3` function reads the response from the upstream and send it to the client.

  ## Examples

      defmodule TestTransport do
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

  @callback write(conn, client, term) :: conn
  @callback read(conn, client, term) :: conn
end
