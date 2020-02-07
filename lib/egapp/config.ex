defmodule Egapp.Config do
  def get(key, default \\ nil) do
    Application.get_env(:egapp, key, default)
  end
end
