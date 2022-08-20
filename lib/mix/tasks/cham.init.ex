defmodule Mix.Tasks.Cham.Init do
  @moduledoc "The hello mix task: `mix help hello`"
  use Mix.Task

  @shortdoc "Setup the folder structure and make an initial public class."
  def run(_args) do
    otp_app = Mix.Cham.otp_app() |> IO.inspect

    # create makefile and docker files
    write_makefile(otp_app)

    _router_path = Mix.Cham.web_path(otp_app, "router.ex") |> IO.inspect
    _public_class = Mix.Cham.web_path(otp_app, "controllers/public") |> IO.inspect
    # add a browser pipeline (may need to not call it that in case its there,
    # or bail if it is)
    #
    # add a scope for "/" that adds an index public page setup

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
        @IFS=$$'\n' ; \\
        help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//'`); \\
        for help_line in $${help_lines[@]}; do \\
          IFS=$$'#' ; \\
          help_split=($$help_line) ; \\
          help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \\
          help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \\
          printf "%-30s %s\n" $$help_command $$help_info ; \\
        done

      build: ## (Re)build the containers
        docker-compose build

      start-db: ## Start the postgres node
        docker-compose up -d db

      stop-db: ## Stop the postgres node
        docker-compose stop

      db-migrate: ## Run migrations
        docker-compose up -d db
        docker-compose run --rm web mix do ecto.create ecto.migrate

      db-backup: ## Dump the db
        docker-compose up -d db
        pg_dump $(dbname) -h localhost -U postgres -w -O -f $(dbname).sql

      db-restore: ## Restore the db
        docker-compose up -d db
        createdb -T template0 -h localhost -U postgres $(dbname)
        psql $(dbname) -h localhost -U postgres < $(dbname).sql

      web-server: ## Start the phoenix web server
        docker-compose run --rm --service-ports web mix deps.get
        docker-compose run --rm --service-ports web
        docker-compose stop

      web-server-iex: ## Start the phoenix web server
        docker-compose run --rm --service-ports web iex -S mix phx.server
        docker-compose stop

      web-shell: ## Start a shell session on the web server
        docker-compose run --rm --service-ports web sh
        docker-compose stop

      test: test-mix

      clean: ## mix clean
        docker-compose run --rm --service-ports web mix clean
        docker-compose stop

      superclean: ## Clean plus remove all compiled stuff
        docker-compose run --rm --service-ports web mix clean
        rm -rf _build/*
        rm -rf deps/*
        docker-compose stop

      test-mix: ## Run mix tests
        docker-compose run --rm --service-ports web mix test
        docker-compose stop

      test-coverage: ## Run test coverage report
        docker-compose run --rm --service-ports web mix test --cover
        docker-compose stop

      format: ## Run code formatter
        docker-compose run --rm --service-ports web mix format
        docker-compose stop
      """,
      [:write]
    )

  end

end
