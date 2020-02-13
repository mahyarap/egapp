defmodule Egapp.SASL do
  @moduledoc """
  A SASL behaviour
  """
  @callback authenticate(any()) :: any()

  def authenticate!(mechanism, message) do
    case mechanism do
      "PLAIN" -> Egapp.SASL.Plain.authenticate(message)
      "DIGEST-MD5" -> Egapp.SASL.Digest.authenticate(message)
      _ -> raise "no match"
    end
  end
end
