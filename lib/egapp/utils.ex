defmodule Egapp.Utils do
  @moduledoc """
  Utility functions
  """

  def generate_id, do: Enum.random(10_000_000..99_999_999)

  def remove_whitespace(data) do
    do_remove_whitespace(data, [])
  end

  defp do_remove_whitespace([h | t], result) when is_list(h) do
    do_remove_whitespace(t, [do_remove_whitespace(h, []) | result])
  end

  defp do_remove_whitespace([h | t], result) do
    case h do
      {:xmlcdata, "\n"} -> do_remove_whitespace(t, result)
      _ -> do_remove_whitespace(t, [h | result])
    end
  end

  defp do_remove_whitespace([], result) do
    Enum.reverse(result)
  end
end
