defmodule Egapp.Utils do
  @moduledoc """
  Utility functions
  """

  def generate_id, do: Enum.random(10_000_000..99_999_999)
end
