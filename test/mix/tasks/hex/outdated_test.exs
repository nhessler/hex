defmodule Mix.Tasks.Hex.OutdatedTest do
  use HexTest.Case
  @moduletag :integration

  defmodule OutdatedDeps.Mixfile do
    def project do
      [app: :outdated_app,
       version: "0.0.2",
       deps: [{:bar, "0.1.0"},
              {:ex_doc, "~> 0.0.1"}]]
    end
  end

  defmodule OutdatedBetaDeps.Mixfile do
    def project do
      [app: :outdated_app,
       version: "0.0.1",
       deps: [{:beta, ">= 0.0.0"}]]
    end
  end

  defmodule OutdatedApp.Mixfile do
    def project do
      [app: :outdated_app,
       version: "0.0.1",
       deps: [{:ex_doc, ">= 0.0.0"},
              {:postgrex, "0.2.0"},
              {:ecto, "0.2.0"}]]
    end
  end

  defmodule NotOutdatedApp.Mixfile do
    def project do
      [app: :outdated_app,
       version: "0.0.1",
       deps: [{:ex_doc, ">= 0.0.0"}]]
    end
  end

  test "outdated" do
    Mix.Project.push OutdatedDeps.Mixfile

    in_tmp fn ->
      Hex.State.put(:home, tmp_path())
      Mix.Dep.Lock.write %{bar: {:hex, :bar, "0.1.0"}, foo: {:hex, :foo, "0.1.0"}}

      Mix.Task.run "deps.get"
      flush

      Mix.Task.run "hex.outdated"

      bar = [:bright, "bar", :reset, "         ", "0.1.0", "    ", :green, "0.1.0", :reset, "   ", :green, "0.1.0"]
            |> IO.ANSI.format
            |> List.to_string

      assert_received {:mix_shell, :info, [^bar]}
      refute_received {:mix_shell, :info, ["\e[1mfoo" <> _]}
    end
  end

  test "outdated --all" do
    Mix.Project.push OutdatedDeps.Mixfile

    in_tmp fn ->
      Hex.State.put(:home, tmp_path())
      Mix.Dep.Lock.write %{bar: {:hex, :bar, "0.1.0"}, foo: {:hex, :foo, "0.1.0"}}

      Mix.Task.run "deps.get"
      flush

      Mix.Task.run "hex.outdated", ["--all"]

      bar = [:bright, "bar", :reset, "         ", "0.1.0", "    ", :green, "0.1.0", :reset, "   ", :green, "0.1.0"]
            |> IO.ANSI.format
            |> List.to_string

      foo = [:bright, "foo", :reset, "         ", "0.1.0", "    ", :red, "0.1.1", :reset, "   ", :green, "~> 0.1.0"]
            |> IO.ANSI.format
            |> List.to_string

      ex_doc = [:bright, "ex_doc", :reset, "      ", "0.0.1", "    ", :red, "0.1.0", :reset, "   ", :red, "~> 0.0.1"]
               |> IO.ANSI.format
               |> List.to_string

      assert_received {:mix_shell, :info, [^bar]}
      assert_received {:mix_shell, :info, [^foo]}
      assert_received {:mix_shell, :info, [^ex_doc]}
    end
  end

  test "outdated --pre" do
    Mix.Project.push OutdatedBetaDeps.Mixfile

    in_tmp fn ->
      Hex.State.put(:home, tmp_path())
      Mix.Dep.Lock.write %{beta: {:hex, :beta, "1.0.0"}}

      Mix.Task.run "deps.get"
      flush

      Mix.Task.run "hex.outdated", []

      beta = [:bright, "beta", :reset, "        ", "1.0.0", "    ", :green, "1.0.0", :reset, "   ", :green, ">= 0.0.0"]
             |> IO.ANSI.format
             |> List.to_string
      assert_received {:mix_shell, :info, [^beta]}

      Mix.Task.reenable "hex.outdated"
      Mix.Task.run "hex.outdated", ["--pre"]

      beta = [:bright, "beta", :reset, "        ", "1.0.0", "    ", :red, "1.1.0-beta", :reset, "  ", :red, ">= 0.0.0"]
             |> IO.ANSI.format
             |> List.to_string
      assert_received {:mix_shell, :info, [^beta]}
    end
  end

  test "outdated app" do
    Mix.Project.push OutdatedApp.Mixfile

    in_tmp fn ->
      Hex.State.put(:home, tmp_path())
      Mix.Dep.Lock.write %{ex_doc: {:hex, :ex_doc, "0.0.1"}}

      Mix.Task.run "deps.get"
      flush

      Mix.Task.run "hex.outdated", ["ex_doc"]
      msg = ["There is newer version of the dependency available ", :bright, "0.1.0 > 0.0.1", :reset, "!"]
            |> IO.ANSI.format
            |> List.to_string
      assert_received {:mix_shell, :info, [^msg]}

      mix = [:bright, "mix.exs", :reset, "   ", :green, ">= 0.0.0"]
            |> IO.ANSI.format
            |> List.to_string
      assert_received {:mix_shell, :info, [^mix]}

      ecto = [:bright, "ecto", :reset, "      ", :red, "~> 0.0.1"]
             |> IO.ANSI.format
             |> List.to_string
      assert_received {:mix_shell, :info, [^ecto]}

      postgrex = [:bright, "postgrex", :reset, "  ", :red, "0.0.1"]
                 |> IO.ANSI.format
                 |> List.to_string
      assert_received {:mix_shell, :info, [^postgrex]}
    end
  end

  test "not outdated app" do
    Mix.Project.push NotOutdatedApp.Mixfile

    in_tmp fn ->
      Hex.State.put(:home, tmp_path())
      Mix.Dep.Lock.write %{ex_doc: {:hex, :ex_doc, "0.1.0"}}

      Mix.Task.run "deps.get"
      flush

      Mix.Task.run "hex.outdated", ["ex_doc"]
      msg = ["Current version ", :bright, "0.1.0", :reset, " of dependency is up to date!"]
            |> IO.ANSI.format
            |> List.to_string
      assert_received {:mix_shell, :info, [^msg]}
    end
  end
end
