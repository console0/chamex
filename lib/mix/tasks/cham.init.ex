defmodule Mix.Tasks.Cham.Init do
  @moduledoc "The hello mix task: `mix help hello`"
  use Mix.Task

  @shortdoc "Setup the folder structure and make an initial public class."
  def run(args) do
    otp_app = Mix.Cham.otp_app() |> IO.inspect
    router_path = Mix.Cham.web_path(otp_app, "router.ex") |> IO.inspect 
    public_class = Mix.Cham.web_path(otp_app, "controllers/public") |> IO.inspect 
    # add a browser pipeline (may need to not call it that in case its there,
    # or bail if it is)
    #
    # add a scope for "/" that adds an index public page setup

  end
end
