defmodule Egapp.SASL do
  @moduledoc """
  A SASL behaviour
  """
  @callback type() :: atom
  @callback authenticate(String.t) :: term

  def authenticate!(mechanism, message, mechanisms) do
    mechanisms
    |> Enum.find(fn mech -> mech.type() |> Atom.to_string() |> String.upcase() == mechanism end)
    |> apply(:authenticate, [message])
  end
end
