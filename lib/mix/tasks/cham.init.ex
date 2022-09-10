defmodule Mix.Tasks.Cham.Init do
  @moduledoc "The hello mix task: `mix help hello`"
  use Mix.Task

  @shortdoc "Setup the folder structure and make an initial public/admin class."
  def run(_args) do
    otp_app = Mix.Cham.otp_app()
    app_name = to_string(otp_app) <> "_web"

    # create makefile and docker files
    write_makefile(otp_app)
    write_dockerfile(otp_app)
    write_docker_compose(otp_app)
    write_docker_script(otp_app)

    # router and default classes
    write_router(otp_app)

    # create an admin class
    Mix.Tasks.Cham.Classinit.generate_class("admin")

    # create public structure and initial page
    class_path = Mix.Cham.web_path(otp_app, Path.join(["controllers","public"]))
    layout_path = Mix.Cham.web_path(otp_app, Path.join(["templates", "layout"]))
    template_path = Mix.Cham.web_path(otp_app, Path.join(["templates","public"]))

    # remove some of the default files we wont need anymore
    with :ok <- File.stat("lib/" <> app_name <> "/controllers/page_controller.ex") do
      File.rm("lib/" <> app_name <> "/controllers/page_controller.ex")
    end

    with :ok <- File.mkdir_p(class_path),
         :ok <- File.mkdir_p(layout_path),
         :ok <- File.mkdir_p(template_path) do
      # write contents
      write_readme(class_path)
      write_class_plug(otp_app)
      Mix.Tasks.Cham.Classinit.write_root_template("public", template_path)
      Mix.Tasks.Cham.Classinit.write_index("public")
      Mix.Tasks.Cham.Classinit.write_view("public")
      write_public_readme(class_path)
      # TODO gen auth should be handled correctly, we don't want to do that ourselves
    end
  end

  def write_public_readme(class_path) do
    readme_path = Path.join(class_path, "README.md")
    this_app = Mix.Cham.otp_app()
    app_name = to_string(this_app) <> "_web"

    File.write(
      readme_path,
      """
      ### Class: `public`

      All non-authenticated browser requests come to this class.

      Routes are defined in `lib/router.ex`,

      Pages should be added by calling `mix cham.pageinit --class public pagename`

      Templates for the pages in this class are located in:

      `lib/#{app_name}/templates/public`

      The outer shell layout is defined in:

      `lib/#{app_name}/templates/layout/public.html.heex`
      """,
      [:write]
    )
  end

  def write_readme(class_path) do
    class_name = "public"
    readme_path = Path.join(class_path, "README.md")
    this_app = Mix.Cham.otp_app()
    app_name = to_string(this_app) <> "_web"

    File.write(
      readme_path,
      """
      ### Class: `#{class_name}`

      All non-authenticated requests come to this class.

      Routes are defined in `lib/#{app_name}/router.ex`

      Pages should be added by calling `mix cham.pageinit --class #{class_name} pagename`

      Templates for the pages in this class are located in:

      `lib/#{app_name}/templates/#{class_name}`

      The outer shell layout is defined in:

      `lib/#{app_name}/templates/layout/#{class_name}.html.heex`
      """,
      [:write]
    )
  end

  def write_class_plug(otp_app) do
    web_name = Mix.Cham.web_name(otp_app)
    plug_path = Mix.Cham.web_path(otp_app, Path.join(["plugs"]))
    plug_file = Mix.Cham.web_path(otp_app, Path.join(["plugs", "require_class.ex"]))

    with :ok <- File.mkdir_p(plug_path) do
      File.write(
        plug_file,
        """
        defmodule #{web_name}.Plugs.RequireClass do
          import Plug.Conn

          use #{web_name}, :controller

          def init(classes), do: classes

          # public (default/missing) class just sets the view
          def call(conn, _args=[]) do
            conn |> put_view(#{web_name}.PublicView)
          end

          def call(conn, classes, view) do
            session_class = get_session(conn, :class)

            case Enum.member?(classes, session_class) do
              true -> conn |> put_view(view)
              _ -> conn |> put_flash(:info, "You must be logged in") |> redirect(to: "/") |> halt()
            end
          end
        end
        """,
        [:write]
      )
    end
  end

  def write_router(otp_app) do
    router_path = Mix.Cham.web_path(otp_app, "router.ex")
    web_name = Mix.Cham.web_name(otp_app)

    File.write(
      router_path,
      """
      defmodule #{web_name}.Router do
        use #{web_name}, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_live_flash
          plug :put_root_layout, {#{web_name}.LayoutView, :root}
          plug :protect_from_forgery
          plug :put_secure_browser_headers
          plug #{web_name}.Plugs.RequireClass
        end

        pipeline :api do
          plug :accepts, ["json"]
        end

        scope "/", #{web_name} do
          pipe_through :browser

          # actual public routes, using the public controller
          get "/", PublicIndexController, :index

          # Admin class
          forward "/admin", AdminRouter

          # Once you generate a new class you can enable it here
          # forward "/employee", ParticipantRouter
        end

        # Other scopes may use custom stacks.
        # scope "/api", #{web_name} do
        #   pipe_through :api
        # end

        # Enables LiveDashboard only for development
        #
        # If you want to use the LiveDashboard in production, you should put
        # it behind authentication and allow only admins to access it.
        # If your application does not have an admins-only section yet,
        # you can use Plug.BasicAuth to set up some basic authentication
        # as long as you are also using SSL (which you should anyway).
        if Mix.env() in [:dev, :test] do
          import Phoenix.LiveDashboard.Router

          scope "/" do
            pipe_through :browser

            live_dashboard "/dashboard", metrics: #{web_name}.Telemetry
          end
        end

        # Enables the Swoosh mailbox preview in development.
        #
        # Note that preview only shows emails that were sent by the same
        # node running the Phoenix server.
        if Mix.env() == :dev do
          scope "/dev" do
            pipe_through :browser

            forward "/mailbox", Plug.Swoosh.MailboxPreview
          end
        end
      end
      """,
      [:write]
    )
  end

  def write_dockerfile(_otp_app) do
    app_dir = File.cwd!()
    dockerfile_path = Path.join([app_dir, "Dockerfile"])

    File.write(
      dockerfile_path,
      """
      # Elixir + Phoenix

      FROM elixir:1.14-alpine

      # Install packages
      RUN apk add --no-cache git openssl-dev build-base postgresql-client inotify-tools

      # Install Phoenix packages
      RUN mix local.hex --force
      RUN mix local.rebar --force

      WORKDIR /app
      EXPOSE 4000
      """,
      [:write]
    )
  end

  def write_docker_script(_otp_app) do
    app_dir = File.cwd!()
    docker_script_path = Path.join([app_dir, "run.sh"])

    File.write(
      docker_script_path,
      """
      #!/bin/sh
      # Adapted from Alex Kleissner's post, Running a Phoenix 1.3 project with docker-compose
      # https://medium.com/@hex337/running-a-phoenix-1-3-project-with-docker-compose-d82ab55e43cf

      set -e

      # Ensure the app's dependencies are installed
      mix deps.get

      # Prepare Dialyzer if the project has Dialyxer set up
      if mix help dialyzer >/dev/null 2>&1
      then
        echo "Found Dialyxer: Setting up PLT..."
        mix do deps.compile, dialyzer --plt
      else
        echo "No Dialyxer config: Skipping setup..."
      fi

      # Wait for Postgres to become available.
      until psql -h db -U "postgres" -c '\\q'; do
        >&2 echo "Postgres is unavailable - sleeping"
        sleep 1
      done

      echo "Postgres is available: continuing with database setup..."

      #Analysis style code
      # Prepare Credo if the project has Credo start code analyze
      if mix help credo >/dev/null 2>&1
      then
        echo "Found Credo: analyzing..."
        mix credo || true
      else
        echo "No Credo config: Skipping code analyze..."
      fi

      # Potentially Set up the database
      mix ecto.create
      mix ecto.migrate

      echo "Launching Phoenix web server..."
      # Start the phoenix web server
      mix phx.server

      """,
      [:write]
    )

    File.chmod!(docker_script_path, 0o755)
  end

  def write_docker_compose(_otp_app) do
    app_dir = File.cwd!()
    docker_compose_path = Path.join([app_dir, "docker-compose.yml"])

    File.write(
      docker_compose_path,
      """
      version: '3.2'
      services:
        db:
          image: postgres
          ports:
            - "5432:5432"
          environment:
            - POSTGRES_PASSWORD=postgres

        web:
          build: .
          volumes:
            - type: bind
              source: .
              target: /app
          ports:
            - "4000:4000"
          environment:
            # Modify your config files (dev.exs and test.exs) so that the password and hostname can be overridden
            # when environment variables are set:
            # password: System.get_env("DB_PASS", "postgres"),
            # hostname: System.get_env("DB_HOST", "localhost"),
            - PGPASSWORD=postgres
            - DB_PASS=postgres
            - DB_HOST=db
          depends_on:
            - db
          command:
            - ./run.sh
      """,
      [:write]
    )
  end

  def write_makefile(otp_app) do
    app_name = to_string(otp_app)
    app_dir = File.cwd!()
    makefile_path = Path.join([app_dir, "Makefile"])

    File.write(
      makefile_path,
      """
      #!/usr/bin/env make

      appname := #{app_name}
      dbname := #{app_name}

      help: ## Shows this help.
      \t@IFS=$$'\\n' ; \\
      \thelp_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//'`); \\
      \tfor help_line in $${help_lines[@]}; do \\
      \t\tIFS=$$'#' ; \\
      \t\thelp_split=($$help_line) ; \\
      \t\thelp_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \\
      \t\thelp_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \\
      \t\tprintf "%-30s %s\\n" $$help_command $$help_info ; \\
      \tdone

      build: ## (Re)build the containers
      \tdocker-compose build

      remove-containers: ## Pull a DB backup and remove the containers
      \tdocker-compose up -d
      \tpg_dump $(dbname) -h localhost -U postgres -w -O -f $(dbname).backupsql
      \tdocker-compose rm -s -v

      start-db: ## Start the postgres node
      \tdocker-compose up -d db

      stop-db: ## Stop the postgres node
      \tdocker-compose stop db

      db-migrate: ## Run migrations
      \tdocker-compose up -d db
      \tdocker-compose run --rm web mix do ecto.create ecto.migrate

      db-backup: ## Dump the db
      \tdocker-compose up -d db
      \tpg_dump $(dbname) -h localhost -U postgres -w -O -f $(dbname).sql

      db-restore: ## Restore the db
      \tdocker-compose up -d db
      \tcreatedb -T template0 -h localhost -U postgres $(dbname)
      \tpsql $(dbname) -h localhost -U postgres < $(dbname).sql

      web-server: ## Start the phoenix web server
      \tdocker-compose run --rm --service-ports web mix deps.get
      \tdocker-compose run --rm --service-ports web
      \tdocker-compose stop

      web-server-iex: ## Start the phoenix web server
      \tdocker-compose run --rm --service-ports web iex -S mix phx.server
      \tdocker-compose stop

      web-shell: ## Start a shell session on the web server
      \tdocker-compose run --rm --service-ports web sh
      \tdocker-compose stop

      test: test-mix

      clean: ## mix clean
      \tdocker-compose run --rm --service-ports web mix clean
      \tdocker-compose stop

      superclean: ## Clean plus remove all compiled stuff
      \tdocker-compose run --rm --service-ports web mix clean
      \trm -rf _build/*
      \trm -rf deps/*
      \tdocker-compose stop

      test-mix: ## Run mix tests
      \tdocker-compose run --rm --service-ports web mix test
      \tdocker-compose stop

      test-coverage: ## Run test coverage report
      \tdocker-compose run --rm --service-ports web mix test --cover
      \tdocker-compose stop

      format: ## Run code formatter
      \tdocker-compose run --rm --service-ports web mix format
      \tdocker-compose stop
      """,
      [:write]
    )
  end
end
