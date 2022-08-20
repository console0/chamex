defmodule Mix.Tasks.Cham.Init do
  @moduledoc "The hello mix task: `mix help hello`"
  use Mix.Task

  @shortdoc "Setup the folder structure and make an initial public class."
  def run(_args) do
    otp_app = Mix.Cham.otp_app() |> IO.inspect

    # create makefile and docker files
    write_makefile(otp_app)
    write_dockerfile(otp_app)
    write_docker_compose(otp_app)

    _router_path = Mix.Cham.web_path(otp_app, "router.ex") |> IO.inspect
    _public_class = Mix.Cham.web_path(otp_app, "controllers/public") |> IO.inspect
    # add a browser pipeline (may need to not call it that in case its there,
    # or bail if it is)
    #
    # add a scope for "/" that adds an index public page setup

  end

  def write_dockerfile(otp_app) do
    app_name = to_string(otp_app)
    app_dir = File.cwd!
    dockerfile_path = Path.join([app_dir, "Dockerfile"])

    File.write(
      dockerfile_path,
      """
      # Elixir + Phoenix

      FROM elixir:1.14-alpine

      # Install debian packages
      RUN apt-get update
      RUN apt-get install --yes build-essential inotify-tools postgresql-client

      # Install Phoenix packages
      RUN mix local.hex --force
      RUN mix local.rebar --force

      WORKDIR /app
      EXPOSE 4000
      """,
      [:write]
    )

  end

  def write_docker_compose(otp_app) do
    app_name = to_string(otp_app)
    app_dir = File.cwd!
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
    app_dir = File.cwd!
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

      start-db: ## Start the postgres node
      \tdocker-compose up -d db

      stop-db: ## Stop the postgres node
      \tdocker-compose stop

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
