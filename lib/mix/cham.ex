defmodule Mix.Cham do
  @moduledoc false

  # we have taken some minimal stuff from phoenix, but
  # we dont want to use it directly at the moment

  @doc """
  Returns the OTP app from the Mix project configuration.
  """
  def otp_app do
    Mix.Project.config() |> Keyword.fetch!(:app)
  end

  @doc """
  Returns the web prefix to be used in generated file specs.
  """
  def web_path(ctx_app, rel_path \\ "") when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      Path.join(["lib", "#{this_app}_web", rel_path])
    else
      Path.join(["lib", to_string(this_app), rel_path])
    end
  end

  @doc """
  Returns the name of the web namespace
  """
  def web_name(ctx_app) when is_atom(ctx_app) do
    this_app = otp_app()
    camelize(to_string(this_app)) <> "Web"
  end

  @doc """
  Taken from Phoenix for naming
  """
  @spec camelize(String.t) :: String.t
  def camelize(value), do: Macro.camelize(value)

  @spec camelize(String.t, :lower) :: String.t
  def camelize("", :lower), do: ""
  def camelize(<<?_, t :: binary>>, :lower) do
    camelize(t, :lower)
  end
  def camelize(<<h, _t :: binary>> = value, :lower) do
    <<_first, rest :: binary>> = camelize(value)
    <<to_lower_char(h)>> <> rest
  end

  defp to_lower_char(char) when char in ?A..?Z, do: char + 32
  defp to_lower_char(char), do: char

end
