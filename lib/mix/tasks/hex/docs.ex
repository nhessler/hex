defmodule Mix.Tasks.Hex.Docs do
  use Mix.Task
  alias Mix.Hex.Utils

  @shortdoc "Publishes docs for package"

  @moduledoc """
  Publishes documentation for the current project and version.

  The documentation will be accessible at `http://hexdocs.pm/my_package/1.0.0`,
  `http://hexdocs.pm/my_package` will always redirect to the latest published
  version.

  Documentation will be generated by running the `mix docs` task. `ex_doc`
  provides this task by default, but any library can be used. Or an alias can be
  used to extend the documentation generation. The expected result of the task
  is the generated documentation located in the `docs/` directory with an
  `index.html` file.

  ## Command line options

    * `--revert VERSION` - Revert given version
  """

  @switches [revert: :string, progress: :boolean]

  def run(args) do
    Hex.start

    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    auth = Utils.auth_info()

    Mix.Project.get!
    config  = Mix.Project.config
    app     = config[:app]
    version = config[:version]

    if revert = opts[:revert] do
      revert(app, revert, auth)
    else
      try do
        Mix.Task.run("docs", args)
      rescue e in Mix.NoTaskError ->
        stacktrace = System.stacktrace
        Mix.raise ~s(The "docs" task is unavailable, add {:ex_doc, ">= x.y.z", only: [:dev]} ) <>
                  ~s(to your dependencies or if ex_doc was already added make sure you run ) <>
                  ~s(the task in the same environment it is configured to)
        reraise e, stacktrace
      end

      directory = docs_dir()

      unless File.exists?("#{directory}/index.html") do
        Mix.raise "File not found: #{directory}/index.html"
      end

      progress? = Keyword.get(opts, :progress, true)
      tarball = build_tarball(app, version, directory)
      send_tarball(app, version, tarball, auth, progress?)
    end
  end

  defp build_tarball(app, version, directory) do
    tarball = "#{app}-#{version}-docs.tar.gz"
    files = files(directory)
    :ok = :erl_tar.create(tarball, files, [:compressed])
    data = File.read!(tarball)

    File.rm!(tarball)
    data
  end

  defp send_tarball(app, version, tarball, auth, progress?) do
    progress =
      if progress? do
        Utils.progress(byte_size(tarball))
      else
        Utils.progress(nil)
      end

    case Hex.API.ReleaseDocs.new(app, version, tarball, auth, progress) do
      {code, _} when code in 200..299 ->
        Hex.Shell.info ""
        Hex.Shell.info "Published docs for #{app} v#{version}"
        # TODO: Only print this URL if we use the default API URL
        Hex.Shell.info "Hosted at #{Hex.Utils.hexdocs_url(app, version)}"
      {code, body} ->
        Hex.Shell.info ""
        Hex.Shell.error "Pushing docs for #{app} v#{version} failed"
        Hex.Utils.print_error_result(code, body)
    end
  end

  defp revert(app, version, auth) do
    version = Utils.clean_version(version)

    case Hex.API.ReleaseDocs.delete(app, version, auth) do
      {code, _} when code in 200..299 ->
        Hex.Shell.info "Reverted docs for #{app} v#{version}"
      {code, body} ->
        Hex.Shell.error "Reverting docs for #{app} v#{version} failed"
        Hex.Utils.print_error_result(code, body)
    end
  end

  defp files(directory) do
    "#{directory}/**"
    |> Path.wildcard
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&{relative_path(&1, directory), File.read!(&1)})
  end

  defp relative_path(file, dir) do
    Path.relative_to(file, dir)
    |> String.to_char_list
  end

  defp docs_dir do
    cond do
      File.exists?("doc") ->
        "doc"
      File.exists?("docs") ->
        "docs"
      true ->
        Mix.raise("Documentation could not be found. Please ensure documentation is in the doc/ or docs/ directory")
    end
  end
end
