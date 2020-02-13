defmodule Egapp.Config do
  @moduledoc """
  A simple interface to work with the application environment
  """

  def get(key, default \\ nil) do
    Application.get_env(:egapp, key, default)
  end
end
