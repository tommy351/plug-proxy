use Mix.Config

config :plug_proxy, PlugProxyTest.Server,
  ip: {127, 0, 0, 1},
  port: 4000

config :plug_proxy, PlugProxyTest.Proxy,
  ip: {127, 0, 0, 1},
  port: 4001
