defmodule ChameleonicWeb.Plugs.RequireClass do
  import Plug.Conn

  use ChameleonicWeb, :controller

  def init(classes), do: classes

  def call(conn, classes) do
    session_class = get_session(conn, :class)

    case Enum.member?(classes, session_class) do
      true -> conn
      _ -> conn |> put_flash(:info, "You must be logged in") |> redirect(to: "/") |> halt()
    end
  end
end

