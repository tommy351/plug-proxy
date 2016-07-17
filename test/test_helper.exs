for mod <- [PlugProxyTest.Server, PlugProxyTest.Proxy] do
  conf = Application.get_env(:plug_proxy, mod, [])
  {:ok, _} = Plug.Adapters.Cowboy.http(mod, [], conf)
end

ExUnit.start()
