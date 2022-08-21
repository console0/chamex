# Chamex

Proof of concept for an opinionated phoenix dev environment and layout that
will make the transition from c5 to phoenix easier for developers.

## Prerequisites

Get `puma-dev` installed and configured.  Once you have it running add the following 
to `~.puma-dev/ex`

```
4000
```

Make sure you also have some sort of docker environment running, be it docker desktop or 
rancher desktop.  I've been using rancher desktop during development of this env.

## Initialization and Installation 

To get started on a new phoenix site:

```
mix phx.new sitename
cd sitename
```

Add this module to `mix.exs`.  Currently its only on git, so install via:

```elixir
def deps do
  [
    {:chamex, git: "https://github.com/console0/chamex", branch: "main"}`}
  ]
end
```

Then run

```
mix deps.get
```

As development is taking place, it makes sense to occasionally run:

```
mix deps.update chamex
```

Since the app will be running in a container, do the following minor changes to `dev.exs` and `test.exs`:

In the db config section:

```
  password: System.get_env("DB_PASS", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "test1",
```

Where ports are configured

```
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4000],
```

To initialize the cham layout and dev tweaks run:

```
mix cham.init
```

This installs a Makefile and some docker files.  You can set up the containers now via:

```
make build
```

This will build an app image for the web server and for the database.  You can start the app via:

```
make web-server
```

The site should now be accessible at `https://sitename.ex.test/`

Man other commands are added tot he Makefile for dumping the DB, running tests, getting a docker shell prompt, etc.  They can be
listed via:

```
make help
```

### TODO

* Make the init and other generators smart enough not to stomp other runs

