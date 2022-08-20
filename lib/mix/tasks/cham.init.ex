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
