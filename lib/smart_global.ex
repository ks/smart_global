defmodule SmartGlobal.Guard do
  defguard is_simple(x) when is_atom(x) or is_number(x) or is_binary(x) or is_bitstring(x)
  defguard is_var(x) when is_tuple(x) and :erlang.size(x) == 2 and elem(x, 0) == :var and is_atom(elem(x, 1))

end

defmodule SmartGlobal.Error do
  defexception [:message]

  @impl true
  def exception(value) do
    msg = "can't encode complex argument #{inspect(value)}"
    %__MODULE__{message: msg}
  end
end

defmodule SmartGlobal do

  @moduledoc """

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
  """

  import :erl_parse, only: [abstract: 1]

  import __MODULE__.Guard
  alias __MODULE__.Error


  def new(mod_name, mod_mapping) do
    with {:ok, ^mod_name, mod_binary} <- module(mod_name, mod_mapping) do
      :code.purge(mod_name)
      :code.load_binary(mod_name, '#{mod_name}.erl', mod_binary)
      {:ok, mod_name}
    end
  end

  def module(mod_name, mod_mapping),
    do: forms(mod_name, mod_mapping) |> :compile.forms([:verbose, :report_errors])

  def forms(mod_name, mod_mapping) when not is_nil(mod_name) and is_atom(mod_name) do
    fun_groups =
      mod_mapping
      |> Enum.map(fn {fun, mapping} when is_atom(fun) -> {fun, groups(mapping)} end)
      |> Enum.into(%{})

    [{:attribute, 0, :module, mod_name},
     {:attribute, 0, :export,
      Enum.flat_map(fun_groups,
        fn {fun, groups} ->
          for arity <- Map.keys(groups), do: {fun, arity}
        end)} |
     Enum.flat_map(fun_groups,
       fn {fun, groups} ->
         Enum.map(groups,
           fn {arity, argsval} ->
             {:function, 0, fun, arity,
              Enum.map(argsval,
                fn {args, val} ->
                  {:clause, 0, Enum.map(args, &abstract_arg/1), [], [ret_expr(val)]}
                end)}
           end)
       end)]
  end


  def abstract_arg(:_), do: {:var, 0, :_}
  def abstract_arg({:var, n}) when is_atom(n), do: {:var, 0, arg_name(n)}
  def abstract_arg(x), do: abstract(x)

  def arg_name(x) when is_atom(x), do: :"_#{x}@1"

  def ret_expr({:"$call", mod, name, args}) when is_atom(name) and is_list(args),
    do: {:call, 0, {:remote, 0, {:atom, 0, mod}, {:atom, 7, name}},
         Enum.map(args, &abstract_arg/1)}
  def ret_expr(val),
    do: abstract(val)


  defp groups(argsvals) when is_list(argsvals),
    do: Enum.group_by(argsvals,
          fn {args, _} ->
            Enum.each(args, &(is_simple(&1) || is_var(&1) || raise Error, value: &1))
            Enum.count(args)
          end)
  defp groups(argvals) when is_map(argvals) do
    group1 =
      argvals
      |> Map.drop([:_])
      |> Enum.reduce([],
           fn {arg, val}, acc ->
             &(is_simple(&1) || is_var(&1) || raise Error, value: &1)
             [{[arg], val} | acc]
           end)
    %{1 => Enum.reverse(case Map.get(argvals, :_, nil) do
                          nil -> group1
                          val -> [{[:_], val} | group1]
                        end)}
  end

end
