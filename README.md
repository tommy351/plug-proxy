# PlugProxy

[![Build Status](https://travis-ci.org/tommy351/plug-proxy.svg?branch=master)](https://travis-ci.org/tommy351/plug-proxy) [![Hex pm](https://img.shields.io/hexpm/v/plug_proxy.svg?style=flat)](https://hex.pm/packages/plug_proxy) [![Coverage Status](https://coveralls.io/repos/tommy351/plug-proxy/badge.svg?branch=master)](https://coveralls.io/r/tommy351/plug-proxy?branch=master) [![Inline docs](https://inch-ci.org/github/tommy351/plug-proxy.svg)](http://inch-ci.org/github/tommy351/plug-proxy)

A plug for reverse proxy server.

## Installation

Add plug_proxy to `mix.exs` dependencies.

  1. Add `plug_proxy` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:plug_proxy, "~> 0.1.0"}]
    end
    ```

  2. Ensure `plug_proxy` is started before your application:

    ```elixir
    def application do
      [applications: [:plug_proxy]]
    end
    ```

## Usage

TODO
