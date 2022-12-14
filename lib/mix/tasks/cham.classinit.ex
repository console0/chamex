defmodule Mix.Tasks.Cham.Classinit do
  @moduledoc "generates a class"
  use Mix.Task

  def run(args) do
    case class = List.first(args) do
      nil -> print_usage()
      _ -> generate_class(class)
    end
  end

  def print_usage() do
    IO.puts("""
    Seems like you need to know how this thing works.
    """)
  end

  def generate_class(raw_class_name) do
    otp_app = Mix.Cham.otp_app()
    class_name = Mix.Cham.to_lower_char(raw_class_name)

    # gen folder web/controllers/class
    class_path = Mix.Cham.web_path(otp_app, Path.join(["controllers", class_name]))
    layout_path = Mix.Cham.web_path(otp_app, Path.join(["templates", "layout"]))
    template_path = Mix.Cham.web_path(otp_app, Path.join(["templates", class_name]))

    with :ok <- File.mkdir_p(class_path),
         :ok <- File.mkdir_p(layout_path),
         :ok <- File.mkdir_p(template_path) do
      # write contents
      write_readme(class_name, class_path)
      write_router(class_name, class_path)
      write_root_template(class_name, layout_path)
      write_index(class_name)
      write_view(class_name)
    end
  end

  def write_view(class_name) do
    otp_app = Mix.Cham.otp_app()
    web_name = Mix.Cham.web_name(otp_app)
    view_path = Mix.Cham.web_path(otp_app, "views/" <> class_name <> "_view.ex")
    capital_class = Mix.Cham.camelize(class_name)

    File.write(
      view_path,
      """
      defmodule #{web_name}.#{capital_class}View do
        use #{web_name}, :view
      end
      """,
      [:write]
    )
  end

  def write_readme(class_name, class_path) do
    readme_path = Path.join(class_path, "README.md")
    this_app = Mix.Cham.otp_app()
    app_name = to_string(this_app) <> "_web"

    File.write(
      readme_path,
      """
      ### Class: `#{class_name}`

      All #{class_name} requests come to this class.

      Routes are defined in `router.ex`, which is a fairly vanilla phoenix router.
      We use forwarding in the main router so developers can use routes like
      `/something` locally that actually map to `/#{class_name}/something`.

      Pages should be added by calling `mix cham.pageinit --class #{class_name} pagename`

      Templates for the pages in this class are located in:

      `lib/#{app_name}/templates/#{class_name}`

      The outer shell layout is defined in:

      `lib/#{app_name}/templates/layout/#{class_name}.html.heex`
      """,
      [:write]
    )
  end

  def write_router(class_name, class_path) do
    router_path = Path.join(class_path, "router.ex")
    web_name = Mix.Cham.web_name(Mix.Cham.otp_app())
    code_name = Mix.Cham.camelize(class_name)

    File.write(
      router_path,
      """
      defmodule #{web_name}.#{code_name}Router do
        use #{web_name}, :router

        # #{class_name} plug pipeline
        pipeline :#{class_name} do
          plug #{web_name}.Plugs.RequireClass, [ "#{class_name}" ]
        end

        # #{class_name} routes
        scope "/", #{web_name} do
          # only users with the #{class_name} class should see these pages
          pipe_through :#{class_name}

          get "/", #{code_name}IndexController, :index
        end
      end
      """,
      [:write]
    )
  end

  def write_index(class_name) do
    # should delegate to a "page" init for the class
    Mix.Tasks.Cham.Pageinit.create_page(class_name, "index")
  end

  def write_root_template(class_name, template_path) do
    shell_path = Path.join(template_path, class_name <> ".html.heex")

    File.write(
      shell_path,
      """
      <main class="container">
        <p class="alert alert-info" role="alert"><%= get_flash(@conn, :info) %></p>
        <p class="alert alert-danger" role="alert"><%= get_flash(@conn, :error) %></p>
        #{class_name} navigation/shell<br/><hr/>
        <%= @inner_content %>
      </main>
      """,
      [:write]
    )
  end
end
