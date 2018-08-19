defmodule PlugProxy.Response do
  @type headers :: [{String.t(), String.t()}]

  @spec process_headers(headers) :: {headers, integer} | {headers, :chunked}
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

  @spec before_send(Plug.Conn.t(), headers, term) :: Plug.Conn.t()
  def before_send(%Plug.Conn{before_send: before_send} = conn, headers, state) do
    conn = %{conn | resp_headers: headers}
    conn = Enum.reduce(before_send, conn, & &1.(&2))
    %{conn | state: state}
  end
end
