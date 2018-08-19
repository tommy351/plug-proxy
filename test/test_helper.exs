for mod <- [PlugProxyTest.Server, PlugProxyTest.Proxy] do
  conf = Application.get_env(:plug_proxy, mod, [])

  adapter =
    case System.get_env("COWBOY_VERSION") do
      "1" <> _ -> Plug.Adapters.Cowboy
      _ -> Plug.Adapters.Cowboy2
    end

  {:ok, _} = adapter.http(mod, [], conf)
end

ExUnit.start()
