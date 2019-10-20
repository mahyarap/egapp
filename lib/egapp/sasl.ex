defmodule Egapp.SASL do
  @callback authenticate(any()) :: any()

  def authenticate!(mechanism, message) do
    case mechanism do
      "PLAIN" -> Egapp.SASL.Plain.authenticate(message)
      _ -> raise "no match"
    end
  end
end
