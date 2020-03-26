# SmartGlobal

  SmartGlobal allows you to use a beam module as read-only store.
  Such module can be generated at the application startup and send to other nodes to load.
  Doesn't support updates, but the module can be regenerated with different bindings.
  Supports _ wildcard to return the default value.

  Example:
  ```
  SmartGlobal.new(

    XXX,

    %{fun1: [{[:a, :b, :c], :three_little_piggies},
             {[:xx, :yy], [1,2,3,5]},
             {[:cc, 123], <<1,2,3,4,5>>},
             {[:_], :default}],

      fun2: %{a: 100,
              b: 200,
              _: :yaya}}

    )
  ```
  will generate a module which when decompied to Elixir would look like:
  ```
  defmodule XXX do
    def fun1(:a, :b, :c), do: :three_little_piggies

    def fun1(:xx, :yy), do: [1,2,3,5]
    def fun1(:cc, 123), do: <<1,2,3,4,5>>

    def fun1(_), do: :default

    def fun2(:a), do: 100
    def fun2(:b), do: 200
    def fun2(_), do: :yaya
  end
  ```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `smart_global` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:smart_global, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/smart_global](https://hexdocs.pm/smart_global).
