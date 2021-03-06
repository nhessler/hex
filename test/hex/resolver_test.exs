defmodule Hex.ResolverTest do
  use HexTest.Case

  defp resolve(reqs, locked \\ []) do
    reqs      = Enum.reverse(reqs)
    deps      = deps(reqs)
    top_level = Enum.map(deps, &elem(&1, 0))
    reqs      = reqs(reqs)
    locked    = locked(locked)

    case Hex.Resolver.resolve(reqs, deps, top_level, locked) do
      {:ok, dict} -> dict
      {:error, messages} -> messages
    end
  end

  defp deps(reqs) do
    Enum.map(reqs, fn {app, _req} ->
      {Atom.to_string(app), false, []}
    end)
  end

  defp reqs(reqs) do
    Enum.map(reqs, fn {app, req} ->
      name = Atom.to_string(app)
      {name, name, req, "mix.exs"}
    end)
  end

  defp locked(locked) do
    Enum.map(locked, fn {app, req} ->
      name = Atom.to_string(app)
      {name, name, req}
    end)
  end

  setup do
    Hex.Registry.open!(Hex.Registry.ETS, registry_path: tmp_path("registry.ets"))
  end

  test "simple" do
    deps = [foo: nil, bar: nil]
    assert Dict.equal? locked([foo: "0.2.1", bar: "0.2.0"]), resolve(deps)

    deps = [foo: "0.2.1", bar: "0.2.0"]
    assert Dict.equal? locked([foo: "0.2.1", bar: "0.2.0"]), resolve(deps)

    deps = [foo: "0.2.0", bar: "0.2.0"]
    assert Dict.equal? locked([foo: "0.2.0", bar: "0.2.0"]), resolve(deps)

    deps = [bar: nil, foo: "~> 0.3.0"]
    assert resolve(deps) == """
    \e[4mFailed to use "foo" because\e[0m
      You specified \e[32m~> 0.3.0\e[0m in your mix.exs\e[0m
    """

    deps = [foo: "~> 0.3.0", bar: nil]
    assert resolve(deps) == """
    \e[4mFailed to use "foo" because\e[0m
      You specified \e[32m~> 0.3.0\e[0m in your mix.exs\e[0m
    """

    deps = [bar: "~> 0.3.0", foo: nil]
    assert resolve(deps) == """
    \e[4mFailed to use "bar" because\e[0m
      You specified \e[32m~> 0.3.0\e[0m in your mix.exs\e[0m
    """

    deps = [foo: nil, bar: "~> 0.3.0"]
    assert resolve(deps) == """
    \e[4mFailed to use "bar" because\e[0m
      You specified \e[32m~> 0.3.0\e[0m in your mix.exs\e[0m
    """
  end

  test "backtrack" do
    deps = [decimal: "0.2.0", ex_plex: "0.2.0"]
    assert Dict.equal? locked([decimal: "0.2.0", ex_plex: "0.2.0"]), resolve(deps)

    deps = [decimal: "0.1.0", ex_plex: ">= 0.1.0"]
    assert Dict.equal? locked([decimal: "0.1.0", ex_plex: "0.1.2"]), resolve(deps)

    deps = [decimal: nil, ex_plex: "< 0.1.0"]
    assert Dict.equal? locked([decimal: "0.2.1", ex_plex: "0.0.1"]), resolve(deps)

    deps = [decimal: "0.1.0", ex_plex: "< 0.1.0"]
    assert Dict.equal? locked([decimal: "0.1.0", ex_plex: "0.0.1"]), resolve(deps)

    deps = [ex_plex: "~> 0.0.2", decimal: "0.1.0", ]
    assert resolve(deps) == """
    \e[4mFailed to use "decimal" (version 0.1.0) because\e[0m
      \e[1mex_plex (version 0.0.2)\e[0m requires \e[31m0.1.1\e[0m
      You specified \e[32m0.1.0\e[0m in your mix.exs\e[0m
    """

    deps = [decimal: "0.1.0", ex_plex: "~> 0.0.2"]
    assert resolve(deps) == """
    \e[4mFailed to use "decimal" because\e[0m
      \e[1mex_plex (version 0.0.2)\e[0m requires \e[32m0.1.1\e[0m\e[0m
    """

    deps = [ex_plex: "0.0.2", decimal: nil]
    assert resolve(deps) == """
    \e[4mFailed to use "decimal" (versions 0.0.1 to 0.2.1) because\e[0m
      \e[1mex_plex (version 0.0.2)\e[0m requires \e[31m0.1.1\e[0m
      You specified \e[32m>= 0.0.0\e[0m in your mix.exs\e[0m
    """

    deps = [decimal: nil, ex_plex: "0.0.2"]
    assert resolve(deps) == """
    \e[4mFailed to use "decimal" because\e[0m
      \e[1mex_plex (version 0.0.2)\e[0m requires \e[32m0.1.1\e[0m\e[0m
    """
  end

  test "complete backtrack" do
    deps = [jose: nil, eric: nil]
    assert Dict.equal? locked([jose: "0.2.1", eric: "0.0.2"]), resolve(deps)
  end

  test "backtrack with multiple parents" do
    deps = [phoenix: "~> 1.1.3", phoenix_ecto: "~> 2.0", phoenix_live_reload: "~> 1.0"]
    assert Dict.equal? locked([ecto: "1.1.0", phoenix: "1.1.3", phoenix_ecto: "2.0.1",
                               phoenix_live_reload: "1.0.3", poison: "1.5.2"]),  resolve(deps)

    deps = [phoenix: nil, phoenix_ecto: "~> 2.0", phoenix_live_reload: "~> 1.0"]
    assert Dict.equal? locked([ecto: "1.1.0", phoenix: "1.1.3", phoenix_ecto: "2.0.1",
                               phoenix_live_reload: "1.0.3", poison: "1.5.2"]), resolve(deps)
  end

  test "locked" do
    locked = [decimal: "0.2.0"]
    deps = [decimal: nil, ex_plex: nil]
    assert Dict.equal? locked([decimal: "0.2.0", ex_plex: "0.2.0"]), resolve(deps, locked)

    locked = [decimal: "0.1.0"]
    deps = [decimal: nil, ex_plex: nil]
    assert Dict.equal? locked([decimal: "0.1.0", ex_plex: "0.1.2"]), resolve(deps, locked)

    locked = [decimal: "0.0.1"]
    deps = [decimal: nil, ex_plex: nil]
    assert Dict.equal? locked([decimal: "0.0.1", ex_plex: "0.0.1"]), resolve(deps, locked)

    locked = [ex_plex: "0.1.0"]
    deps = [decimal: "0.1.0", ex_plex: nil]
    assert Dict.equal? locked([decimal: "0.1.0", ex_plex: "0.1.0"]), resolve(deps, locked)

    locked = [ex_plex: "0.1.0", decimal: "0.1.0"]
    deps = [decimal: "0.1.0", ex_plex: nil]
    assert Dict.equal? locked([decimal: "0.1.0", ex_plex: "0.1.0"]), resolve(deps, locked)

    locked = [ex_plex: "0.1.0", decimal: "0.1.0"]
    deps = [decimal: nil, ex_plex: nil]
    assert Dict.equal? locked([decimal: "0.1.0", ex_plex: "0.1.0"]), resolve(deps, locked)

    locked = [ex_plex: "0.1.0", decimal: "0.1.0"]
    deps = []
    assert Dict.equal? [], resolve(deps, locked)
  end

  test "failure due to locked dep" do
    locked = [decimal: "0.0.1"]
    deps = [ex_plex: "0.1.0", decimal: nil]
    assert resolve(deps, locked) == """
    \e[4mFailed to use "decimal" (version 0.0.1) because\e[0m
      \e[1mex_plex (version 0.1.0)\e[0m requires \e[31m~> 0.1.0\e[0m
      Locked to \e[32m0.0.1\e[0m in your mix.lock\e[0m
    """

    deps = [decimal: nil, ex_plex: "0.1.0"]
    assert resolve(deps, locked) == """
    \e[4mFailed to use "decimal" because\e[0m
      \e[1mex_plex (version 0.1.0)\e[0m requires \e[32m~> 0.1.0\e[0m
      Locked to \e[32m0.0.1\e[0m in your mix.lock\e[0m
    """

    locked = [decimal: "0.0.1"]
    deps = [ex_plex: "0.1.0", decimal: "~> 0.0.1"]
    assert resolve(deps, locked) == """
    \e[4mFailed to use "decimal" (version 0.0.1) because\e[0m
      \e[1mex_plex (version 0.1.0)\e[0m requires \e[31m~> 0.1.0\e[0m
      Locked to \e[32m0.0.1\e[0m in your mix.lock\e[0m
    """

    locked = [decimal: "0.0.1"]
    deps = [decimal: "~> 0.0.1", ex_plex: "0.1.0"]
    assert resolve(deps, locked) == """
    \e[4mFailed to use "decimal" because\e[0m
      \e[1mex_plex (version 0.1.0)\e[0m requires \e[32m~> 0.1.0\e[0m
      Locked to \e[32m0.0.1\e[0m in your mix.lock\e[0m
    """
  end

  test "optional" do
    deps = [ex_doc: nil, has_optional: nil]
    assert Dict.equal? locked([ex_doc: "0.0.2", has_optional: "0.1.0"]), resolve(deps)
  end
end
