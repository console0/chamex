defmodule Mix.Tasks.Cham.Pageinit do
  @moduledoc "generates a page"
  use Mix.Task

  @switches [
    class: :string
  ]

  def run(args) do
    {opts, args} = OptionParser.parse_head!(args, strict: @switches)

    class =
      Keyword.get(opts, :class)
      |> Mix.Cham.to_lower_char()

    page =
      List.first(args)
      |> Mix.Cham.to_lower_char()

    with true <- is_binary(class),
         true <- is_binary(page) do
      create_page(class, page)
    else
      _ -> print_usage()
    end
  end

  def create_page(class_name, page_name) do
    otp_app = Mix.Cham.otp_app()
    code_path = Mix.Cham.web_path(otp_app, "controllers/" <> class_name <> "/" <> page_name <> ".ex")

    template_path =
      Mix.Cham.web_path(otp_app, "templates/" <> class_name <> "/" <> page_name <> ".html.eex")

    write_template(template_path, page_name, class_name)
    write_code(code_path, page_name, class_name)
  end

  def write_code(template_path, page_name, class_name) do
    page_code_name = Mix.Cham.camelize(page_name)
    app_code_name = Mix.Cham.web_name(Mix.Cham.otp_app())
    class_code_name = Mix.Cham.camelize(class_name)

    File.write(
      template_path,
      """
      defmodule #{app_code_name}.#{class_code_name}#{page_code_name}Controller do
        use #{app_code_name}, :controller

        plug :put_layout, "#{class_name}.html"

        def #{page_name}(conn, _params) do
          # This is where you write the code to run the page

          render(conn, "#{page_name}.html")
        end
      end
      """,
      [:write]
    )
  end

  def write_template(template_path, page_name, class_name) do
    File.write(
      template_path,
      """
      <section class="row">
        This is the page for #{class_name}/#{page_name}
      </section>
      """,
      [:write]
    )
  end

  def print_usage() do
    IO.puts("""
    Seems like you need to know how this thing works.
    """)
  end
end
